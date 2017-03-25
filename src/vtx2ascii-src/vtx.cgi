#!/usr/bin/perl
use CGI;

# config
$SPOOL="/home/kraxel/vtx";
$VTX2ASCII="/home/kraxel/bin/vtx2ascii";

#######################################################################
# create time string

@WEEK = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
@MON  = ('Jan','Feb','Mar','Apr','May','Jun',
         'Jul','Aug','Sep','Oct','Nov','Dec');

sub time2str {
    @tm    = gmtime($_[0]);
    sprintf ("%s, %02d %s %04d %02d:%02d:%02d GMT",
             $WEEK[$tm[6]],$tm[3],$MON[$tm[4]],$tm[5]+1900,$tm[2],$tm[1],$tm[0]);
}

#######################################################################
# helper functions

sub start_page {
    local($title,$file) = @_;

    if ($file ne "") {
        @inode = stat $file;
        printf("Last-modified: %s\n",time2str(@inode[9]));
    }
    print <<EOF;
Content-Type: text/html

<html>
<head>
<title>videotext: $title</title>
</html>
<body bgcolor=white color=black link=royalblue vlink=darkblue>
EOF
}

sub finish_page {
    print "</body></html>\n";
}

sub panic {
    local($text) = @_;

    start_page("PANIC");
    print "<h2>PANIC</h2>$text";
    &finish_page;
    exit;
}

sub addlink() {
    local($nr) = @_;

    $links{$nr} = 1;
    return $nr;
}

#######################################################################
# main

$cgi = new CGI;

if ($cgi->path_info eq "" || $cgi->path_info =~ /^\/[^\/]+$/) {
    print $cgi->redirect($cgi->url . $cgi->path_info . "/");
    exit;
}
($dummy,$station,$page) = split(/\//,$cgi->path_info);

# entry page - station list
if ($station !~ /\S/) {
    opendir DIR, $SPOOL || panic("can't open dir $SPOOL: $@");
    &start_page("station list",$SPOOL);
    print "<h2>station list</h2>\n<ul>\n";
    while ($file = readdir(DIR)) {
        next if ($file =~ /^\./);
	next unless -d "$SPOOL/$file";
	print "<li><a href=\"$file/\">$file</a>\n";
    }
    print "</ul>\n";
    &finish_page;
    exit;
}

# station dir - spage list
if ($page !~ /\S/) {
    opendir DIR, "$SPOOL/$station" ||
	panic("can't open dir $SPOOL/$station: $@");
    &start_page("$station - page list","$SPOOL/$station");
    print "<h2>$station - page list</h2>\n\n";
    print "<a href=\"../\">[station list]</a><hr noshade><ul>\n";
    while ($file = readdir(DIR)) {
        next unless ($file =~ /\.vtx/);
	print "<li><a href=\"$file\">$file</a>\n";
    }
    print "</ul>\n";
    &finish_page;
    exit;
}

# print page
unless (-f "$SPOOL/$station/$page") {
    # sub-page check
    if ($page =~ s/_00.vtx/_01.vtx/ && -f "$SPOOL/$station/$page") {
	print $cgi->redirect($cgi->url . "/$station/$page");
	exit;
    }
    panic("$SPOOL/$station/$page: not found");
}

# read
undef $/;
open VTX,"$VTX2ASCII -h $SPOOL/$station/$page |" || 
    panic("can't run $VTX2ASCII: $@");
$data = <VTX>;
close VTX;

# look for links
$data =~ s/(\d\d\d)/&addlink($1)/eg;

# print
start_page("$station - $page","$SPOOL/$station/$page");
print "<h2>$station - $page</h2>\n";
print "<a href=\"../\">[station list]</a> &nbsp; ";
print "<a href=\"./\">[page list]</a> &nbsp; ";
if ($page =~ /(\d\d\d)_(\d\d).vtx/ && $2 > 0) {
    printf "<a href=\"%03d_%02d.vtx\">[prev subpage]</a> &nbsp; ",$1,$2-1;
    printf "<a href=\"%03d_%02d.vtx\">[next subpage]</a> &nbsp; ",$1,$2+1;
}
print "<br>\n";
foreach $item (sort keys %links) {
    print "<a href=\"${item}_00.vtx\">$item</a>\n";
}
print "<hr noshade>\n";
print "$data";
&finish_page;
exit;
