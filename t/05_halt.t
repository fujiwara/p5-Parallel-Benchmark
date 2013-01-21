# -*- mode:perl -*-
use strict;
use Test::More;

BEGIN { use_ok 'Parallel::Benchmark' }

my $bm = Parallel::Benchmark->new(
    startup   => sub {
        my ($self, $n) = @_;
        $self->stash->{counter} = 0;
    },
    benchmark => sub {
        my ($self, $n) = @_;
        if ( $self->stash->{counter}++ == 10 ) {
            $self->halt("counter reached 10");
        }
        1;
    },
    debug       => 1,
    concurrency => 2,
    time        => 1,
);

my $result = $bm->run;
isa_ok $result => "HASH";
is $result->{score} => 20, "score 10 * 2";
note explain $result;

done_testing;
