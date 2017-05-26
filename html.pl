#!/usr/bin/perl -X

# (C) 2016-2017 Tobias Girstmair
# Extracts hypertext formatted news from ORF Teletext
# uses a modified version of vtx2ascii to decode pages
# from dvbtext's spool directory. 

# Usage: ./plain.pl <VTX-file>
# Output: HTML

use strict;
use warnings;
use 5.010;
# convert to utf-8 before outputting; WARN: still processes latin-1 (regexes too)!
binmode STDOUT, ":encoding(utf8)";

my %meta;
my $title;
my $text = "";
# TODO: run tzap/dvbtext in background if not already running
my $page = shift;
my ($subpage) = $page=~m/\d{3}_(\d{2})/; #requires ppp_ss file name scheme! @parens: https://stackoverflow.com/a/10034105
$subpage += 0; # convert to number to remove leading zero
# run through vtx2ascii (has been modified to output correct ISO 8859-1 without national replacements)
open (VTX, "./vtx2ascii -a $page |") || die ("Can'r run vtx2ascii");
my $last = "";
my $is_10x = 0;
do {
	# transliterate from ETSI EN 300 706 G0 German to latin-1 (ÄÖÜäöüß°§):
	tr/[\\]{|}~`@/\N{U+C4}\N{U+D6}\N{U+DC}\N{U+E4}\N{U+F6}\N{U+FC}\N{U+DF}\N{U+B0}\N{U+A7}/;
	my $line = $_;
	$line =~ s/^\s+|\s+$//g;
	chomp ($line);

	given ($.) {
		when (1) { %meta = parse_metadata ($line) ; $is_10x = ($meta{'page'}<110) }
		when (2) { $meta{'subres'} = $line }
		when (3) { $meta{'res'} = $line }
		when (4) {}
		when (5 + (1*$is_10x)) { $title = $line }
		when (4 + (1*$is_10x)) {}
		when (4 + (3*$is_10x)) { $title .=$line if ($title eq "")}
		default { $text .= $last . "_EOL_" . ($last eq ""?"":($line eq ""?"<br>":" ")) }
	}
	$last = $line unless $. == (5+(2*$is_10x));
} while (<VTX>);
$text .= $last;

# substitute hyphenation:
#  * replace with soft hyphen when it splits a word (between lowercase letters;
#    still allows line break when necessary. 
#  * keep, when followed by uppercase letter (e.g. "03-Jährige", "PIN-Nummer")
#  * remove in any other case (was: forced hyphenation due to space constraints)
# ad _EOL_: linebreaks already stripped in loop above; wouldn't work either way
# due to single line regex. INFO: Underscore is in DE-localized teletext charset. 
$text =~ s/([[:lower:]])-_EOL_ ([[:lower:]])/\1&shy;\2/g;
$text =~ s/([[:alnum:]])-_EOL_ ([[:upper:]])/\1-\2/g;
$text =~ s/_EOL_//g;

# remove ORFText idiosyncrasies
$text =~ s/([[:alnum:]]),([[:alnum:]])/\1, \2/g; # no space after comma to save space
$text =~ s/([[:alnum:]])\.([[:upper:][:digit:]])/\1. \2/g; # no space after period to save space (WARN: breaks URLS like tirol.ORF.at)

# adblocker: (keep it 7bit-ASCII; perl processes latin1, but output will be utf8)
$text =~ s/Kalendarium - t.glich neu \. 734//g;
$text =~ s/>>tirol\. ?ORF\.at//g;

my @tmp = split(' ',$meta{'date'});
my $shortdate = substr $tmp[1], 0, 6;
my $pagesubpage = $meta{'page'} . ($subpage > 0?".$subpage":"");
my $moreinfo = "$meta{'res'} - $meta{'subres'}; $meta{'date'}";
print "<p>$pagesubpage:</span> <b title='$moreinfo' onclick='javascript:alert(\"$moreinfo\")'>$title</b><br>$text</p>";

close (VTX);

sub parse_metadata {
	my @elems = split ' ', @_[0];

	my %retval = (
		'page' => shift @elems,
		'channel' => shift @elems,
		'date' => join (' ', @elems)
	);

	return %retval;
}
