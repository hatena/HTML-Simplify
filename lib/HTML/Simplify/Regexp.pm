package HTML::Simplify::Regexp;
use warnings;
use strict;

our $unlikely_candidate =
    qr/combx|comment|community|disqus|extra|foot|header|menu|remark|rss|shoutbox|sidebar|sponsor|ad-break|agegate|pagination|pager|popup|tweet|twitter/i;

our $ok_maybe_its_a_candidate =
    qr/and|article|body|column|main|shadow/i;

our $negative =
    qr/combx|comment|com-|contact|foot|footer|footnote|masthead|media|meta|outbrain|promo|related|scroll|shoutbox|sidebar|sponsor|shopping|tags|tool|widget/i;

our  $positive =
    qr/article|body|content|entry|hentry|main|page|pagination|post|text|blog|story/i;

our $extraneous =
    qr/print|archive|comment|discuss|e[\-]?mail|share|reply|all|login|sign|single/i;

our $div_to_p_elements =
    qr/<(a|blockquote|dl|div|img|ol|p|pre|table|ul)/i;

our $replace_brs =
    qr/(<br[^>]*>[ \n\r\t]*){2,}/i;

our $replace_fonts =
    qr/<(\/?)font[^>]*>/i;

our $trim=
    qr/^\s+|\s+$/;

our $normalize=
    qr/\s=2,;/;

our $kill_breaks =
    qr/(<br\s*\/?>(\s|&nbsp;?)*)=1,;/;

our $videos =
    qr/http:\/\/(www\.)?(youtube|vimeo)\.com/i;

our $skip_footnote_link =
    qr/^\s*(\[?[a-z0-9]=1,2;\]?|^|edit|citation needed)\s*$/i;

our $next_link =
    #Match: next, continue, >, >>, » but not >|, »| as those usually mean last.
    qr/(next|weiter|continue|>([^\|]|$)|»([^\|]|$))/i;

our $prev_link =
    qr/(prev|earl|old|new|<|«)/i;

1;
