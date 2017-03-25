#!/usr/bin/perl -X

# (C) 2016-2017 Tobias Girstmair
# Extracts plain text news from ORF Teletext
# uses a modified version of vtx2ascii to decode pages
# from dvbtext's spool directory. 

# Usage: ./plain.pl <VTX-file>
# Output: Line 1: Heading (pageNo); following lines are news body

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
# TODO: run tzap/dvbtext in background if not already running
my $page = shift;
my $subp = 0; #shift; #TODO: could be undefined
# run through vtx2ascii (has been modified to output correct ISO 8859-1 without national replacements)
open (VTX, "./vtx2ascii -a $page |") || die ("Can'r run vtx2ascii");
my $last = "";
my $is_10x = 0;
do {
	# transliterate from ETSI EN 300 706 G0 German to UTF-8:
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
		default { $text .= $last ."|EOL|". ($last eq ""?"":($line eq ""?"\n":" ")) }
	}
	$last = $line unless $. == (5+(2*$is_10x));
} while (<VTX>);
$text .= $last;

$text =~ s/([[:lower:]])-\|EOL\| ([[:lower:]])/\1\2/g; #remove hyphenation only when in between lowercase letters
$text =~ s/\|EOL\|//g; #remove hyphenation only when in between lowercase letters

#ADBlocker
$text =~ s/ORF TELETEXT jetzt auch als App gratis im App-Store für iOS . Android//g;
$text =~ s/Weidenrinde bei R.ckenschmerzen >652 Onlineshop: www\.hafesan\.at//g;

#DEBUG:
print STDERR "Page: $meta{'page'}\tChannel: $meta{'channel'}\tDate: $meta{'date'}\n";
print STDERR "Ressort: $meta{'res'}\tSubressort: $meta{'subres'}\n";
print STDERR "is_10x: ", $is_10x?"yes":"no", "\n";

print $title, " ($meta{'page'})\n", $text;

close (VTX);

sub parse_metadata {
	my @elems = split ' ', @_[0];

	my %retval = (
		'page' => shift @elems,
		'channel' => shift @elems,
		'date' => join (' ', @elems) ##date doesnt work TODO
	);

	return %retval;
}
