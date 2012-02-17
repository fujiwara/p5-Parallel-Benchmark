package Parallel::Benchmark;
use strict;
use warnings;
our $VERSION = '0.01';

use Mouse;
use Log::Minimal;
use Time::HiRes qw/ tv_interval gettimeofday /;
use Parallel::ForkManager;
use POSIX;

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

sub run {
    my $self = shift;

    local $Log::Minimal::COLOR = 1;
    local $Log::Minimal::PRINT = sub {
        my ( $time, $type, $message, $trace) = @_;
        warn "$time [$type] $message\n";
    };

    my $pm = Parallel::ForkManager->new( $self->concurrency );
    my $result = {
        score   => 0,
        elapsed => 0,
    };
    $pm->run_on_finish (
        sub {
            my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data) = @_;
            if (defined $data) {
                $result->{score}   += $data->[0];
                $result->{elapsed} += $data->[1];
            }
        }
    );
    my @pids;
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
            my $r = $self->_run_benchmark_on_child($n);
            $self->teardown->( $self, $n );
            $pm->finish( 0, $r );
            exit;
        }
    }

    sleep 1;

    kill SIGUSR1, @pids;
    my $teardown = sub { kill SIGUSR2, @pids };
    local $SIG{INT} = $teardown;

    sleep $self->time;

    $teardown->();
    $pm->wait_all_children;

    $result->{elapsed} /= $self->concurrency;

    infof "done benchmark: score %s, elapsed %.3f sec = %.3f / sec",
        $result->{score},
        $result->{elapsed},
        $result->{score} / $result->{elapsed},
    ;
    $result;
}

sub _run_benchmark_on_child {
    my $self = shift;
    my $n    = shift;

    my ($wait, $run) = (1, 1);
    debugf "spwan child %d pid %d", $n, $$;
    local $SIG{USR1} = sub { $wait = 0 };
    local $SIG{USR2} = sub { $run = 0  };
    local $SIG{INT}  = sub {};

    sleep 1 while $wait;

    debugf "starting benchmark on child %d pid %d", $n, $$;
    my $start = [gettimeofday];

    my $score = 0;
    while ($run) {
        $score += $self->benchmark->( $self, $n );
    }

    my $elapsed = tv_interval($start);

    debugf "done benchmark on child %d: score %s, elapsed %.3f sec.",
        $n, $score, $elapsed;

    return [ $score, $elapsed ];
}


1;
__END__

=head1 NAME

Parallel::Benchmark -

=head1 SYNOPSIS

  use Parallel::Benchmark;
  my $bm = Parallel::Benchmark->new(
      benchmark => sub {
          fib(10);
          return 1; # score
      },
      concurrency => 3,
  );
  my $result = $bm->run;
  # {
  #   'elapsed' => '3.066999',
  #   'score' => 45342
  # }

=head1 DESCRIPTION

Parallel::Benchmark is forking benchmark framework

=head1 AUTHOR

FUJIWARA Shunichiro E<lt>fujiwara@cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
