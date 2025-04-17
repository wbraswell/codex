package Codex::Utils::ApproximateTokensUsed;
use strict;
use warnings;
use Perl::Types;

use Exporter 'import';
our @EXPORT_OK = qw(approximate_tokens_used);

=head1 NAME

Codex::Utils::ApproximateTokensUsed - Estimate LM token usage from response items

=head1 FUNCTIONS

=head2 approximate_tokens_used($items_arrayref)

Roughly estimate the number of language-model tokens in a list of response items by
counting characters and dividing by four.

=cut

sub approximate_tokens_used {
    my arrayref::hashref $items = shift;
    my nonsigned_integer $char_count = 0;
    for my hashref $item (@$items) {
        my $type = $item->{type} // '';
        if ($type eq 'message') {
            for my hashref $c (@{ $item->{content} // [] }) {
                my $ctype = $c->{type} // '';
                if ($ctype eq 'input_text' || $ctype eq 'output_text') {
                    $char_count += length($c->{text} // '');
                } elsif ($ctype eq 'refusal') {
                    $char_count += length($c->{refusal} // '');
                } elsif ($ctype eq 'input_file') {
                    $char_count += length($c->{filename} // '');
                }
            }
        } elsif ($type eq 'function_call') {
            $char_count += length($item->{name} // '') + length($item->{arguments} // '');
        } elsif ($type eq 'function_call_output') {
            $char_count += length($item->{output} // '');
        }
    }
    # ceil(char_count/4)
    return int(($char_count + 3) / 4);
}

1;
__END__