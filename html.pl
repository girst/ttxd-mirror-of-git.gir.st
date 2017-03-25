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
binmode STDOUT, ":encoding(utf8)";

# Seitenformat: 
#  100-109:
#   Metadaten:      1
#   Subressort:     2
#   Ressort/Sparte: 3
#   Leer            4
#   Related:        5
#   Leer            6
#   Titel:          7
#   Text:           8-24
#
#  112-899:
#   Metadaten:      1
#   Subressort:     2
#   Ressort/Sparte: 3
#   Leer            4
#   Titel:          5
#   Text:           6-24
#   

my %meta;
my $title;
my $text = "";
my $page = shift;
my $subp = 0; #TODO: allow subpages
# run through vtx2ascii (has been modified to output correct ISO 8859-1 without national replacements)
open (VTX, "./vtx2ascii -a $page |") || die ("Can'r run vtx2ascii");
my $last = "";
my $is_10x = 0;
do {
	# transliterate from ETSI EN 300 706 G0 German to Latin-1 (will be converted to UTF-8 by perl):
	tr/[\\]{|}~/\N{U+C4}\N{U+D6}\N{U+DC}\N{U+E4}\N{U+F6}\N{U+FC}\N{U+DF}/;
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
		when (4 + (3*$is_10x)) { $title .=$line }
		default { $text .= $last . "_EOL_" . ($last eq ""?"":($line eq ""?"<br>":" ")) }
	}
	$last = $line unless $. == (5+(2*$is_10x));
} while (<VTX>);
$text .= $last;

#remove hyphenation at original line ending only when in between lowercase letters, replace with soft hyphen to still allow hyphenation when needed. ad _EOL_: linebreaks already stripped in loop above; wouldn't work either way due to single line regex.
$text =~ s/([[:lower:]])-_EOL_ ([[:lower:]])/\1&shy;\2/g;
$text =~ s/_EOL_//g;

# adblocker: just add more regexes
$text =~ s/Kalendarium - t.glich neu \. 734//g;

print "<p>$meta{'page'}: <b>$title</b><br>$text</p>";

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
