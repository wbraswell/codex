package Codex::Utils::InputUtils;
use strict;
use warnings;
use Perl::Types;

use Exporter 'import';
our @EXPORT_OK = qw(create_input_item);

use File::Slurp qw(read_file);
use MIME::Base64 qw(encode_base64);
use File::Type;

=head1 NAME

Codex::Utils::InputUtils - Create response input items from text and images

=head1 FUNCTIONS

=head2 create_input_item($text, $images_arrayref)

Returns a hashref representing an OpenAI input message with embedded images.

=cut

sub create_input_item {
    my string $text   = shift;
    my arrayref::string $images = shift;
    my hashref $item = {
        role    => 'user',
        type    => 'message',
        content => [ { type => 'input_text', text => $text } ],
    };
    my $ft = File::Type->new();
    for my string $file (@$images) {
        my bytes $binary = read_file($file, { binmode => ':raw' });
        my string $mime = $ft->mime_type($file) // 'application/octet-stream';
        my string $encoded = encode_base64($binary, '');
        push @{ $item->{content} }, {
            type      => 'input_image',
            detail    => 'auto',
            image_url => "data:${mime};base64,${encoded}",
        };
    }
    return $item;
}

1;
__END__