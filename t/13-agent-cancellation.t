use strict;
use warnings;
use Test::More tests => 2;
use lib qw(../lib);
use threads;
use Time::HiRes qw(sleep);
# We will locally override handle_exec_command for testing

# Load the module under test
use Codex::Agent::Loop;

sub make_agent {
    my %received;
    my $agent = Codex::Agent::Loop->new(
        model                  => 'any',
        instructions           => '',
        config                 => { model => 'any', instructions => '' },
        approvalPolicy         => { mode => 'auto' },
        onItem                 => sub { push @{$received{items} ||= []}, shift },
        onLoading              => sub {},
        getCommandConfirmation => sub { return { review => 'yes' } },
        onLastResponseId       => sub {},
    );
    return ($agent, \%received);
}

# Test 1: slow exec, cancel before completion
{
    no warnings 'redefine';
    # Override handle_exec_command to simulate slow execution
    local *Codex::Agent::HandleExecCommand::handle_exec_command = sub {
        sleep(0.05);
        return { outputText => 'hello', metadata => {}, additionalItems => [] };
    };
    my ($agent, $rec) = make_agent();
    $agent->run([{ type => 'message', role => 'user', content => [] }]);
    # Wait briefly and then cancel
    sleep(0.01);
    $agent->cancel();
    # Allow time for any post-exec scheduling
    sleep(0.2);
    my $has_output = grep { $_->{type} && $_->{type} eq 'function_call_output' } @{ $rec->{items} || [] };
    ok(!$has_output, 'no function_call_output after cancel on slow exec');
}

# Test 2: fast exec, cancel after execution but before delayed emit
{
    no warnings 'redefine';
    # Override handle_exec_command to immediate return
    local *Codex::Agent::HandleExecCommand::handle_exec_command = sub {
        return { outputText => 'hello-fast', metadata => {}, additionalItems => [] };
    };
    my ($agent2, $rec2) = make_agent();
    $agent2->run([{ type => 'message', role => 'user', content => [] }]);
    # Wait some time, but before emission delay (30ms)
    sleep(0.02);
    $agent2->cancel();
    # Allow time for scheduled emit
    sleep(0.1);
    my $has_output2 = grep { $_->{type} && $_->{type} eq 'function_call_output' } @{ $rec2->{items} || [] };
    ok(!$has_output2, 'no function_call_output after cancel on fast exec');
}