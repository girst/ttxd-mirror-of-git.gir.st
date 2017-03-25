#!/usr/bin/perl -X

use strict;
use warnings;
use 5.010;

my @pages = (101, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 127, 128, 129, 130, 131, 132, 133, 134, 102, 136, 137, 138, 139, 140, 141, 142, 143, 108, 461, 462, 463, 464, 465);

print "Content-type: text/html\n\n";

print "<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>ORFText News</title><style>body{max-width:40em;text-align:justify;margin:auto;padding:.5em;font-family:serif;}</style></head><body bgcolor=black style='color:#ffffff'>";
print "<h1>ORFText News</h1>";

foreach (@pages) {
	print `./html.pl /run/ttxd/spool/2/${_}_00.vtx` if -e "/run/ttxd/spool/2/${_}_00.vtx";
}
print "</body></html>";
