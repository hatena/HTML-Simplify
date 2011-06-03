package HTML::Simplify;
use warnings;
use strict;

use List::Util qw/min max/;
use HTML::TreeBuilder;
use HTML::Element;

use HTML::Simplify::Regexp;

use base qw/Class::Accessor::Lvalue::Fast/;
__PACKAGE__->mk_accessors(qw/document flags debug/);

use constant FLAG_STRIP_UNLIKELYS => 0x1;
use constant FLAG_WEIGHT_CLASSES  => 0x2;
use constant FLAG_CLEAN_CONDITIONALLY => 0x4;

sub new {
    my ($class) = @_;
    my $self = $class->SUPER::new();
    $self->flags = FLAG_STRIP_UNLIKELYS | FLAG_WEIGHT_CLASSES | FLAG_CLEAN_CONDITIONALLY;
    return $self;
}

sub new_from_content {
    my ($class, $html) = @_;
    my $self= $class->new;
    $self->document = HTML::TreeBuilder->new_from_content($html);
    return $self;
}

sub flag_is_active {
    my ($self,$flag) = @_;
    return ($self->flags & $flag) > 0;
}

sub add_flag {
    my ($self, $flag) = @_;
    $self->flags = ( $self->flags | $flag );
}

sub remove_flag {
    my ($self, $flag) = @_;
    $self->flags = ( $self->flags & ~$flag );
}

sub get_suggested_direction {
    my ($self,$text) = @_;
    $text =~ s/@\w+//g;

    my @count_heb = $text =~ /[\\u05B0-\\u05F4\\uFB1D-\\uFBF4]/g;
    my @count_arb = $text =~ /[\\u060C-\\u06FE\\uFB50-\\uFEFC]/g
;
    if ( (@count_heb + @count_arb) * 100 / length $text > 20 ) {
        return "rtl";
    }
    return "ltr";
}

sub initialize_node {
    my ($self, $node) = @_;
    $node->attr('readability',0);

    if ( $node->tag eq 'div') {
        $node->attr('readability', $node->attr('readability') + 5)

    } elsif ($node->tag eq 'pre' ||
             $node->tag eq 'td'  ||
             $node->tag eq 'blockquote') {
        $node->attr('readability', $node->attr('readability') + 3)


    } elsif ($node->tag eq 'address' ||
             $node->tag eq 'ol' ||
             $node->tag eq 'ul' ||
             $node->tag eq 'dl' ||
             $node->tag eq 'dd' ||
             $node->tag eq 'dt' ||
             $node->tag eq 'li' ||
             $node->tag eq 'form' ) {
        $node->attr('readability', $node->attr('readability') - 3)
    } elsif ($node->tag eq 'h1' ||
             $node->tag eq 'h2' ||
             $node->tag eq 'h3' ||
             $node->tag eq 'h4' ||
             $node->tag eq 'h5' ||
             $node->tag eq 'h6' ||
             $node->tag eq 'th' ) {
        $node->attr('readability', $node->attr('readability') - 5)
    }
    $node->attr(
        'readability',
        $node->attr('readability') + $self->get_class_weight($node)
    );
}

sub remove_scripts {
    my ($self, $doc) = @_;
    my @scripts = $doc->find('script');

    for (@scripts) {
        if ( !$_->attr('src') ||
             index($_->attr('src'), 'readability') < 0 ||
             index($_->attr('src'), 'typekit') < 0 ) {
            $_->delete;
        }
    }
}

sub get_class_weight {
    my ($self, $node) = @_;
    if (!$self->flag_is_active(FLAG_WEIGHT_CLASSES)) {
        return 0;
    }
    my $weight = 0;

    #Look for a special classname
    if ( my $class_name = $node->attr('class') ) {
        if ( $class_name =~ $HTML::Simplify::Regexp::negative ) {
            $weight -= 25;
        }
        if ( $class_name =~ $HTML::Simplify::Regexp::positive ) {
            $weight += 25;
        }
    }
    #Look for a special ID */
    if ( $node->id ) {
        if ( $node->id =~ $HTML::Simplify::Regexp::negative ) {
            $weight -= 25;
        }
        if ( $node->id =~ $HTML::Simplify::Regexp::positive ) {
            $weight += 25;
        }
    }
    return $weight;
}

sub get_link_density {
    my ($self, $e) = @_;
    my @links = $e->find("a");
    my $text_length = length $self->get_inner_text($e);
    return 0 unless $text_length;

    my $link_length = 0;
    for my $link (@links) {
        $link_length += length $self->get_inner_text($link);
    }
    return $link_length / $text_length;
}

sub get_article_title { #Not Suitable for Japanese Web Sites
    my ($self) = shift;
    my $cur_title = "";
    my $orig_title = "";

    eval{
        $cur_title = $orig_title = $self->document->find('head')->find('title')->as_text;
    };

    if ( $cur_title =~ / [\|\-] / ) {
        $cur_title =~ s/(.*)[\|\-] .*/$1/gi;
        my @words = split(' ', $cur_title);
        if ( @words < 3) {
            $cur_title = $orig_title;
            $cur_title =~ s/[^\|\-]*[\|\-](.*)/$1/gi;
        }
    } elsif ( index( $cur_title, ': ') >= 0 ) {
        $cur_title = $orig_title;
        $cur_title =~ s/.*:(.*)/$1/gi;

        my @words = split(' ', $cur_title);
        if ( @words < 3) {
            $cur_title = $orig_title;
            $cur_title =~ s/[^:]*[:](.*)/$1/gi;
        }
    } elsif ( length($cur_title) > 150 || length ($cur_title) < 15 ) {
        my @h_ones = $self->document->find('h1');
        if ( @h_ones == 1) {
            $cur_title = $h_ones[0]->as_text;
        }
    }
    $cur_title =~ s/$HTML::Simplify::Regexp::trim//gi;

    my @words = split(' ', $cur_title);
    if ( @words <= 4 ) {
        $cur_title = $orig_title;
    }

    my $article_title = HTML::Element->new("H1");
    $article_title->push_content($cur_title);
    return $article_title;
}

sub prep_document {
    my $self = shift;
    my $body = $self->document->find('body');
    if ( !$body ) {
        $body = HTML::Element->new("body");
        $self->document->insert_element($body);
    }
    $body->idf("readabilityBody");

    for my $style ( $self->document->look_down('_tag'=>'link','rel'=>'stylesheet') ) {
        $style->delete;
    }
    for my $style ($self->document->find('style')) {
        $style->delete;
    }

    # Turn all double br's into p's
    # Note, this is pretty costly as far as processing goes. Maybe optimize later.
    my $new_html = $self->document->find('body')->as_HTML;
    $new_html =~ s!$HTML::Simplify::Regexp::replace_brs!</p><p>!g;
    $new_html =~ s!$HTML::Simplify::Regexp::replace_fonts!<$1span>!g;

    my $new_body = HTML::TreeBuilder->new_from_content($new_html);
    $self->document->find('body')->delete;
    $self->document->insert_element($new_body);
}

sub clean_styles {
    my ($self, $e) = @_;
    $e ||= $self->document;
    my @children = $e->content_list;

    return unless $e;

    #Remove any root styles, if we're able.
    if ( !$e->attr('class') || $e->attr('class') ne 'readability-styled' ) {
        # go until there are no more child nodes
        for my $cur (@children) {
            if ( ref $cur ) {
                # Remove style attribute(s) :
                if ( !$e->attr('class') || $e->attr('class') ne 'readability-styled' ) {
                    $cur->attr("style",undef);
                }
                $self->clean_styles($cur);
            }
        }
    }
}

sub kill_breaks {
    my ($self, $e) = @_;
    my $inner = $e->inner_HTML;
    $inner =~ s!$HTML::Simplify::Regexp::kill_breaks!<br />!;
    $e->inner_HTML( $inner );
}

sub get_char_count {
    my ($self, $e, $s ) = @_;
    $s ||= ",";
    my @chars = split($s, $self->get_inner_text($e));
    return @chars-1;
}

sub clean_conditionally {
    my ($self, $e, $tag) = @_;
    return unless $self->flag_is_active(FLAG_CLEAN_CONDITIONALLY);

    my @tag_list = grep { $_ != $e } $e->find($tag);

    # Gather counts for other typical elements embedded within.
    # Traverse backwards so we can remove nodes at the same time without effecting the traversal.
    # TODO: Consider taking into account original contentScore here.
    my $count = 0;
    for my $cur_elm (reverse @tag_list) {
        my $weight = $self->get_class_weight($cur_elm);
        my $content_score = 0;

        if ( ref $cur_elm && $cur_elm->attr('readability') ) {
            $content_score += $cur_elm->attr('readability');
        }

        if ($self->debug) {
            warn sprintf "Cleaning Conditionally %s (%s:%s) %s",
                $cur_elm->tag, ($cur_elm->attr('class') || '') ,( $cur_elm->id || '' ),
                $weight + $content_score;
        }

        if ( $weight + $content_score < 0 ) {
            $cur_elm->delete;
        } elsif ( $self->get_char_count($cur_elm,',') < 10) {
            # If there are not very many commas, and the number of
            # non-paragraph elements is more than paragraphs or other ominous signs, remove the element.
            my @_p  = grep { $_ != $cur_elm } $cur_elm->find("p");
            my $p = @_p;
            my @_img = grep { $_ != $cur_elm } $cur_elm->find("img");
            my $img   = @_img;;
            my @_li = grep { $_ != $cur_elm } $cur_elm->find("li");
            my $li    = @_li - 100;
            my @_input = grep { $_ != $cur_elm } $cur_elm->find("input");
            my $input = @_input;

            if ($self->debug) {
                warn sprintf "Cleaning Conditionally %s (%s:%s) %s\n p: %d img: %d li: %d input:%d",
                    $cur_elm->tag, ($cur_elm->attr('class') || '') ,( $cur_elm->id || '' ),
                    $weight + $content_score, $p, $img, $li, $input;
            }


            my $embed_count = 0;
            my @embeds = $cur_elm->find("embed");
            for my $embed ( @embeds ) {
                if ( $embed->attr('src') !~ $HTML::Simplify::Regexp::videos ) {
                    $embed_count += 1;
                }
            }
            my $link_density = $self->get_link_density($cur_elm);
            my $content_length = length $self->get_inner_text($cur_elm);
            my $to_remove = 0;

            if ( $img > $p ) {
                $to_remove = 1;
            } elsif ( $li > $p && lc $tag ne "ul" && lc $tag ne "ol") {
                $to_remove = 1;
            } elsif ( $input > int($p/3) ) {
                $to_remove = 1;
            } elsif ( $content_length < 25 && ($img == 0 || $img > 2) ) {
                $to_remove = 1;
            } elsif ( $weight < 25 && $link_density > 0.2 ) {
                $to_remove = 1;
            } elsif ( $weight >= 25 && $link_density > 0.5 ) {
                $to_remove = 1;
            } elsif ( ($embed_count == 1 && $content_length < 75) || $embed_count > 1 ) {
                $to_remove = 1;
            }

            if( $to_remove ) {
                warn 'DELETE By Cleaning Conditinally';
                $cur_elm->delete;
            }
        }
    }
}

sub clean {
    my ($self, $e, $tag) = @_;
    my @target_list = $e->find($tag);
    my $is_embed = ($tag eq 'embed');

    for my $cur_elm (@target_list) {
        #Allow youtube and vimeo videos through as people usually want to see those.
        if ( $is_embed ) {
            my $attribute_values = "";
            for ( $cur_elm->all_attr_names ) {
                next if index($_,'_') == 0;
                $attribute_values .= ($cur_elm->attr($_) . '|');
            }
            # First, check the elements attributes to see if any of them contain youtube or vimeo
            if ( $attribute_values !~ $HTML::Simplify::Regexp::videos ) {
                next;
            }
            # Then check the elements inside this element for the same.
            if ( $cur_elm->inner_HTML !~ $HTML::Simplify::Regexp::videos ) {
                next;
            }
        }
        $cur_elm->delete;
    }
}

sub clean_headers {
    my ($self, $e) = @_;

    for (1..2) {
        my @headers = $e->find('h' . $_);
        for my $header (@headers) {
            if ( $self->get_class_weight($header) < 0 ||
                 $self->get_link_density($header) > 0.33 ) {
                $header->delete;
            }
        }
    }
}

sub prep_article {
    my ($self, $article_content) = @_;
    $self->clean_styles($article_content);
    $self->kill_breaks($article_content);

    #Clean out junk from the article content
    $self->clean_conditionally($article_content, "form");
    $self->clean($article_content, "object");
    $self->clean($article_content, "h1");



    # If there is only one h2, they are probably using it
    # as a header and not a subheader, so remove it since we already have a header.
    my @_h2 = $article_content->find('h2');
    if( @_h2 == 1) {
        $self->clean($article_content, "h2");

    }
    $self->clean($article_content, "iframe");
    $self->clean_headers($article_content);

    #Do these last as the previous stuff may have removed junk that will affect these */
    $self->clean_conditionally($article_content, "table");
    $self->clean_conditionally($article_content, "ul");
    $self->clean_conditionally($article_content, "div");

    #Remove extra paragraphs
    my @article_paragraphs = $article_content->find('p');
    for my $ap (@article_paragraphs) {
        my @img = $ap->find('img');
        my @embed = $ap->find('embed');
        my @object = $ap->find('object');

        if ( @img == 0 && @embed == 0 && @object == 0 && !$self->get_inner_text($ap,0) ) {
            $ap->delete;
        }
    }
    my $inner = $article_content->inner_HTML;
    $inner =~ s/<br[^>]*>\s*<p/<p/gi;
    $article_content->inner_HTML($inner);
}

sub grab_article {
    my ($self, $page) = @_;
    my $strip_unlikely_candidates = $self->flag_is_active(FLAG_STRIP_UNLIKELYS);

    $page = $page ? $page : $self->document->find('body');

    my $page_cache_html = $page->as_HTML;
    my @all_elements = $page->look_down(sub{1});

    #First, node prepping. Trash nodes that look cruddy (like ones with the class name "comment", etc), and turn divs
    # into P tags where they have been used inappropriately (as in, where they contain no other block level elements.)
    # Note: Assignment from index for performance. See http://www.peachpit.com/articles/article.aspx?p=31567&seqNum=5
    # TODO: Shouldn't this be a reverse traversal?

    my @nodes_to_score;
    for my $node (@all_elements) {
        #Remove unlikely candidates
        if ($strip_unlikely_candidates) {
            my $unlikely_match_string = ($node->attr('class') || '' ) . ($node->id || '');
            if (
                $unlikely_match_string =~ /$HTML::Simplify::Regexp::unlikely_candidate/g &&
                $unlikely_match_string !~ /$HTML::Simplify::Regexp::ok_maybe_its_a_candidate/g &&
                $node->tag ne "body"
            ) {
                if ( $self->debug ) {
                    warn "Removing unlikely candidate - " . $unlikely_match_string;
                }
                $node->delete;
                next;
            }
        }

        if ( $node->tag && ($node->tag eq "p" || $node->tag eq "td" || $node->tag eq "pre")) {
            push @nodes_to_score, $node;
        }

        #Turn all divs that don't have children block level elements into p's
        if ( $node->tag && $node->tag eq "div") {
            if ($node->inner_HTML !~ /$HTML::Simplify::Regexp::div_to_p_elements/g ) {
                $node->tag('p');
                push @nodes_to_score, $node;
            } else {
                # EXPERIMENTAL
                if ( $self->debug ) {
                    warn sprintf "dvi_to_p %s(%s:%s)",
                        $node->tag, ($node->attr('class') ||''), ($node->id || '');
                }
                for my $child_ref ($node->content_refs_list) {
                    next if ref $$child_ref;

                    my $p = HTML::Element->new('p');
                    $p->attr('style',"display: inline");
                    $p->attr('class','readability-styled');
                    $p->push_content($$child_ref);
                    $child_ref = \$p;
                }
            }
        }
    }
    #Loop through all paragraphs, and assign a score to them based on how content-y they look.
    #Then add their score to their parent node.
    #A score is determined by things like number of commas, class names, etc. Maybe eventually link density.
    my @candidates;
    for my $node (@nodes_to_score) {

        my $parent_node = $node->parent;
        my $grand_parent_node = $parent_node ? $parent_node->parent : undef;
        my $inner_text  = $self->get_inner_text($node);

        if ( $self->debug ) {
            warn sprintf "NodesToScore: %s(%s:%s:%d) %s",
                $node->tag, ($node->attr('class') || '') ,
                ( $node->id || '' ), length $inner_text,
                ($parent_node ? ($parent_node->tag . ' ' .($parent_node->attr('class') ||'') ): 'NoParent');
        }

        if (!$parent_node || !$parent_node->tag) {
            next;
        }

        #If this paragraph is less than 25 characters, don't even count it.
        next if length $inner_text < 25;

        # Initialize readability data for the parent.
        unless ( defined $parent_node->attr('readability') ) {
            $self->initialize_node($parent_node);
            push @candidates, $parent_node;
        }

        # Initialize readability data for the grandparent.
        if ( $grand_parent_node &&
             not defined $grand_parent_node->attr('readability') &&
             $grand_parent_node->tag
         ) {
            $self->initialize_node($grand_parent_node);
            push @candidates, $grand_parent_node;
        }

        my $content_score = 0;
        # Add a point for the paragraph itself as a base.
        $content_score += 1;

        #Add points for any commas within this paragraph */
        my @commas = split(',', $inner_text);
        $content_score += scalar @commas;

        #For every 100 characters in this paragraph, add another point. Up to 3 points.
        $content_score += min( int( length($inner_text) / 100), 3 );

        #Add the score to the parent. The grandparent gets half. */
        $parent_node->attr('readability', $parent_node->attr('readability') + $content_score);

        if ( $grand_parent_node ) {
            $grand_parent_node->attr(
                'readability',
                $grand_parent_node->attr('readability') + $content_score/2
            );
        }
    }

    # After we've calculated scores, loop through all of the possible candidate nodes we found
    # and find the one with the highest score.
    my $top_candidate;
    for my $candidate (@candidates) {
        #Scale the final candidates score based on link density. Good content should have a
        #relatively small link density (5% or less) and be mostly unaffected by this operation.
        if ( $self->debug ) {
            warn 'Candidate: ' . $candidate . " (" .
                ($candidate->attr('class') || '') . ":" . ( $candidate->id || '' ). ") with score " .
                $candidate->attr('readability');
        }

        $candidate->attr(
            'readability',
            $candidate->attr('readability') * ( 1 - $self->get_link_density($candidate) )
        );


        if ( !$top_candidate ||
             $candidate->attr('readability') > $top_candidate->attr('readability')
         ) {
            $top_candidate = $candidate;
        }
    }

    # If we still have no top candidate, just use the body as a last resort.
    # We also have to copy the body node so it is something we can modify.

    if ( !$top_candidate || $top_candidate->tag eq "body") {
        $top_candidate = HTML::Element->new("div");
        $top_candidate->inner_HTML($page->inner_HTML);
        $page->inner_HTML("");
        $page->push_content($top_candidate);
        $self->initialize_node($top_candidate);
    }

    # Now that we have the top candidate, look through its siblings for content that might also be related.
    #Things like preambles, content split by ads that we removed, etc.

    my $article_content  = HTML::Element->new("div");
    my $sibling_score_threshold
        = max(10, $top_candidate->attr('readability') * 0.2);
    my @sibling_nodes = $top_candidate->parent->content_list;
    for my $sibling_node (@sibling_nodes) {
        my $append = 0;

        next unless ref $sibling_node;

        if ( $sibling_node == $top_candidate) {
            $append = 1;
        }

        my $content_bonus = 0;
        #Give a bonus if sibling nodes and top candidates have the example same classname

        if ( $sibling_node->attr('class') &&
             $top_candidate->attr('class') &&
             $sibling_node->attr('class') eq $top_candidate->attr('class') &&
             $top_candidate->attr('class') ne "") {
             $content_bonus += $top_candidate->attr('readability') * 0.2;
        }

        if ( $sibling_node->attr('readability') &&
             $sibling_node->attr('readability') + $content_bonus >= $sibling_score_threshold
         ) {
            $append = 1;
        }

        if ( $sibling_node->tag eq 'p' ) {
            my $link_density = $self->get_link_density($sibling_node);
            my $node_content = $self->get_inner_text($sibling_node);
            my $node_length  = length $node_content;

            if ( $node_length > 80 && $link_density < 0.25 ) {
                $append = 1;
            } elsif ( $node_length < 80 &&
                      $link_density == 0 &&
                      $node_content =~ /\.( |$)/) {
                $append = 1;
            }
        }

        if ( $append ) {
            my $node_to_append;
            if ( $sibling_node->tag ne "div" && $sibling_node->tag ne "p") {
                #We have a node that isn't a common block level element, like a form or td tag.
                #Turn it into a div so it doesn't get filtered out later by accident.
                $node_to_append = $sibling_node;
                $node_to_append->tag('div');
            } else {
                $node_to_append = $sibling_node;
            }
            #To ensure a node does not interfere with readability styles, remove its classnames */
            $node_to_append->attr('class',"");

            #Append sibling and subtract from our list because it removes the node when you append to another node
            $article_content->push_content($node_to_append);
        }
    }
    #So we have all of the content that we need. Now we clean it up for presentation.
    $self->prep_article($article_content);

    # Now that we've gone through the full algorithm, check to see if we got any meaningful content.
    # If we didn't, we may need to re-run grabArticle with different flags set. This gives us a higher
    # likelihood of finding the content, and the sieve approach gives us a higher likelihood of
    # finding the -right- content.

    if ( length $self->get_inner_text($article_content, 0) < 250) {
        $page->inner_HTML($page_cache_html);

        if ( $self->flag_is_active(FLAG_STRIP_UNLIKELYS) ) {
            $self->remove_flag(FLAG_STRIP_UNLIKELYS);
            return $self->grab_article($page);
        } elsif ( $self->flag_is_active(FLAG_WEIGHT_CLASSES) ) {
            $self->remove_flag(FLAG_WEIGHT_CLASSES);
            return $self->grab_article($page);
        } elsif ($self->flag_is_active(FLAG_CLEAN_CONDITIONALLY)) {
            $self->remove_flag(FLAG_CLEAN_CONDITIONALLY);
            return $self->grab_article($page);
        } else {
            return;
        }
    }
    return $article_content;
}

sub simplify {
    my ($self, $html) = @_;
    $self->document = HTML::TreeBuilder->new_from_content($html) if $html;

    $self->prep_document;
    $self->remove_scripts($self->document);

    return $self->grab_article($html);
}

sub get_title {
    my $self = shift;
    return $self->get_article_title;
}


sub get_inner_text {
    my ($self, $e, $normalize_spaces) = @_;
    my $text_content = $e->as_text;

    $normalize_spaces = 1 unless defined $normalize_spaces;
    $text_content =~ s/$HTML::Simplify::Regexp::trim//gi;

    if ($normalize_spaces) {
        $text_content =~ s/$HTML::Simplify::Regexp::normalize//gi;
    }
    return $text_content;
}
1;

package HTML::Element;
sub inner_HTML {
    my ($self, $html)  = @_;
    if ($html) {
        $self->delete_content;
        my $new_node = HTML::TreeBuilder->new_from_content($html);
        my @elms = $new_node->find('body')->content_list;
        for (@elms) {
            $self->push_content($_);
        }
    }

    my @children = $self->content_list;
    my $res = '';
    for (@children) {
        if ( ref $_ eq 'HTML::Element' ) {
            $res .= $_->as_HTML;
        } else {
            $res .= $_;
        }
    }
    return $res;
}

1;
