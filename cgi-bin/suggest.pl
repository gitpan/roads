#!/usr/bin/perl
use lib "/home/roads2/lib";

# suggest.pl - cut down template creation for end users, derived from
#              the main mktemp.pl ROADS template editor code
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#         Martin Hamilton <martinh@gnu.org>
#
# $Id: suggest.pl,v 3.4 1998/08/18 19:23:35 martin Exp $

use Getopt::Std;

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;
use ROADS::HTMLOut;
use ROADS::ReadTemplate;

# Handle command line parameters.  These aren't used normally - consider them
# to be undocumented debugging aids for the developers.
getopts('L:C:f:u:');

# File to return to end user
$htmlform = $opt_f || "suggest.html";

# The URL of this script
$myurl = $opt_u || "/$ROADS::WWWCgiBin/suggest.pl";

# What language to return
$Language = $opt_L || "en-uk";

# What character set to use.
$CharSet = $opt_C || "ISO-8859-1";

# Print out the HTTP Content-type header and then cleave the CGI URL into
# an associative array ready for use.
&cleaveargs;

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

print STDOUT "Content-type: text/html\n\n";

# If the URL being suggested for inclusion isn't present we must squirt out
# the introductory FORM for the user and then exit.
if ($CGIvar{SUGGESTurl} eq "") {
    &OutputHTML("suggest", "$htmlform");
    exit;
}

# If we get this far they must have supplied us with a URL
&OutputHTML("suggest", "done.html");

$cmd = "$ROADS::MailerPath -s '[Proposed] $CGIvar{SUGGESTurl}'";
unless (open (MAIL, "|$cmd $ROADS::DBAdminEmail")) {
    &WriteToErrorLog("mktemp", "Can't open a pipe to $MailerPath: $!");
    &OutputHTML("suggest", "mailererror.html");
    exit 1;
}

foreach $attrib (keys %CGIvar) {
    next unless $attrib =~ /^SUGGEST/;
    $print_attrib = $attrib;
    $print_attrib =~ s/^SUGGEST//;
    $print_attrib =~ tr [a-z] [A-Z];
    $print_value = $CGIvar{"$attrib"};
    $print_value =~ s/\n/\n                     /g;
    printf MAIL "%-20.20s $print_value\n", "$print_attrib:";
}

$time = gmtime();
print MAIL <<EOF

Submitted at:       $time (UTC)
=============================================================
REMOTE HOST:        $ENV{REMOTE_HOST}
REMOTE ADDRESS:     $ENV{REMOTE_ADDR}
REMOTE IDENT:       $ENV{REMOTE_IDENT}
REMOTE USER:        $ENV{REMOTE_USER}
HTTP_USER_AGENT:    $ENV{HTTP_USER_AGENT}
=============================================================
EOF
;

close(MAIL);

exit;
__END__


=head1 NAME

B<cgi-bin/suggest.pl> - suggest a resource for inclusion in the database

=head1 SYNOPSIS

  cgi-bin/suggest.pl [-C charset] [-f form] [-L language]
    [-u myurl]

=head1 DESCRIPTION

B<suggest.pl> program is a Common Gateway Interface (CGI) program run
from an HTTP daemon.  This is a cut down equivalent of the regular
ROADS template editor intended for use by end users.  It simply
renders the HTML form I<suggest.html> (by default) to the end user and
returns any fields on the form whose names are prefixed by B<SUGGEST>
in an email message to the ROADS database administrator once the form
is submitted.

=head1 HTML FORM ELEMENTS

It is necessary to include a field called I<SUGGESTurl> on the form,
since use of this is hard coded into the program.

=head1 OPTIONS

These options are only practically useful for debugging.

=over 4

=item B<-C> I<charset>

Character set to use.

=item B<-f> I<form>

HTML form to return to end user.

=item B<-L> I<language>

Language to use.

=item B<-u> I<url>

URL of the B<suggest.pl> program.

=back

=head1 CGI VARIABLES

=over 4

=item B<charset>

Character set to use.

=item B<form>

HTML form to return to end user.  Note that only alphanumeric characters
will be used.

=item B<language>

Language to use.

=back

=head1 FILES

I<config/multilingual/*/suggest/done.html> - message returned
to end user when template submitted.

I<config/multilingual/*/suggest/mailerror.html> - message
returned to end user if mail message couldn't be sent.

I<config/multilingual/*/suggest/suggest.html> - default HTML
form returned to end user.

=head1 SEE ALSO

L<admin-cgi/mktemp.pl>

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

