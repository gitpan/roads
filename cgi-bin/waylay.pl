#!/usr/bin/perl
use lib "/home/roads2/lib";

# waylay.pl - generate a page of HTML for a given URL protocol scheme
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: waylay.pl,v 3.14 1998/11/05 18:39:00 jon Exp $

# Fix for stupid Netscape server bug/misfeature
close(STDERR) if $ENV{"SERVER_NAME"} =~ /netscape/i;

use Getopt::Std;
getopts('C:L:u:');

require ROADS;
use ROADS::CGIvars;
use ROADS::ErrorLogging;
use ROADS::HTMLOut;
use ROADS::Override

&cleaveargs;

#
# Main code
#

# What character set to use.
$CharSet = $opt_C || "ISO-8859-1";

# What language to return
$Language = $opt_L || "en-gb";

# URL to use if not passed as CGI variable
$myurl = $opt_u || $CGIvar{url};

# Protocol schemes to override
&Override;

print "Content-type: text/html\n\n";

unless ($myurl) {
    print <<EndOfHTML;
<HTML>
<HEAD>
<TITLE>Internal Error</TITLE>
</HEAD>
<BODY>
<H1>Internal Error</H1>

An internal error has occurred in the ROADS software.  Contact
technical support!<P>
</BODY>
</HTML>
EndOfHTML

    &WriteToErrorLog($0, "No URL specified!");
    exit;
} 

$scheme = $myurl;
$scheme =~ s/:.*//;
$scheme =~ tr/[\/\.]//;
if ($override{"$scheme"}) {
    $file = $override{"$scheme"};
} else {
    $file = "other.html";
}

# should have a way of testing for "other" ?
&OutputHTML("waylay", "$file", $Language, $CharSet);

exit;
__END__


=head1 NAME

B<cgi-bin/waylay.pl> - generate a page of HTML for a given URL protocol
  scheme

=head1 SYNOPSIS

  cgi-bin/waylay.pl [-C charset] [-L language] [-u myurl]

=head1 DESCRIPTION

This Perl program is intended for use when rendering ROADS database
records which make use of unusual or bizarre protocol schemes.  For
example, the I<wais> protocol scheme is not widely supported, and
the I<mailto> protocol scheme has no attached semantics to tell the
user whether they are going to be dealing with a human being or a
software agent.

It is assumed that the software which generates URLs referencing
this program knows whether or not there is a page of HTML which may
be used to describe the protocol scheme in question.

=head1 OPTIONS

These options are intended for debugging use only.

=over 4

=item B<-C> I<charset>

The character set to use.

=item B<-L> I<language>

The language to return.

=item B<-u> I<myurl>

The URL of this program, if not passed as CGI variable - default
is I<waylay.pl> in the nominated CGI executables directory.

=back

=head1 CGI VARIABLES

=over 4

=item B<charset>

The character set to use.

=item B<language>

The language to return.

=item B<myurl>

The URL of this program - default is I<waylay.pl> in the nominated CGI
executables directory.

=back

=head1 FILES

I<config/protocols> - list of protocol schemes to waylay
and message files to return

I<config/multilingual/*/waylay/*.html> - per-protocol
explanations

=head1 FILE FORMAT

The file I<config/protocols> is line oriented, with two fields on each
line, colon delimited:

=over 1

=item Protocol name, e.g. I<wais>

=item Message filename, e.g. I<wais.html>

=back

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

Martin Hamilton E<lt>martinh@gnu.orgE<gt>

