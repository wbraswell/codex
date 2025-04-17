package Codex::Utils::Parsers;
use strict;
use warnings;
use Perl::Types;

use Exporter 'import';
our @EXPORT_OK = qw(
    parse_tool_call_output
    parse_tool_call
    parse_tool_call_arguments
);

use JSON qw(decode_json);
use Codex::Utils::FormatCommand qw(format_command_for_display);

=head1 NAME

Codex::Utils::Parsers - Parse tool call JSON and arguments

=head1 FUNCTIONS

=head2 parse_tool_call_output($json_text)

Attempts to decode a JSON string with { output, metadata }.
Returns a hashref with keys 'output' and 'metadata'.

=head2 parse_tool_call_arguments($arguments_text)

Parses JSON string to extract cmd array, workdir, and timeout.
Returns undef on failure.

=head2 parse_tool_call($tool_call_hashref)

Given a tool call hashref, returns a hashref with cmd and cmdReadableText, or undef.

=cut

sub parse_tool_call_output {
    my string $text = shift;
    my $result;
    eval { $result = decode_json($text); 1 } or do {
        return { output => 'Failed to parse JSON result', metadata => { exit_code => 1, duration_seconds => 0 } };
    };
    return { output => $result->{output}, metadata => $result->{metadata} };
}

sub parse_tool_call_arguments {
    my string $text = shift;
    my $json;
    eval { $json = decode_json($text); 1 } or do {
        warn "Failed to parse toolCall.arguments: $text";
        return undef;
    };
    return undef unless ref($json) eq 'HASH';
    my $cmd = $json->{cmd} // $json->{command};
    return undef unless ref($cmd) eq 'ARRAY' && !grep { ref } @$cmd;
    my $args = { cmd => $cmd };
    $args->{workdir}        = $json->{workdir}  if defined $json->{workdir}  && !ref $json->{workdir};
    $args->{timeoutInMillis}= $json->{timeout}   if defined $json->{timeout}   && !ref $json->{timeout};
    return $args;
}

sub parse_tool_call {
    my hashref $tool_call = shift;
    my hashref $args = parse_tool_call_arguments($tool_call->{arguments});
    return undef unless $args;
    my arrayref::string $cmd = $args->{cmd};
    my string $text = format_command_for_display($cmd);
    return { cmd => $cmd, cmdReadableText => $text };
}

1;
__END__