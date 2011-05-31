use strict;
use warnings;

use Test::More;
use File::Slurp;
use HTML::Simplify;

use base qw/Test::Class/;

sub startup : Test(startup) {
    my $self = shift;
    $self->{simpl} = HTML::Simplify->new();
}



runtest;
1;

