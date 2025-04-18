use strict;
use warnings;
use Test::More tests => 1;
use lib qw(../lib);
use Test::MockModule;

# Prepare an agent with a simple onItem collector
my @received;
my $agent = do {
    require Codex::Agent::Loop;
    Codex::Agent::Loop->new(
        model                  => 'test-model',
        instructions           => '',
        config                 => {},
        onItem                 => sub { push @received, shift },
        onLoading              => sub {},
        getCommandConfirmation => sub {},
        onLastResponseId       => sub {},
    );
};

# Stub Mojo::UserAgent to return a fake transaction
my $fake_tx = bless {}, 'FakeTx';
my $ua_mod = Test::MockModule->new('Mojo::UserAgent');
$ua_mod->mock('build_tx',  sub { return $fake_tx });

# Stub FakeTx->res->on to capture the data callback
my $callback;
my $res = bless {}, 'FakeRes';
Test::MockModule->new('FakeTx')->mock('res', sub { return $res });
Test::MockModule->new('FakeRes')->mock('on', sub {
    my ($self, $event, $cb) = @_;
    $callback = $cb;
});

# Stub Mojo::UserAgent->start to invoke the data callback
$ua_mod->mock('start', sub {
    # Simulate two SSE chunks: one content delta, then DONE
    $callback->(undef, "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n");
    $callback->(undef, "data: [DONE]\n\n");
});

# Invoke streaming loop directly
$agent->_stream_loop([
    { type => 'message', role => 'user', content => 'ignored' }
]);

is_deeply(
    \@received,
    [ { type => 'message', role => 'assistant', content => [ { type => 'input_text', text => 'Hello' } ] } ],
    'Streaming delivers assistant content'
);