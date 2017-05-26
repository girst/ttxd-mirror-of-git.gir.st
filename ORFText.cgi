#!/usr/bin/perl -X

use strict;
use warnings;
use 5.010;

my @pages = (101, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 127, 128, 129, 130, 131, 132, 133, 134, 102, 136, 137, 138, 139, 140, 141, 142, 143, 706, 108, 461, 462, 463, 464, 465);

print "Content-type: text/html\n\n";

print "<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>ORFText News</title><style>body{max-width:40em;text-align:justify;margin:auto;padding:.5em;font-family:serif;}a:link,a:visited{color:grey}</style></head><body bgcolor=black style='color:#ffffff'>";
print "<h1>ORFText News</h1>";
print '<a href="#pol">pol</a> | <a href="#loc">loc</a> [<a href="#tir">T</a>] | <a href="#web">web</a>';

foreach (@pages) {
	if ($_ == 101) {
		print "<a name=pol></a><h2>Politik</h2>";
	} elsif ($_ == 102) {
		print "<a name=loc></a><h2>Chronik</h2>";
	} elsif ($_ == 706) {
		print "<a name=tir></a><h3>Tirol</h3>";
	} elsif ($_ == 108) {
		print "<a name=web></a><h2>Web/Media</h2>";
	}
	my @subpages = glob "/run/ttxd/spool/2/${_}_*.vtx";
	foreach (@subpages) {
		my $file_age = time() - (stat ($_))[9];
		print `./html.pl $_` if $file_age < 1000;
		#print "<li>$_ : $file_age</li>" if $file_age > 1000;
	}
	#print `./html.pl /run/ttxd/spool/2/${_}_00.vtx` if -e "/run/ttxd/spool/2/${_}_00.vtx";
}
print "</body></html>";
