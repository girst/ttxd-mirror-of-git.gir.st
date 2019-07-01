#!/usr/bin/perl -X
# vim: foldmethod=marker

use strict;
use warnings;
use 5.010;
use utf8;use open qw/:std :utf8/;

use ORFText;

=pod
TODO: %headings won't register when topstory is missing (->sportarten)
this is version 2.0 of ttxd
values for query string/cookie:
 - special flags start with _
    - _noqna: hide "fragen/antworten" (set by default)
 - numeric: pagenumbers
=cut

my $pages = $ENV{HTTP_COOKIE} // join '&', (
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

my @pages = split /&/, ($ENV{QUERY_STRING} =~ s/(\d{3})-(\d{3})/${\join'&',$1..$2}/gr) // $pages;

# pages from query string won't affect cookie
#print "Set-Cookie: $pages; Max-Age=2147483647\r\n";
print "Content-type: text/html\r\n\r\n";

# html format {{{
$ORFText::REF_MARKUP = sub {
	return qq{<a href="?$_[1]" data-page="$_[1]" class="ttxref" target="_blank">$_[0]<b>$_[1]</b></a>}
};
sub format_table {
	my $text = join("\n",map{s/[\x00-\x20]/ /gr}@{%{$_[0]}{raw}})=~s/^ ,,+//msr=~s/\n+$//r;
	return {%$_, text=>"<pre>$text</pre>"};
}
sub format_html { my %page = %{$_[0] or return};
	no warnings 'numeric';
	use List::Util qw[max];
	sub ifdef { $_[1]? "$_[0]$_[1]":"" }
	my $pagespec = substr($page{page},0,1) ."00/$page{page}_000".max($page{subpage},1);

	return <<"HTML";
<section class=page>
  <h3 title='@{[join' - ', $page{ressort}||(), $page{subressort}||(), $page{topic}||()]}'>
    <a id="page-$page{page}">$page{page}${\ifdef('.',$page{subpage})}:</a>
    $page{title}
  </h3>
  <p>$page{text}
  <a title="Permanentlink zum Teilen erstellen" href="https://web.archive.org/save/http://text.orf.at/$pagespec.htm" class="archive" target="_blank">&#x27a4;</a>
  <p class=advert title="Werbung">${\($page{advert}=~s|\b(\d{3})\b|<a href="?$1" target="_blank">$1</a>|gr)}</p>
</section>
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
<!DOCTYPE html>
<html lang='de'>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1'>
<title>ORFText News</title>
<style>
  body {
    text-align:justify;
    hyphens:auto;
  
    color:#ddd;
    background:black;
    max-width:30em;
    margin:auto;
    padding:.5em;
  }
  h1{font-family: sans-serif}
  h1, b { color:white; }
  body h2 { font-size: larger; }
  a:link, a:visited { color: white; }
  a:hover, a:active { color: #eeeeee; }

  article {
    font:large serif;
    line-height:1.5;
  }

  section.page {
    margin-bottom: 2em;
  }
  section.page p {
    margin: 0;
  }
  section.page h3 {
    font-size: 1.1em;
    color: white;
    margin: 0;
  }
  section.page h3 a{
    font-weight: normal;
    color: #ddd;
  }
  section.page h4 {
    font-size: 1em;
    margin: 0;
  }
  a.archive {
    text-decoration:none;
    font-size:xx-small;
    vertical-align:middle;
  }
  a.config {
    float:right;
  }
  h1 a {
    text-decoration:none;
  }
  .page p.advert a {
    color: black;
  }
  .page p.advert {
    text-align: left;
    margin-top: .5em;
    color: #333;
    background: lightgrey;
  }
  p.errors {
    line-height: 1;
  }
  pre { /*sporttablellen*/
    margin: 0;
    max-width: 100%;
    overflow-x: auto;
    /*experimental:*/
    display: inline-block;
    vertical-align: text-bottom;
  }
</style>
<script>
document.addEventListener("DOMContentLoaded", function(event) {
    document.querySelectorAll("a.ttxref").forEach(e=>{
        var n = e.getAttribute("data-page");
        if(document.querySelector("#page-"+n) !== null) {
            e.href="#page-"+n;
            e.target="_self";
        }
    });
});
</script>

<article>
<h1><a href="?" title="zur Startseite">ORFText News</a></h1>
EOF
# }}}
my (@all, @nonempty);
page:foreach (grep/[0-9]/,@pages) {
	print "<h2>$headings{$_}</h2>\n" if $headings{$_};

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
			print format_html $_ ;
			push @nonempty, $pageno;
		}
	}
}

sub subtr { return grep{not%{{map{$_=>1}@{$_[1]}}}{$_}} @{$_[0]}; }
sub uniq  { return sort keys %{{@_}}; }
my @empty = uniq subtr [sort @all], [@nonempty];  # WARN: uniq breaks when sort is removed!
my ($N, $n) = ('n'x!!$#empty, 'n'x!!$#all);
print "<p class=errors>";
print "<small>Tafel$N @{[join ', ', @empty]} wurde$N nicht gefunden. </small>" if @empty;
print "</p>";

print "<section class=links>";
print "<hr><p>".join ' | ', (
	'<a href="?'.(join '&', 101, '113-125', '127-134').'">Politik</a>',
	'<a href="?'.(join '&', 102, '136-143'           ).'">Chronik</a>', 
	'<a href="?'.(join '&',      '701-709'           ).'">Bundesländer</a>', 
	'<a href="?'.(join '&',      '471-478', '481-488').'">einfache Sprache</a>',
	'<a href="?'.(join '&', 103, '146-149'           ).'">Leute</a>',
	'<a href="?'.(join '&', 108, '461-465'           ).'">Multimedia</a>',
	'<a href="?'.(join '&', 110, 107, '191-198'      ).'">Kultur &amp; Show</a>',
	'<a href="?'.(join '&', 104, '151-159'           ).'">Wirtschaft</a>',
	'<a href="?'.(join '&', 161, 167, 169,170,172,174).'">Börse</a>',
	'<a href="?'.(join '&', 105, '203-209'           ).'">Sport</a>',
	'<a href="?'.(join '&', '101-110'                ).'">Topstories</a>',
);
print "</section>";
print "</article>";
