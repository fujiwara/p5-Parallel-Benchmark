requires 'File::Temp';
requires 'Log::Minimal';
requires 'Mouse';
requires 'POSIX';
requires 'Parallel::ForkManager', 'v0.7.6';
requires 'Parallel::Scoreboard';
requires 'Time::HiRes';
requires 'Try::Tiny';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.36';
};
