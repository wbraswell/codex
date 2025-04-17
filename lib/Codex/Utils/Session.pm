package Codex::Utils::Session;
use strict;
use warnings;
use Perl::Types;

use Exporter 'import';
our @EXPORT_OK = qw(
    CLI_VERSION
    ORIGIN
    set_session_id
    get_session_id
    set_current_model
    get_current_model
);

=head1 NAME

Codex::Utils::Session - Store and retrieve global session metadata

=head1 CONSTANTS

=over 4

=item CLI_VERSION
Version of the CLI.

=item ORIGIN
Origin identifier for the CLI.

=back

=head1 FUNCTIONS

=head2 set_session_id($id)
set_current_model($model)
get_session_id()
get_current_model()

Set and get the current session ID and model.

=cut

use constant CLI_VERSION => '0.1.2504161510';
use constant ORIGIN      => 'codex_cli_ts';

my string $session_id    = '';
my string $current_model = '';

sub set_session_id {
    my string $id = shift;
    $session_id = $id // '';
}

sub get_session_id {
    return $session_id;
}

sub set_current_model {
    my string $model = shift;
    $current_model = $model // '';
}

sub get_current_model {
    return $current_model;
}

1;
__END__