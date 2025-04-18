use strict;
use warnings;
use Test::More tests => 2;
use lib qw(../lib);

# Mock Codex::SinglePass to check invocation
{
    no warnings 'redefine';
    require Codex::SinglePass;
    my @called;
    local *Codex::SinglePass::run_singlepass = sub {
        push @called, [@_];
    };
    # Invoke via CLI
    require Codex::CLI;
    Codex::CLI::run('singlepass', '--original-prompt=Hello', '--config=foo.json', '--root=/tmp');
    is(scalar @called, 1, 'run_singlepass was called');
    is_deeply($called[0], ['--original-prompt=Hello', '--config=foo.json', '--root=/tmp'], 'Arguments passed through');
}