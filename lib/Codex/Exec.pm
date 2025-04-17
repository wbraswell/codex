package Codex::Exec;
use strict;
use warnings;
use Exporter 'import';
use Codex::ApplyPatch qw(process_patch);
use Perl::Types qw(arrayref string);

our @EXPORT_OK = qw(exec_apply_patch get_base_cmd);

=head1 NAME

Codex::Exec - Utilities for command execution and patch application

=cut

# Apply a patch text to the filesystem via callbacks, return ExecResult
sub exec_apply_patch {
    my ($patch_text, $open_fn, $write_fn, $remove_fn) = @_;
    eval {
        my $res = process_patch($patch_text, $open_fn, $write_fn, $remove_fn);
        return { stdout => $res, stderr => '', exitCode => 0 };
    } or do {
        my $err = $@ || 'Unknown error';
        chomp $err;
        return { stdout => '', stderr => "$err", exitCode => 1 };
    };
}

# Determine base command for display, trimming "bash -lc" wrapper
sub get_base_cmd {
    my ($cmd_aref) = @_;
    my @cmd = @$cmd_aref;
    if (@cmd == 3 && $cmd[0] eq 'bash' && $cmd[1] eq '-lc') {
        my $inner = $cmd[2];
        $inner =~ s/^'(.*)'$/$1/;
        return $inner;
    }
    # otherwise, take first element of formatted command
    return $cmd[0] || '';
}

1;