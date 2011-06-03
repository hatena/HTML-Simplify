use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTML::Simplify;
use LWP::UserAgent;
use Jcode;
use Encode qw/decode_utf8 encode_utf8/;
use Perl6::Say;

my $url = $ARGV[0];

die "usage $1 <url>" unless $url;

my $ua = LWP::UserAgent->new;
my $req = HTTP::Request->new(GET => $url);



my $res = $ua->request($req);

die 'Can not get HTML' unless $res->is_success;


my $html = $res->content;
$html = decode_utf8( Jcode->new( $html )->utf8 );
my $simplifier = HTML::Simplify->new_from_content($html);
$simplifier->debug = 1;


my $simplified = $simplifier->simplify;


if ( $simplified ) {
    say encode_utf8 $simplifier->get_title->as_text;

    my $html;
    eval {
        $html = $simplified->as_XML;
    };
    say encode_utf8 $html if $html;;
    my $first_img = $simplified->find('img');
    say $first_img->attr('src') if $first_img;
} else {
    die 'Can not Simplify';
}


