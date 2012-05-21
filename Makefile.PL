use inc::Module::Install;
name 'Parallel-Benchmark';
all_from 'lib/Parallel/Benchmark.pm';

requires 'Parallel::ForkManager';
requires 'Parallel::Scoreboard';
requires 'Log::Minimal';
requires 'Time::HiRes';
requires 'Mouse';
requires 'POSIX';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
