#!/usr/bin/perl
use lib "/home/roads2/lib";

# dumpdbm.pl: Dump the contents of an arbitrary DBM file (handy for debugging)
#
# Authors: Jon Knight <jon@net.lut.ac.uk>
#          Martin Hamilton <martinh@gnu.org>
#
# $Id: dumpdbm.pl,v 3.4 1998/08/18 19:24:45 martin Exp $

use Getopt::Std;
getopts('htf:');

require ROADS;
use ROADS::ErrorLogging;
use ROADS::CGIvars;

# Output format to use.  Default to colon separated but allow either a table
# or HTML output.
$Table = $HTML = 0;
$Table = 1 if ($opt_t);
$HTML = 1 if ($opt_h);

# Force output in HTML and get CGI parameters if we appear to be a CGI script
if($ENV{GATEWAY_INTERFACE} ne "") {
  $HTML = 1;
  &cleaveargs;  

  unless($ENV{REMOTE_USER}) {
    print STDOUT <<EndOfHTML;
Content-type: text/html

<HTML>
<HEAD>
<TITLE>Can't dump $DBMFile</TITLE>
</HEAD>
<BODY>
<H1>Can't dump $DBMFile</H1>

Sorry - you can only run this as a CGI script if you're HTTP authenticated!
</BODY>
</HTML>
EndOfHTML

    exit;
  }
}

# Look at the index indirection file by default.
$DBMFile = $opt_f || $CGIvar{file} || "$ROADS::Guts/index.dbm";

dbmopen(%HASH, "$DBMFile", 0644);

# If HTML output, write a nice header
if($HTML) {
  print STDOUT <<"EndOfHTML";
Content-Type: text/html

<HTML>
<HEAD>
<TITLE>DBM Dump of $DBMFile</TITLE>
</HEAD>
<BODY>
<H1>DBM Dump of $DBMFile</H1>

<TABLE BORDER>
<TR><TH>Key</TH><TH>Value</TH></TR>
EndOfHTML
}

while(($key, $val) = each %HASH) {
  if($HTML) {
    print STDOUT "<TR><TD>$key</TD><TD>$val<BR></TD></TR>\n";
  } elsif($Table) {
    write;
  } else {
    print STDOUT "$key: $val\n";
  }
}

if($HTML) {
  print STDOUT <<"EndOfHTML";
</TABLE>
</BODY>
</HTML>
EndOfHTML
}
dbmclose(%HASH);
exit(0);

format STDOUT_TOP=
DBM Dump of : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
              $DBMFile
key                             value
------------------------------------------------------------------------------
.

format STDOUT=
^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$key,				$val
.

exit;
__END__


=head1 NAME

B<admin-cgi/dumpdbm.pl> - dump out DB(M) database entries and keys

=head1 SYNOPSIS

  admin-cgi/dumpdbm.pl [-f filename] [-h] [-t]
 
=head1 DESCRIPTION

This Perl program will dump out the contents of a DB(M) database,
formatted as pretty-printed text, HTML, or HTML TABLES.  It defaults
to the ROADS indirection index I<guts/index.idr>.

=head1 OPTIONS

=over 4

=item B<-f> I<filename>

DB(M) database filename to operate on.

=item B<-h>

Generate HTML.

=item B<-t>

Generate HTML >= 3.2 tables.

=back

=head1 BUGS

Because of the security problems associated with being able to read
arbitrary files over the WWW, this program will only operate on an
arbitrary file if the user is HTTP authenticated.

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
