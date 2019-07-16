#!/usr/bin/perl -X
# vim: foldmethod=marker

use strict;
use warnings;
use 5.010;
use utf8;use open qw/:std :utf8/;

use ORFText;
use Text::Wrap;
$Text::Wrap::columns = 60;

=pod
 ORFText News for VT100 compatible terminals
 intended to be called like so (query strings supported):
	curl -s http://foo/ | less -R
TODO: 
 * 
=cut

my @pages = (
	101, 113 .. 125,  # Politik: Österreich/EU
	     127 .. 134,  # Politik: International
	102,#136 .. 144,  # Chronik
#	     701 .. 709   # Bundesländer (W-NÖ-B-OÖ-S-T-V-K-St)
#	     471 .. 478   # Nachrichten leicht verständlich
#	103, 146 .. 149   # Leute
#	104, 151 .. 159   # Wirtschaft
#	     161,167,169, # Börse
#	     170,172,174  # -"-
#	105, 203 .. 209,  # Sport vom Tag
#	     210 .. 259,  # Sportarten
#	     261 .. 278,  # Wintersport & Großereignisse
#	107,110,191..198, # Show und Kultur
	108,#461 .. 465,  # Web/Media
#	     468 .. 469,  # Webtipps
# Special Flags:
	"_noqna",         # hide Q-and-A
);

if ($ENV{QUERY_STRING}) {
	@pages = split /&/, ($ENV{QUERY_STRING} =~ s/(\d{3})-(\d{3})/${\join'&',$1..$2}/gr);
}

print "Content-type: text/plain\r\n\r\n";

# terminal output formatting {{{
my $BOLD = "\033[1m";
my $ITAL = "\033[3m";
my $GREY = "\033[2m";
my $INVR = "\033[7m";
my $RESET= "\033[0m";
$ORFText::REF_MARKUP = sub { my ($text, $ref) = @_;
	return "$text<b>$ref</b>"; #Note: can't put escape sequences here, or they'll be dropped by ORFText::trim_ws()
};
sub format_table {
	my $text = join("\n",map{s/[\x00-\x20]/ /gr}@{%{$_[0]}{raw}})=~s/^ ,,+//msr=~s/\n+$//r;
	return {%$_, text=>$text};
}
sub format_vt100 { my %page = %{$_[0] or return};
	no warnings 'numeric';
	use List::Util qw[max];
	sub ifdef { $_[1]? "$_[0]$_[1]":"" }
	my $pagespec = substr($page{page},0,1) ."00/$page{page}_000".max($page{subpage},1);
	my $text = $page{text};
	$text =~ s{<p>}{\n}g;
	$text =~ s{<i>(.*?)</i>}{${ITAL}$1${RESET}}g;
	$text =~ s{<b>(.*?)</b>}{${BOLD}$1${RESET}}g;
	$text =~ s{<h4>(.*?)</h4>}{\n${BOLD}$1${RESET}\n}g;
	$text =~ s{\N{SOFT HYPHEN}}{}g;
	$text =~ s{&lt;}{<}g;
	$text =~ s{&amp;}{&}g;
	$text = wrap('', '', $text);

	return <<"HTML";
${GREY}$page{page}${\ifdef('.',$page{subpage})}: ${RESET}${BOLD}$page{title}${RESET}
$text

HTML
}
# }}}
# headings {{{
my %headings = (
	101 => "Politik: Österreich/EU",
	127 => "Politik: International",
	102 => "Chronik",
	103 => "Leute",
	104 => "Wirtschaft",
	161 => "Börse",
	105 => "Sport",
	 #203 => "Sport vom Tag",
	 #260 => "Wintersport und Großereignisse"
	106 => "Fernsehen",
	108 => "Multimedia",
	107 => "Kultur &amp; Show", # XXX: this will show it multiple times!
	110 => "Kultur &amp; Show",
	109 => "Wetter",
	471 => "Nachrichten leicht verständlich",
	481 => "Nachrichten leichter verständlich",
	701 => "Wien",
	702 => "Niederösterreich",
	703 => "Burgenland",
	704 => "Oberösterreich",
	705 => "Salzburg",
	706 => "Tirol",
	707 => "Vorarlberg",
	708 => "Kärnten",
	709 => "Steiermark",

);
# }}}
# html-head {{{
print <<'EOF';
   ___  ___ ___ _____        _   
  / _ \| _ \ __|_   _|____ _| |_ 
 | (_) |   / _|  | |/ -_) \ /  _|
  \___/|_|_\_|   |_|\___/_\_\\__|

EOF
# }}}
my (@all, @nonempty);
page:foreach (grep/[0-9]/,@pages) {
	print "${BOLD}$headings{$_}${RESET}\n\n" if $headings{$_};

	my $pageno = $_;
	push @all, $pageno;
	foreach (glob "/run/ttxd/spool/2/${_}_*.vtx") {
		my $file_age = time - (stat)[9];
		next if $file_age > 300;

		for (ORFText::html($_)) {
			next unless $_; # fail req'd for $nonempty
			if ("_noqna" ~~ @pages) { # hide Q-and-A
				next page if %{$_}{text}=~m@[Aa]lle Fra.?gen/Antworten.+?500@;# /.?/ is a soft hyphen
			}
			$_ = format_table $_ if %$_{tabular};
			print format_vt100 $_ ;
			push @nonempty, $pageno;
		}
	}
}

my @empty = sort grep{not $_ ~~ @nonempty} @all;
my ($N, $n) = ('n'x!!$#empty, 'n'x!!$#all);
print "${GREY}Tafel$N @{[join ', ', @empty]} wurde$N nicht gefunden. ${RESET}" if @empty;
