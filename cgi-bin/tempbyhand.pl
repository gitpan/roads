#!/usr/bin/perl
use lib "/home/roads2/lib";

# tempbyhand.pl
#
# Authors: Jon Knight <jon@net.lut.ac.uk>
#          Martin Hamilton <martinh@gnu.org>
# $Id: tempbyhand.pl,v 3.13 1998/08/18 19:23:35 martin Exp $

# Fix for stupid Netscape server bug/misfeature
close(STDERR) if $ENV{"SERVER_NAME"} =~ /netscape/i;

use File::Basename;
use Getopt::Std;
getopts('L:C:d:f:o:u:w:v:');

require ROADS;
use ROADS::CGIvars;
use ROADS::DatabaseNames;
use ROADS::ErrorLogging;
use ROADS::HTMLOut;
use ROADS::Override;
use ROADS::Render;
use ROADS::WPPC;

#
# Globals
#

# Get the name that this program was called under.
$scriptname = basename($0,".pl");
# The location of the list of active database names and directories
$dbnames = $opt_d || "$ROADS::Config/databases";
# Source for the HTML FORM
$htmlform = $opt_f || "tempbyhand.html";
# Protocol schemes to override
$protocols = $opt_o || "$ROADS::Config/protocols";
# The URL of this program
$myurl = $opt_u || "/$ROADS::WWWCgiBin/tempbyhand.pl";
# The URL of the "waylay" program (sits between result listing and object)
$waylay = $opt_w || "/$ROADS::WWWCgiBin/waylay.pl";
# Result view
$view = $opt_v || "default";
# What language to return
$Language = $opt_L || "en-uk";
# What character set to use.
$CharSet = $opt_C || "ISO-8859-1";

&Override;
&ReadDBNames;
&cleaveargs;

print "Content-type: text/html\n\n";

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

if ($CGIvar{form} ne "") {
    $htmlform = "$CGIvar{form}";
    $htmlform =~ tr/[A-Za-z0-9]//c;
    $htmlform .= ".html";
}

if($ENV{QUERY_STRING} eq "") {
    &OutputHTML("tempbyhand", $htmlform,$Language,$CharSet);
    exit;
}

$handle = $CGIvar{query};

if ($CGIvar{query} eq "") {
    &OutputHTML("tempbyhand", "nohandle.html",$Language,$CharSet);
    exit;
}

$dbase = $CGIvar{database} || $ROADS::ServiceName;

undef (@results);
$query = "handle=$handle";

unless ($host{"$dbase"} && $port{"$dbase"}) {
    &OutputHTML("tempbyhand", "baddbase.html",$Language,$CharSet);
    exit;
}

push (@results, &wppc($host{"$dbase"}, $port{"$dbase"}, $query));
&render($query, $view, @results);

exit 0;
__END__


=head1 NAME

B<cgi-bin/tempbyhand.pl> - given a template handle, render it as HTML

=head1 SYNOPSIS

  cgi-bin/tempbyhand.pl [-d databases] [-C charset]
    [-f form] [-L language] [-o protocols] [-u url] 
    [-w waylay_url] [-v view]

=head1 DESCRIPTION

The B<tempbyhand.pl> program is a Common Gateway Interface (CGI)
program used to return a template to an end user given the handle of the
template.  It is called from the B<search.pl> and B<admin.pl> to display
the full details from a template when the user has selected the titles
only option.

B<tempbyhand.pl> actually carries out a WHOIS++ search behind the
scenes.

=head1 OPTIONS

These options are intended for debugging use only.

=over 4

=item B<-d> I<databases>

File containing list of databases to use.

=item B<-C> I<charset>

The character set to use.

=item B<-f> I<form>

HTML form to return to the end user if no handle to lookup is
supplied.

=item B<-L> I<language>

The language to use.

=item B<-o> I<protocols>

URL protocol schemes to override, e.g. I<wais>.  See
L<cgi-bin/waylay.pl> for more information.

=item B<-u> I<myurl>

The URL of this program, if not passed as CGI variable - default
is I<tempbyhand.pl> in the nominated CGI executables directory.

=item B<-w> I<waylay_url>

The URL of the program to use when "waylaying" URLs which are odd or
unusual.  See L<cgi-bin/waylay.pl> for more information.

=back

=head1 CGI VARIABLES

The B<tempbyhand.pl> program uses two CGI parameters to determine
which template to display:

=over 4

=item B<charset>

Character set to use.

=item B<database>

This is the name of the database from which the template is to be
retieved.  This may be a local or remote WHOIS++ database - but it
must be listed by name in the file I<config/databases>.

=item B<form>

HTML form to return to the end user.

=item B<language>

Language to use.

=item B<query>

This is a WHOIS++ query to send, usually simply "handle=", followed by
the handle of the template to display.

=back

=head1 FILES

I<config/databases> - list of servers and databases.

I<config/multilingual/*/tempbyhand/baddbase.html>
- the database requested couldn't be found.

I<config/multilingual/*/tempbyhand/nohandle.html>
- the handle requested couldn't be found.

I<config/multilingual/*/tempbyhand/noconnect.html>
- the WHOIS++ server couldn't be contacted.

I<config/multilingual/*/tempbyhand/nohits.html>
- there were no hits in the WHOIS++ server.

I<config/multilingual/*/tempbyhand/tempbyhand.html>
- the HTML form returned by default to the end user
when no handle is supplied.

I<config/multilingual/*/tempbyhand-views/*>
- HTML rendering rules for lookup results.

=head1 SEE ALSO

L<admin-cgi/admin.pl>, L<cgi-bin/search.pl>

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

=head1 AUTHOR

Jon Knight E<lt>jon@net.lut.ac.ukE<gt>,
Martin Hamilton E<lt>martinh@gnu.orgE<gt>

