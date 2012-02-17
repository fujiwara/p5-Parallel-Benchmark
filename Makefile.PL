use inc::Module::Install;
name 'Parallel-Benchmark';
all_from 'lib/Parallel/Benchmark.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
