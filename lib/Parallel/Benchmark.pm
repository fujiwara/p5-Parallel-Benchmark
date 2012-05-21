package Parallel::Benchmark;
use strict;
use warnings;
our $VERSION = '0.02';

use Mouse;
use Log::Minimal;
use Time::HiRes qw/ tv_interval gettimeofday /;
use Parallel::ForkManager;
use Parallel::Scoreboard;
use POSIX qw/ SIGUSR1 SIGUSR2 /;

has benchmark => (
    is      => "rw",
    isa     => "CodeRef",
    default => sub { sub { return 1 } },
);

has setup => (
    is      => "rw",
    isa     => "CodeRef",
    default => sub { sub { } },
);

has teardown => (
    is      => "rw",
    isa     => "CodeRef",
    default => sub { sub { } },
);

has time => (
    is      => "rw",
    isa     => "Int",
    default => 3,
);

has concurrency => (
    is      => "rw",
    isa     => "Int",
    default => 1,
);

has debug => (
    is      => "rw",
    isa     => "Bool",
    default => 0,
    trigger => sub {
        my ($self, $val) = @_;
        $ENV{LM_DEBUG} = $val;
    },
);

has stash => (
    is      => "rw",
    isa     => "HashRef",
    default => sub { +{} },
);

has scoreboard => (
    is => "rw",
    default => sub {
        Parallel::Scoreboard->new(
            base_dir => "/tmp/" . __PACKAGE__ . ".$$",
        );
    },
);

sub run {
    my $self = shift;

    local $Log::Minimal::COLOR = 1
        if -t *STDERR;                ## no critic
    local $Log::Minimal::PRINT = sub {
        my ( $time, $type, $message, $trace) = @_;
        warn "$time [$type] $message\n";
    };

    infof "starting benchmark: concurrency: %d, time: %d",
        $self->concurrency, $self->time;

    my $pm = Parallel::ForkManager->new( $self->concurrency );
    my $result = {
        score   => 0,
        elapsed => 0,
        stashes => {},
    };
    $pm->run_on_finish (
        sub {
            my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data) = @_;
            if (defined $data) {
                $result->{score}   += $data->[1];
                $result->{elapsed} += $data->[2];
                $result->{stashes}->{ $data->[0] } = $data->[3];
            }
        }
    );
    my (@pids, %prepared_children);
    my $parent_pid = $$;

 CHILD:
    for my $n ( 1 .. $self->concurrency ) {
        my $pid = $pm->start;
        if ($pid) {
            # parent
            push @pids, $pid;
            next CHILD;
        }
        else {
            #child
            $self->setup->( $self, $n );
            $self->scoreboard->update("setup_done");

            my $r = $self->_run_benchmark_on_child($n);
            $self->teardown->( $self, $n );
            $pm->finish( 0, $r );
            exit;
        }
    }

    # wait for all children's setup finish
    while (1) {
        my $stats = $self->scoreboard->read_all();
        my $done  = scalar grep { /setup_done/ } values %$stats;
        last if $done == @pids;
        sleep 1;
    }
    sleep 1;

    kill SIGUSR1, @pids;
    my $teardown = sub { kill SIGUSR2, @pids };
    local $SIG{INT} = $teardown;

    sleep $self->time;

    $teardown->();
    $pm->wait_all_children;

    $result->{elapsed} /= $self->concurrency;

    if ( $result->{elapsed} > 0 ) {
        infof "done benchmark: score %s, elapsed %.3f sec = %.3f / sec",
            $result->{score},
            $result->{elapsed},
            $result->{score} / $result->{elapsed},
        ;
    }
    else {
        warnf "done benchmark: score %s, but elapsed time = 0 (maybe failed?)",
            $result->{score},
       ;
    }

    $result;
}

sub _run_benchmark_on_child {
    my $self = shift;
    my $n    = shift;

    my ($wait, $run) = (1, 1);
    local $SIG{USR1} = sub { $wait = 0 };
    local $SIG{USR2} = sub { $run = 0  };
    local $SIG{INT}  = sub {};
    debugf "spwan child %d pid %d", $n, $$;

    sleep 1 while $wait;

    debugf "starting benchmark on child %d pid %d", $n, $$;

    my $benchmark = $self->benchmark;
    my $score     = 0;
    my $start     = [gettimeofday];

    $score += $benchmark->( $self, $n ) while $run;

    my $elapsed = tv_interval($start);

    debugf "done benchmark on child %d: score %s, elapsed %.3f sec.",
        $n, $score, $elapsed;

    return [ $n, $score, $elapsed, $self->stash ];
}


1;
__END__

=head1 NAME

Parallel::Benchmark - parallel benchmark module

=head1 SYNOPSIS

  use Parallel::Benchmark;
  sub fib {
      my $n = shift;
      return $n if $n == 0 or $n == 1;
      return fib( $n - 1 ) + fib( $n - 2 );
  }
  my $bm = Parallel::Benchmark->new(
      benchmark => sub {
          my ($self, $id) = @_;
          fib(10);  # code for benchmarking
          return 1; # score
      },
      concurrency => 3,
  );
  my $result = $bm->run;
  # output to STDERR
  #  2012-02-18T21:18:17 [INFO] starting benchmark: concurrency: 3, time: 3
  #  2012-02-18T21:18:21 [INFO] done benchmark: score 42018, elapsed 3.000 sec = 14005.655 / sec
  # $result hashref
  # {
  #   'elapsed' => '3.000074',
  #   'score'   => 42018,
  # }

=head1 DESCRIPTION

Parallel::Benchmark is parallel benchmark module.

=head1 METHODS

=over 4

=item B<new>(%args)

create Parallel::Benchmark instance.

  %args:
    benchmark:   CodeRef to benchmark.
    setup:       CodeRef run on child process before benchmark.
    teardown:    CodeRef run on child process after benchmark.
    time:        Int     benchmark running time. default=3
    concurrency: Int     num of child processes. default=1
    debug:       Bool    output debug log.       default=0

=item B<run>()

run benchmark. returns result hashref.

    {
      'stashes' => {
        '1' => { },   # $self->stash of child id==1
        '2' => { },
        ...
      },
      'score'   => 1886,        # sum of score
      'elapsed' => '3.0022655', # elapsed time (sec)
    };

=item B<stash>

HashRef to store some data while processing.

Child process's stash returns to result on parent process.

  $result = $bm->run;
  $result->{stashes}->{$id}; #= $self->stash on child $id

=back

=head1 EXAMPLES

=head2 HTTP GET Benchmark

  use LWP::UserAgent;
  my $bm = Parallel::Benchmark->new(
      setup => sub {
          my ($self, $id) = @_;
          $self->stash->{ua} = LWP::UserAgent->new;
      },
      benchmark => sub {
          my ($self, $id) = @_;
          my $res = $self->stash->{ua}->get("http://127.0.0.1/");
          $self->stash->{code}->{ $res->code }++;
          return 1;
      },
      teardown => sub {
          my ($self, $id) = @_;
          delete $self->stash->{ua};
      },
      concurrency => 2,
  );
  my $result = $bm->run();
  # {
      'stashes' => {
        '1' => {
          'code' => {
            '200' => 932,
            '500' => 7
          }
        },
        '2' => {
          'code' => {
            '200' => 935,
            '500' => 12
          }
        }
      },
      'score' => 1886,
      'elapsed' => '3.0022655'
    }


=head1 AUTHOR

FUJIWARA Shunichiro E<lt>fujiwara@cpan.orgE<gt>

=head1 SEE ALSO

Parallel::ForkManager

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
