# -*- mode:perl -*-
use strict;
use Test::More;

BEGIN { use_ok 'Parallel::Benchmark' }

my $bm = Parallel::Benchmark->new(
    benchmark => sub {
        my ($self, $n) = @_;
        die;
    },
    debug       => 1,
    concurrency => 1,
    time        => 1,
);

my $result = $bm->run;
isa_ok $result => "HASH";
is $result->{score}   => 0,   "score 0";
is $result->{elapsed} => 0, "elapsed 0";
note explain $result;

done_testing;
