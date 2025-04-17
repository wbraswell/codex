package Codex::Agent::Sandbox::RawExec;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(
    exec
);

=head1 NAME

Codex::Agent::Sandbox::RawExec - raw execution sandbox stub

=cut

use IPC::Open3;
use Symbol qw(gensym);
use POSIX qw(:sys_wait_h);

sub exec {
    my ($cmd_aref, $opts, $writableRoots, $abortSignal) = @_;
    my @cmd = @$cmd_aref;
    my $stderr = gensym;
    my $pid = open3(my $in, my $out, $stderr, @cmd);
    close $in;
    my $stdout = do { local $/; <$out> };
    my $errout = do { local $/; <$stderr> };
    waitpid($pid, 0);
    my $exit = $? >> 8;
    return { stdout => $stdout // '', stderr => $errout // '', exitCode => $exit };
}

1;