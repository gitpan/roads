#!/usr/bin/perl
use lib "/home/roads2/lib";

# lookupcluster.pl - search WHOIS++ servers for template clusters
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#         Martin Hamilton <martinh@gnu.org>
# $Id: lookupcluster.pl,v 3.14 1998/08/18 19:24:45 martin Exp $

# Fix for stupid Netscape server bug/misfeature
close(STDERR) if $ENV{"SERVER_NAME"} =~ /netscape/i;

use Getopt::Std;

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::DatabaseNames;
use ROADS::ErrorLogging;
use ROADS::HTMLOut;
use ROADS::LookupRender;
use ROADS::Override;
use ROADS::Rank;
use ROADS::WPPC;

# Handle command line parameters
getopts('C:L:cl:o:p:u:v:w:');

#
# Globals
#

# What character set to use.
$CharSet = $opt_C || "ISO-8859-1";

# What language to return
$Language = $opt_L || "en-uk";

# Caseless matching is default
$opt_c=0 unless $opt_c;

# Logfile to record hits from queries in.
$hitlog = $opt_l || "$ROADS::Logs/lookupcluster-hits";

# Protocol schemes to override
$protocols = $opt_p || "$ROADS::Config/protocols";

# Where the template outlines live
$OutlineDir = $opt_o || "$ROADS::Config/outlines/";

# The URL of this program
$myurl = $opt_u || "/$ROADS::WWWAdminCgi/lookupcluster.pl";

# The URL of the template editor program.
$editorurl = "/$ROADS::WWWAdminCgi/mktemp.pl";

# Result view
$view = $opt_v || "$ROADS::Config/lookupcluster-views";

# The URL of the "waylay" program (sits between result listing and object)
$waylay = $opt_w || "/$ROADS::WWWCgiBin/waylay.pl";

# Set up a signal handler for SIGALRM
$SIG{'ALRM'} = 'signalhandler';

#
# Main code
#

# Set up an alarm call for 1 hours time (in case something goes wrong and we
# end up hanging about far longer than we should).  Not that there are any
# HTTP daemons which have this problem, oh no... ;-)
alarm(3600);

# The CGI arguments.
&cleaveargs;
&CheckUserAuth("lookupcluster_users");
$opt_c = 1 if $CGIvar{caseful} eq "on";
$debug = 1 if $CGIvar{debug} eq "on";

print "Content-type: text/html\n\n";

#### Temporary permanent debugging.
#$debug = 1;

&ReadDBNames;
&Override;

$CGIvar{stemming} = "off" unless $CGIvar{stemming} eq "on";
$CGIvar{highlight} = "off" unless $CGIvar{highlight} eq "on";

# Change the output language if specified in either the HTTP headers or the 
# CGI variables passed from the browser.
if($ENV{"HTTP_ACCEPT_LANGUAGE"} ne "") {
    $Language = $ENV{"HTTP_ACCEPT_LANGUAGE"};
}
if($CGIvar{language} ne "") {
    $Language = $CGIvar{language};
}

# Change the character set if specified in either the HTTP headers of the
# CGI variables passed from the browser.
if($ENV{"HTTP_ACCEPT_CHARSET"} ne "") {
    $CharSet = $ENV{"HTTP_ACCEPT_CHARSET"};
}
if($CGIvar{charset} ne "") {
    $CharSet = $CGIvar{charset};
}

if($CGIvar{query} eq "") {
   &OutputHTML("lookupcluster", "search.html", $Language, $CharSet);
   exit;
}

if ($CGIvar{query} eq "") {
    &OutputHTML("lookupcluster", "nosearchterm.html", $Language, $CharSet);
    exit;
}

# Get a version of the query string that we can display to the user.
$displayquery = $CGIvar{query};
$displayquery =~ s/\&/ AND /g;
$displayquery =~ s/\|/ OR /g;
$displayquery =~ s/!/ NOT /g;

undef (@results);

# Grab the cluster name and the cluster variant number that we were passed.
$CGIvar{type} =~ /([A-Za-z\-]+)([0-9]+)/;
$ClusterName = $1;
$ClusterNumber = $2;

# Open the appropriate template outline
$tt=$CGIvar{templatetype};
$tt=~tr/A-Z/a-z/;
if (!open(OUTLINE,"$OutlineDir/$tt")) {
    &OutputHTML("mktemp","notemplateoutline.html",$Language,$CharSet);
    &WriteToErrorLogAndDie("$0", 
      "Can't open template outline $OutlineDir/$tt");
}
<OUTLINE>;
while(/Template-type:/i) {
    <OUTLINE>;
}

while(!eof(OUTLINE)) {
    $line = <OUTLINE>;
    chomp $line;
    ($fieldname,$xsize,$ysize,$defaultvalue,$optional) = split(/:/,$line);
    if ($xsize eq "") {
        $xsize = 25;
    }
    if ($ysize eq "") {
        $ysize = 1;
    }
    if($fieldname =~ /$ClusterName/i) {
        $fieldname =~ /\(([a-zA-Z]+)\*\)/;
        $ClusterType = $1;
        last;
    }
}
close(OUTLINE);

print STDOUT "ClusterName = '$ClusterName'<BR>\n" if($debug);
print STDOUT "ClusterNumber = '$ClusterNumber'<BR>\n" if($debug);
print STDOUT "ClusterType = '$ClusterType'<BR>\n" if($debug);

# Do the searches over the selected databases, returning the hits in the
# configured log file.
foreach $dbname (keys %database) {
    $query = $database{"$dbname"} ? 
      "destination=$database{\"$dbname\"} and $displayquery" :
        $displayquery;
    $query = $query.":authenticate=yes;name=admin;password=roads";
    print STDOUT "[<EM>Searching host '$host{\"$dbname\"}', port " .
      "'$port{\"$dbname\"}' with query '$displayquery'</EM>]<BR>\n" if $debug;
    push (@results, &wppc($host{"$dbname"}, $port{"$dbname"}, $query));
}

@ranked_results = &rank($displayquery,@results);

if ($debug) { foreach (@results) { print "hit... $_<P>\n"; } }

if (open(HITLOG,">>$hitlog")) {
    flock(HITLOG,2);

    # write hit search stats in common log format
    @MON = ('Dummy', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
	    'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    ($gsec,$gmin,$ghour,$gmday,$gmon,$gyear,$gwday,$gyday,$gisdst)
	= gmtime;
    $offset = $hour - $ghour;
    
    $datestr = sprintf("%02d/%s/%4d:%02d:%02d:%02d %s%02d00", $mday, 
		       $MON[$mon + 1], $year + 1900, $hour, $min, $sec, 
		       $offset >= 0 ? '+' : '-', $offset);

    printf HITLOG "%s %s %s [%s] \"%s\" %d 0\n",
      $ENV{REMOTE_HOST} ? $ENV{REMOTE_HOST} : $ENV{REMOTE_ADDR},
      $ENV{REMOTE_IDENT} ? $ENV{REMOTE_IDENT} : "-",
      $ENV{REMOTE_USER} ? $ENV{REMOTE_USER} : "-",
      $datestr,
      $displayquery,
      $#ranked_results;
    flock(HITLOG,8);
    close(HITLOG);
} else {
    &WriteToErrorLog("lookupcluster", "Can't open hit log $hitlog: $!");
}

&lookuprender($displayquery, $view, @ranked_results);

exit 0;


#
# Signal handler subroutine - mainly to handle SIGALRM in order to commit
# suicide when crappy CERN httpd's leave us lying around for hours.  We don't
# write anything anywhere as we don't know what state we're in at the moment.
#
sub signalhandler {
    exit(0);
}

exit;
__END__


=head1 NAME

B<admin-cgi/lookupcluster.pl> - search WHOIS++ servers for template clusters

=head1 SYNOPSIS

  admin-cgi/lookupcluster.pl [-c] [-C charset] [-L language]
    [-l logfile] [-o outlines] [-p protocols]
    [-u myurl] [-v view] [-w waylay_url]
 
=head1 DESCRIPTION

This Perl program is run behind the scenes by the ROADS template
editor, when performing searches for cluster information to embed in
templates which are being created or edited.

=head1 OPTIONS

These options are intended for debugging use only.

=over 4

=item B<-C> I<charset>

The character set to use.

=item B<-L> I<language>

The language to return.

=item B<-c>

Whether to consider case, off by default.

=item B<-l> I<logfile>

Logfile to record hits from queries in, default is
I<lookupcluster-hits> in the ROADS logs directory.

=item B<-o> I<outlines>

Where the template outlines live.

=item B<-p> I<protocols>

Protocol schemes to override using the B<waylay> program.

=item B<-u> I<myurl>

URL of this program, default is I<lookupcluster.pl> in the
nominated CGI executables directory.

=item B<-v> I<viewdir>

Result views directory - specifications for how templates should be
rendered.

=item B<-w> I<waylay_url>

The URL of the B<waylay.pl> program, which sits between result listing
and object rendering into HTML.

=back

=head1 CGI VARIABLES

=over 4

=item B<caseful>

Boolean variable which indicates whether searches should consider case
or not.

=item B<charset>

The character set to use.

=item B<debug>

Boolean variable which controls whether debugging output is returned
in the HTML which is rendered to the end user.

=item B<highlight>

Boolean variable which controls whether occurences of the search terms
in the search results should be highlighted.

=item B<language>

The language to use.

=item B<query>

The query itself.

=item B<stemming>

Boolean variable which controls whether stemming is performed on the
query.  See the documentation for B<search.pl> for more information
about this.

=item B<type>

The cluster name and variant number which is being searched for.

=item B<templatetype>

Template type to search for.

=back

=head1 SEE ALSO

L<cgi-bin/search.pl>, L<admin-cgi/admin.pl>, L<admin-cgi/mktemp.pl>

=head1 COPYRIGHT

Copyright (c) 1988, Martin Hamilton E<lt>martinh@gnu.orgE<gt> and Jon
Knight E<lt>jon@net.lut.ac.ukE<gt>.  All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

It was developed by the Department of Computer Studies at Loughborough
University of Technology, as part of the ROADS project.  ROADS is funded
under the UK Electronic Libraries Programme (eLib), the European
Commission Telematics for Research Programme, and the TERENA
development programme.

=head1 AUTHORS

Jon Knight E<lt>jon@net.lut.ac.ukE<gt>,
Martin Hamilton E<lt>martinh@gnu.orgE<gt>

