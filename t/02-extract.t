use strict;
use warnings;

use Test::More;
use File::Slurp;
use HTML::Simplify;

use parent qw( Test::Class );

sub simplify : Tests {

    @_ = sort(glob("t/input*.html"));
    $_[-1] =~ /^t\/input(.*)\.html$/;
    my $files = $1;

    for my $n (1..$files) {
        my $simplifier = HTML::Simplify->new;
        my $input = read_file("t/input${n}.html");
        my $raw = read_file("t/raw${n}.html");
        my $text = read_file("t/text${n}.txt");

        my $res = $simplifier->simplify($input);
        is($raw, $res->as_HTML);
        is($text, $res->as_XML);
    }
}

__PACKAGE__->runtests();

1;
