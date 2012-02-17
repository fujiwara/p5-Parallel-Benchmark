# -*- mode:perl -*-
use strict;
use Test::More;

BEGIN { use_ok 'Parallel::Benchmark' }

my $bm = Parallel::Benchmark->new(
    setup => sub {
        my ($self, $n) = @_;
        warn "setup $n";
    },
    benchmark => sub {
        my ($self, $n) = @_;
        sleep 1;
        warn "CHILD $n";
        return 1;
    },
    teardown => sub {
        my ($self, $n) = @_;
        warn "teardown $n";
    },
    debug       => 1,
    concurrency => 3,
);

my $result = $bm->run;
isa_ok $result => "HASH";
ok exists $result->{score},   "score exists";
ok exists $result->{elapsed}, "elapsed exists";

done_testing;
