# -*- mode:perl -*-
use strict;
use Test::More;

BEGIN { use_ok 'Parallel::Benchmark' }

my $bm = Parallel::Benchmark->new(
    setup => sub {
        my ($self, $n) = @_;
        sleep 2 if $n % 2 == 0;
    },
    benchmark => sub {
        my ($self, $n) = @_;
        return 1;
    },
    debug       => 1,
    time        => 1,
    concurrency => 4,
);

my $result = $bm->run;
isa_ok $result => "HASH";
ok exists $result->{score},   "score exists";
ok exists $result->{elapsed}, "elapsed exists";
is scalar (keys %{$result->{stashes}}) => 4, "all stashes exists";
ok $result->{elapsed} >= 0.9, "elapsed >= 0.9";
ok $result->{elapsed} <= 1.1, "elapsed <= 1.1";
note explain $result;

done_testing;
