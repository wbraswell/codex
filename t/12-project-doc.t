use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(make_path);
use Test::More tests => 4;
use lib qw(../lib);
use Codex::Config qw(load_config PROJECT_DOC_MAX_BYTES DEFAULT_AGENTIC_MODEL DEFAULT_INSTRUCTIONS);

# Setup project directory with .git
my $proj = tempdir(CLEANUP => 1);
make_path(File::Spec->catdir($proj, '.git'));
my $config_path = File::Spec->catfile($proj, 'config.json');
my $instr_path  = File::Spec->catfile($proj, 'instructions.md');

# 1) happy path: project doc gets merged
my $doc = "# Project\nThis is my project.";
{
    my $doc_file = File::Spec->catfile($proj, 'codex.md');
    open my $dfh, '>', $doc_file or die $!;
    print $dfh $doc;
    close $dfh;
    my $cfg = load_config($config_path, $instr_path, { cwd => $proj });
    like($cfg->{instructions}, qr/\Q$doc\E/, 'instructions contains project doc');
}

# 2) opt-out prevents inclusion
{
    my $doc_file = File::Spec->catfile($proj, 'codex.md');
    open my $dfh, '>', $doc_file or die $!;
    print $dfh "ignore me";
    close $dfh;
    my $cfg = load_config($config_path, $instr_path, { cwd => $proj, disableProjectDoc => 1 });
    ok($cfg->{instructions} !~ /ignore me/, 'opt-out omits project doc');
}

# 3) file larger than limit gets truncated and warns
{
    my $big = 'x' x (PROJECT_DOC_MAX_BYTES + 4096);
    my $doc_file = File::Spec->catfile($proj, 'codex.md');
    open my $dfh, '>', $doc_file or die $!;
    print $dfh $big;
    close $dfh;
    my $warned = 0;
    {
        local $SIG{__WARN__} = sub { $warned++ };
        my $cfg = load_config($config_path, $instr_path, { cwd => $proj });
        is(length($cfg->{instructions}), PROJECT_DOC_MAX_BYTES, 'instructions truncated to limit');
    }
    ok($warned, 'warned on truncation');
}

# 4) default config model unaffected
{
    my $cfg = load_config($config_path, $instr_path, { cwd => $proj, disableProjectDoc => 1 });
    is($cfg->{model}, DEFAULT_AGENTIC_MODEL, 'default model remains');
}