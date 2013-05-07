package Test::HTML::Simplify;
use strict;
use warnings;

use Test::More;
use File::Slurp;
use HTML::Simplify;
use Encode qw/encode_utf8 decode_utf8/;
use parent qw( Test::Class );

sub getArticleTitle : Tests {
    my $html = <<EOT;
<html><head>
<title>日本語タイトル</title>
</head></html>
EOT
    my $simple = HTML::Simplify->new_from_content($html);
    my $title_elm = $simple->get_article_title;
    isa_ok $title_elm, 'HTML::Element';
    is $title_elm->as_text, '日本語タイトル';
}

sub simplify : Tests {
    my $html = decode_utf8 <<EOT;
<html>
<head>
  <link rel="stylesheet" src="http://hogehuga.com/">
  <title> ぶくまぽっぷ - hatenabookmarkグループ </title>
</head>
<body>
hoge<br><br><br><br>
</body>
</html>
EOT
    my $simple = HTML::Simplify->new_from_content($html);
    my $simplified = $simple->simplify;

    print encode_utf8 $simplified->as_HTML;
}

__PACKAGE__->runtests;
1;

