BEGIN {
    my @devmods = qw(
        Module::Install::AuthorTests
        Module::Install::Repository
    );
    my @not_available;

    eval qq{use inc::Module::Install; 1;} or push @not_available, 'inc::Module::Install';
    for my $mod (@devmods) {
        eval qq{require $mod} or push @not_available, $mod;
    }
    if (@not_available) {
        print qq{# The following modules are not available.\n};
        print qq{# `$^X $0 | cpanm` will install them:\n};
        print $_, "\n" for @not_available;
        print "\n";
        exit -1;
    }
}

use inc::Module::Install;
name 'Parallel-Benchmark';
all_from 'lib/Parallel/Benchmark.pm';

requires 'Parallel::ForkManager' => "0.7.6";
requires 'Parallel::Scoreboard';
requires 'File::Temp';
requires 'Log::Minimal';
requires 'Time::HiRes';
requires 'Mouse';
requires 'POSIX';
requires 'Try::Tiny';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
