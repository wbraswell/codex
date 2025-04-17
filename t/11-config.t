use strict;
use warnings;
use Test::More tests => 5;
use lib qw(../lib);
use File::Temp qw(tempdir);
use File::Spec;
use Codex::Config qw(load_config save_config DEFAULT_AGENTIC_MODEL DEFAULT_INSTRUCTIONS);

# Setup temporary directory for config
my $dir = tempdir(CLEANUP => 1);
my $config_path = File::Spec->catfile($dir, 'config.json');
my $instr_path  = File::Spec->catfile($dir, 'instructions.md');

# 1) load default when none exist
my $cfg1 = load_config($config_path, $instr_path, { disableProjectDoc => 1 });
is($cfg1->{model}, DEFAULT_AGENTIC_MODEL, 'default model');
is($cfg1->{instructions}, DEFAULT_INSTRUCTIONS, 'default instructions');

# 2) save and load config correctly
my %test_conf = ( model => 'test-model', instructions => 'test instructions' );
save_config(\%test_conf, $config_path, $instr_path);

# config file should contain model
{
    local $/;
    open my $cfh, '<', $config_path or die $!;
    my $content = <$cfh>;
    close $cfh;
    like($content, qr/"model"\s*:\s*"test-model"/, 'config file contains model');
}

# instructions file equals instructions
{
    local $/;
    open my $ifh, '<', $instr_path or die $!;
    my $idata = <$ifh>;
    close $ifh;
    is($idata, 'test instructions', 'instructions file contents');
}

# loaded config matches test_conf
my $cfg2 = load_config($config_path, $instr_path, { disableProjectDoc => 1 });
is_deeply($cfg2, \%test_conf, 'loaded config matches saved');