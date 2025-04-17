package Codex::Utils::Terminal;
use strict;
use warnings;
use Perl::Types;

use Exporter 'import';
our @EXPORT_OK = qw(set_ink_renderer clear_terminal on_exit);

use Curses;

=head1 NAME

Codex::Utils::Terminal - Terminal utilities (Curses-based)

=head1 FUNCTIONS

=head2 set_ink_renderer($obj)

No-op placeholder for compatibility.

=head2 clear_terminal()

Clears the screen unless CODEX_QUIET_MODE is set.

=head2 on_exit()

Restores the terminal on exit.

=cut

sub set_ink_renderer {
    # no-op in Curses backend
}

sub clear_terminal {
    return if $ENV{CODEX_QUIET_MODE} && $ENV{CODEX_QUIET_MODE} eq '1';
    Curses::clear();
    Curses::refresh();
}

sub on_exit {
    # restore terminal
    Curses::endwin();
}

1;
__END__