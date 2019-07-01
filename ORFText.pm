package ORFText;
our $VERSION = '2.00';

=pod Project: ORFText.pm
 - NOW: a module returning data structure with inline-html
 - LATER: instead of returning html return a syntax tree
   html tag insertion is limited to {{{text mangling}}}
	- html_escape # HTML
	- emphasize   # HTML
	- rehyphenate # UNICODE
	- linebreak   # HTML
	- $ORF_idio_slash (negative lookahead against </foo>)

  TODO - URL references (">>tirol.ORF.at")
  (C) 2016-2019 Tobias Girstmair
  Extracts hypertext formatted news from ORF Teletext
  reads and decodes pages from dvbtext's spool directory. 
=cut

use 5.010;
use strict;
use warnings;
use utf8;
use Data::Dumper;

use base 'Exporter';
our @EXPORT = qw(html weather $TABLE_YES $REF_MARKUP);
our $TABLE_YES = 0; # enable that to parse tables w/ vtx2ascii
our $REF_MARKUP = sub { return "<u>$_[0]<b>$_[1]</b></u>"};

### i/o {{{
use constant {
	VTX_HEADER => 12,
	TTX_HEADER =>  8,
	STATUS_BAR => 32,
};
sub slurp_lines { my ($file) = @_;
	open VTX, "<:raw", "$file" or die ("Can'r open $file");

	# read page number:
	seek VTX, VTX_HEADER+TTX_HEADER, 0;
	read VTX, my $pagenum, 3;
	$pagenum &= "\x7f" x 3; # zero out parity bit

	# read page content:
	seek VTX, VTX_HEADER+TTX_HEADER+STATUS_BAR, 0;
	read VTX, my $raw_text, 40*23;
	$raw_text &= ("\x7f" x length $raw_text); # zero out parity bit
	# NOTE: unpack chomps strings when using the 'A' template.
	my @lines = map {tr/[\\]{|}~`@/ÄÖÜäöüß°§/r} unpack 'A40'x23, $raw_text;

	close VTX;
	my ($subpage) = $file=~m/\d{3}_(\d{2})\.vtx/;
	return ($pagenum, $subpage, @lines);
}
### }}}
### Teletext Grammar {{{
# control characters defined in ETSI EN 300 706 (2003) 12.2 Table 26
my $ORF_TTX_GRAMMAR = qr {
(?(DEFINE)
    (?<cntrl>
        (?>(?&a_color))    | (?>(?&g_color))
        | (?>(?&flash))    | (?>(?&steady))
        | (?>(?&endbox))   | (?>(?&startbox))
        | (?>(?&n_size))   | (?>(?&d_height))
        | (?>(?&d_width))  | (?>(?&d_size))
        | (?>(?&conceal))  | (?>(?&esc))
        | (?>(?&g_cont))   | (?>(?&g_sep))
        | (?>(?&bg_black)) | (?>(?&bg_new))
        | (?>(?&g_hold))   | (?>(?&g_release))
        | (?>(?&fake))
    )
    (?<a_color>
        (?>(?&a_blk))
        | (?>(?&a_red))
        | (?>(?&a_grn))
        | (?>(?&a_ylw))
        | (?>(?&a_blu))
        | (?>(?&a_mgt))
        | (?>(?&a_cya))
        | (?>(?&a_wht))
    )
    (?<g_color>
        (?>(?&g_blk))
        | (?>(?&g_red))
        | (?>(?&g_grn))
        | (?>(?&g_ylw))
        | (?>(?&g_blu))
        | (?>(?&g_mgt))
        | (?>(?&g_cya))
        | (?>(?&g_wht))
    )
    (?<a_blk> \x00) (?<g_blk> \x10) (?<blk> (?&a_blk)|(?&g_blk))
    (?<a_red> \x01) (?<g_red> \x11) (?<red> (?&a_red)|(?&g_red))
    (?<a_grn> \x02) (?<g_grn> \x12) (?<grn> (?&a_grn)|(?&g_grn))
    (?<a_ylw> \x03) (?<g_ylw> \x13) (?<ylw> (?&a_ylw)|(?&g_ylw))
    (?<a_blu> \x04) (?<g_blu> \x14) (?<blu> (?&a_blu)|(?&g_blu))
    (?<a_mgt> \x05) (?<g_mgt> \x15) (?<mgt> (?&a_mgt)|(?&g_mgt))
    (?<a_cya> \x06) (?<g_cya> \x16) (?<cya> (?&a_cya)|(?&g_cya))
    (?<a_wht> \x07) (?<g_wht> \x17) (?<wht> (?&a_wht)|(?&g_wht))
    (?<flash>    \x08) (?<steady>    \x09)
    (?<endbox>   \x0a) (?<startbox>  \x0b)
    (?<n_size>   \x0c) (?<d_height>  \x0d)
    (?<d_width>  \x0e) (?<d_size>    \x0f)
    (?<conceal>  \x18)
    (?<g_cont>   \x19) (?<g_sep>     \x1a)
    (?<esc>      \x1b) # switch G0 charset
    (?<bg_black> \x1c) (?<bg_new>    \x1d)
    (?<g_hold>   \x1e) (?<g_release> \x1f)

    (?<ws> (?&cntrl)|[ ])
    (?<_> (?&ws)*)
    (?<WHT> (?&a_wht)|(?&g_wht)|[ ])
    (?<S> \A ^(?&_))
    (?<E> (?&_)$ \Z)

    # graphics characters:
    (?<g_34> \x2c) # middle row (sixel 2^3 and 2^4)

    # fake ctrlchar to mark up subheadings with emphasize():
    (?<fake> \x7f)
)
}xms;
# ORF Specific Shortcuts:
# a. page parsing:
my $ORF_10x_title    = qr/(?&S)(?&WHT)(?&bg_new)((?&a_red)(?&_)[^\x00]+?)(?&E)$ORF_TTX_GRAMMAR/;
my $ORF_10x_text_1   = qr/(?&S)(?&WHT)(?&bg_new)[^\x01](.+?)(?&E)$ORF_TTX_GRAMMAR/; # text variant 1: non-emph. beginning
my $ORF_10x_text_2   = qr/(?&S)(?&WHT)(?&bg_new)((?&a_red).*(?&a_blk).*)(?&E)$ORF_TTX_GRAMMAR/; # text variant 2: non-whole-line-emph. at beginning
my $ORF_10x_text     = qr/(?|$ORF_10x_text_1|$ORF_10x_text_2)/; # combine with "branch reset" pattern
my $ORF_11x_title    = qr/(?&S)((?&a_cya)[^\x07]+?)(?&E)$ORF_TTX_GRAMMAR/;
my $ORF_11x_subtitle = qr/^(?&a_ylw)([^\x07]+?)(?&E)$ORF_TTX_GRAMMAR/; # yellow subheadings (not inline-yellow)
my $ORF_11x_text_1   = qr/^(?&WHT)([^\x1d].+)(?&E)$ORF_TTX_GRAMMAR/; # text variant 1: starts with non-emphasised word (\x1d: don't match subres_2)
my $ORF_11x_text_2   = qr/^((?&a_cya).*(?&a_wht).*)(?&E)$ORF_TTX_GRAMMAR/; # text variant 2: starts with non-full-length emphasis
my $ORF_11x_text_3   = qr/^(?&g_red)(?&g_34)+((?&a_cya).+?)(?:(?&g_red)(?&g_34)+|$)$ORF_TTX_GRAMMAR/; # text variant 3: very last line (red band below 11x pages)
my $ORF_11x_text_xtra= qr/^((?:(?&a_ylw)|(?&a_grn)).*(?:(?&a_wht).*)?)(?&E)$ORF_TTX_GRAMMAR/; # hardly used; sort of paragraph heading (->121-20190526-greentext.vtx)
my $ORF_11x_text     = qr/(?|$ORF_11x_text_1|$ORF_11x_text_2|$ORF_11x_text_3)/; # combines the regexes above into a single match group; (?|) resets the backref-number
my $ORF_70x_subres   = qr/(?&S)(?&a_wht)(?&bg_new)(?&a_red)(?&_)(.+)(?&_)(?&bg_black)(?&E)$ORF_TTX_GRAMMAR/;
my $ORF_subressort   = qr/(?&S)(.*?)(?&E)$ORF_TTX_GRAMMAR/;
my $ORF_ressort_topic= qr/(?&S)(?&a_wht)(?&_)(.+?)(?&_)(?&bg_new)(?&_)(.*?)(?&_)(?&bg_black)?(?&E)$ORF_TTX_GRAMMAR/; # topic=fallback title
my $ORF_emptyline    = qr/^(?&ws)*$ORF_TTX_GRAMMAR$/;
my $ORF_advert       = qr/^[\001\002\004](?&bg_new)(?:[\000\001\007](?!(?&cntrl))|[\003\a]\r|\r\0)(?&_)(.+)(?&_)$ORF_TTX_GRAMMAR/;
# b. reference and emphasis matching:
my $ORF_ref_name_1   = qr/([^\|]*?>+ ?(?:S. ?)?)/;  # "Hofer >", "Opposition > S. "
my $ORF_ref_name_2   = qr/(>+[^\|]*?)/;    # ">Platter "
my $ORF_ref_name     = qr/(?|$ORF_ref_name_1|$ORF_ref_name_2)/;
my $ORF_ref_nums     = qr/(\d{3}(?:[-\/]\d{3})?)/; # "113-116", "127/128", "115"
my $ORF_reference    = qr/(?:(?&a_red)|(?&a_cya)) *$ORF_ref_name$ORF_ref_nums(?&_)(?:\||$)$ORF_TTX_GRAMMAR/;
my $ORF_10x_emph     = qr/(?&a_red)(.*?)(?:(?&a_blk)|(\|)(?! ?(?&a_red))|$)$ORF_TTX_GRAMMAR/;  # 10x: red-on-white
my $ORF_11x_emph_y   = qr/(?&a_ylw)(.*?)(?:(?&a_wht)|(\|)(?! ?(?&a_ylw))|$)$ORF_TTX_GRAMMAR/;  # 11x: yellow-on-black
my $ORF_11x_emph_c   = qr/(?&a_cya)(.*?)(?:(?&a_wht)|(\|)(?! ?(?&a_cya))|$)$ORF_TTX_GRAMMAR/;  # 11x: cyan-on-black
my $ORF_11x_emph_g   = qr/(?&a_grn)(.*?)(?:(?&a_wht)|(\|)(?! ?(?&a_grn))|$)$ORF_TTX_GRAMMAR/;  # 11x: green-on-black
my $ORF_emphasis     = qr/(?|$ORF_10x_emph|$ORF_11x_emph_y|$ORF_11x_emph_c|$ORF_11x_emph_g)/;
my $ORF_subtitle     = qr/(?&fake)(.+?)\|$ORF_TTX_GRAMMAR/; # uses fake ctrlchar to differentiate from yellow-emph
# c. rehyphenation:
my $ORF_hy_ergaenz   = qr/(\b\w+\b)-\| ?\b(und|oder)\b ?/; # (Ergänzungsstrich, e.g. "Staats- und Regierungschefs")
my $ORF_hy_trenn     = qr/([[:lower:]])-\| ?([[:lower:]])/; # (Trennstrich)
my $ORF_hy_binde     = qr/(\S)-\| ?(\S)/; # (Bindestrich, e.g. "Mikl-Leitner", "30-jaehriges", etc.)
my $ORF_hy_gedanken  = qr/[ |]-[ |]/; # (Gedankenstrich)
# d. unsave space / idiosyncrasies:
my $ORF_idio_comma   = qr/(?|([[:alnum:])"]),([[:alpha:]])|([[:alpha:])"]),([[:alnum:]]))/;  # comma: not between 5,4%
my $ORF_idio_period  = qr/(?|([[:alnum:])"])\.([[:upper:]])|([[:alpha:])"])\.([[:digit:]]))/;  # period: not between 1.000.000, www.foo.org
my $ORF_idio_URL     = qr/(\S+)\. (ORF\.at)/;  # special case for e.g. tirol.ORF.at
my $ORF_idio_colon   = qr/(?|([[:alnum:]]):([[:alpha:]])|([[:alpha:]]):([[:alnum:]]))/;  # colon: not between 1:0
my $ORF_idio_slash   = qr/( ?)(?!<)\/( ?)/; # fix foo/bar at end of line ("ÖVP/ FPÖ"->"ÖVP/FPÖ"); negative lookahead to not match </foo> from emphasize()
# e. trimming, better-line-breaks, misc.:
my $ORF_ws           = qr/(?&ws)$ORF_TTX_GRAMMAR/;  # Note: control characters are rendered as whitespace; included as well
my $ORF_is_table     = qr/[\x21-\x7e]((?&a_color)|[ ]){2,}[\x21-\x7e]|^\x11\x2c+\x06Liga-Start:$ORF_TTX_GRAMMAR/; # Warn: breaks when line3 is "m/n" -- filter beforehand
my $ORF_bleedover    = qr/(.+?)  +(.+)/;  # when two-line ressort (left-aligned) bleeds into subressort (right-aligned)
# Note: [^\xNN] makes sure each line is only matched by 1 regex
# Note: inline markup is terminated by a ctrlchar (?&a_xxx), linebreak (\|) or end of string ($).
#       negative lookahead after \| allows us to match multiline-emphasis in one go
# Note: ORF_hy_* removes linebreaks; have to sanitize lines not ending with a hyphen seperately
# Note: is_table: matches tables by alignment-whitespace; 215-219 have 'Liga-Start' in last line
# }}}
### text mangling {{{
sub emphasize { for (@_) {
	s{$ORF_reference}{ @{[$REF_MARKUP->($1, $2)]} }g;
	s{$ORF_subtitle} {<h4>$1</h4>}g;
	s{$ORF_emphasis} { <i>$1</i> $2}g;
}}
sub rehyphenate { for (@_) {
	use charnames ();
	s{$ORF_hy_ergaenz} {$1- $2 }g;
	s{$ORF_hy_trenn}   {$1\N{SOFT HYPHEN}$2}g;
	s{$ORF_hy_binde}   {$1-$2}g;
	s{$ORF_hy_gedanken}{ \N{EN DASH} }g;
}}
sub linebreak { for (@_) {
	s{\|\|+}{<p>}g;   # mark up paragraphs
	s/(<p>)+$//gs;    # remove if last
	s{\| *}{ }g;        # remove other line-markers
}}
sub unsave_space { for (@_) {
	s{$ORF_idio_comma} {$1, $2}g;
	s{$ORF_idio_period}{$1. $2}g;
	s{$ORF_idio_colon} {$1: $2}g;
	s{$ORF_idio_slash} {$1/$1}g;
	s{$ORF_idio_URL}   {$1.$2}g;
}}
sub trim_ws { for (@_) {
	# Note: also removes cntrl chars
	s/^$ORF_ws+|$ORF_ws+$//g;
	s/$ORF_ws+/ /g; # keep a space between words
}}
sub html_escape { for (@_) {
	s/&/&amp;/g;
	s/</&lt;/g;
	# don't escape '>' or ref.matching breaks!
}}
=pod "Try to infer linebreaks without empty line"
    For each line, check if the first word from the next line would fit in the same line
    This heuristic is not flawless; ignoring short words helps a lot, but isn't perfect either.
    To match each line and the next word (which are overlapping), forward lookahead is used.
=cut
sub better_line_breaks {
	return if $_[0] =~ m/\|\|/; # mostly, only cramped pages (i.e. those without any empty lines) need this treatment.
	# matches each physical line and the next word:
	my @lines = $_[0] =~ m/(?=(?:^|\|)(.*?(?:\||$)[\x00-\x20]*?\w+))/sg;

	my @text = split /\|/, $_[0];
	for (0 .. $#lines) {
		$text[$_] .= "|" if (length $lines[$_] < 39 and $lines[$_]=~m/\w{6,}$/); # double up "|" to make empty line
	}
	$_[0] = join '|', @text;
}
### }}}

sub html { my ($file) = @_;
	my ($title, $text, $subres, $ressort, $topic);
	my ($title_2, $text_2, $subres_2);
	my $advert;
	my $is_table = 0;

	my ($page, $subpage, @lines) = slurp_lines ($file);

	# 1. parse header:
	($subres) = (shift @lines) =~ m{$ORF_subressort};
	($ressort, $topic) = (shift @lines) =~ m{$ORF_ressort_topic};
	($ressort, $subres) = ("$1 $ressort", $2) if ($subres =~ m/$ORF_bleedover/);
	$subres = $topic if ($page =~ m/70./); # Bundesländer pages
	my ($page_x_of_y) = (shift @lines) =~ m{([0-9/]+)}; # will be discarded

	# 2. parse body:
	for (@lines) {
		if (/$ORF_emptyline/) {
			$text .= "|" if defined $text;
		} elsif (m{$ORF_is_table} and $page =~/2..|7[56]./) {
			return {tabular=>1, raw=>\@lines, title=>$topic,page=>$page,subpage=>$subpage, ressort=>$ressort,subressort=>$subres};
		} elsif ($page < 111) {
			if    (m{$ORF_10x_title}) { (defined $text?$text:$title) .= "$1|"; }
			elsif (m{$ORF_10x_text})  { $text .= "$1|"; }
			elsif (m{$ORF_advert})   {$advert .= "$1|" if defined $text;} # WARN: this parses ads
			# NOTE: ads only appear after the text; "ads" before it are category pages, which we don't display at all
		} elsif ($subres_2) { # second snippet of 70x page
			if    (m{$ORF_11x_title}) { $title_2 .= "$1|"; }
			elsif (m{$ORF_11x_text})  { $text_2 .= "$1|" }
		} else {
			if    (m{$ORF_11x_title})    { (defined $text?$text:$title) .= "$1|"; }
			elsif (m{$ORF_11x_subtitle}) { (length $title?$text:$title) .= "\x7f$1|"; }
			elsif (m{$ORF_11x_text})     { $text .= "$1|"; }
			elsif (m{$ORF_11x_text_xtra}){ $text .= "|$1||"; }
			elsif (m{$ORF_70x_subres})   { $subres_2 = $1; }
			# TEMP: display other-colored text as normal:
			elsif (m{^(?&a_color)$ORF_TTX_GRAMMAR}) {$text.="|{ $_ }|";}
		}

		$is_table += !!(defined $text and m{$ORF_is_table});
	}

	# 3. post-processing
	if ($topic =~ /\bPresse zum\b/) {
		# Pressespiegel: use topic as title; TODO: requires testing
		$text = "$title $text";
		$title = $topic;
	} else {
		# otherwise: only use topic if no title (6xx has neither)
		$title //= $topic || "$ressort - $subres";
	}
	if ($is_table > 1) {  # NOTE: we ignore a 1-off double-spacing mistake (quite common)
		$text =~ s/(?&cntrl)$ORF_TTX_GRAMMAR/ /g; # remove all markup/colors
		$text =~ s/[|{}]+/||/g; # force new paragraph for each ttx-line
	}
	better_line_breaks ($text); # tries to guess where a line break should be

	html_escape ($text, $title, $advert//(), $text_2//(), $title_2//());      # HTML
	emphasize   ($text,         $advert//(), $text_2//());                    # HTML
	trim_ws     ($text, $title, $advert//(), $text_2//(), $title_2//()); 
	rehyphenate ($text, $title, $advert//(), $text_2//(), $title_2//());      # UNICODE
	linebreak   ($text, $title, $advert//(), $text_2//(), $title_2//());      # HTML
	unsave_space($text, $title, $advert//(), $text_2//(), $title_2//());

	return {
		title => $title,
		text  => $text,
		topic => $topic,
		page  => $page,
		subpage => defined $subres_2? 'A': 0+($subpage//0),
		ressort => $ressort,
		subressort => $subres,
		advert => $advert,
	    }, defined $subres_2? {
		title => $title_2,
		text  => $text_2,
		topic => "",
		page  => $page,
		subpage => 'B',
		ressort => $ressort,
		subressort => $subres_2,
	}: undef;
}

sub weather { my ($spool, $city) = @_;
	my $s = qr{[\x00-\x20]+};
	my $S = qr{[^\x00-\x20]+?};
	my %weather;
	for (<$spool/601_01.vtx $spool/6{0[2-9],10}_??.vtx>) {
		my ($page, $subpage, @lines) = slurp_lines ($_);
		for (grep /${s}$city/, @lines) {
			my ($loc, $time, $wetter, $temp) =
			  m/$s(.*?)$s($S)h$s(.*?)$s([-0-9,°]+)$s?/;

			$weather{time} = "$time:00";
			$weather{location} = $loc;
			$weather{weather} = $wetter;
			$weather{temperature} = $temp;
			return %weather if $temp;
		}
	}
	return undef;
};
1; # vim:foldmethod=marker
