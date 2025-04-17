package Codex::Utils::FormatCommand;
use strict;
use warnings;
use Perl::Types;
use String::ShellQuote qw(shell_quote);

use Exporter 'import';
our @EXPORT_OK = qw(format_command_for_display);

=head1 NAME

Codex::Utils::FormatCommand - Format shell command arrays for display

=head1 SYNOPSIS

  use Codex::Utils::FormatCommand qw(format_command_for_display);
  my arrayref::string $cmd = [qw(bash -lc 'echo foo')];
  my string $text = format_command_for_display($cmd);

=head1 DESCRIPTION

Exports a utility to format an arrayref of command strings for display,
stripping the internal "bash -lc" wrapper when present.

=head1 FUNCTIONS

=head2 format_command_for_display($command_arrayref)

Takes an arrayref of strings and returns a single string suitable for display.
If the command is ["bash","-lc",...], strips the wrapper and returns the inner.
Otherwise, quotes the args with String::ShellQuote.

=cut

sub format_command_for_display {
    my arrayref::string $command = shift;
    # detect ["bash","-lc",string]
    if (@$command == 3 && $command->[0] eq 'bash' && $command->[1] eq '-lc' && !ref $command->[2]) {
        my string $inner = $command->[2];
        # strip surrounding single quotes
        if ($inner =~ /^'(.*)'$/s) {
            $inner = $1;
        }
        return $inner;
    }
    # fallback: quote all args
    return shell_quote(@$command);
}

1;
__END__