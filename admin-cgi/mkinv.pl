#!/usr/bin/perl
use lib "/home/roads2/lib";

# mkinv.pl - WWW front end to the mkinv.pl program
#
# Authors: Jon Knight <jon@net.lut.ac.uk>
#          martin hamilton <martinh@gnu.org>
# $Id: mkinv.pl,v 2.17 1998/12/01 17:54:07 jon Exp $

# Fix for stupid Netscape server bug/misfeature
close(STDERR) if $ENV{"SERVER_NAME"} =~ /netscape/i;

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;

use Getopt::Std;
getopts('du:');

#
# Options
#

# The URL of this program
$myurl = $opt_u || "/$ROADS::WWWAdminCgi/mkinv.pl";

# Main code

# Print out the HTTP Content-type header and then cleave the CGI URL into
# an associative array ready for use.
&cleaveargs;
&CheckUserAuth("mkinv_users");
print "Content-type: text/html\n\n";

# Debugging
$debug = $CGIvar{debug} || $opt_d;

unless ($ENV{QUERY_STRING}) {
    print <<"EndOfHTML";
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Inverted Index Generator</TITLE>
</HEAD>
<BODY>
<H1>Inverted Index Generator</H1>

<P>
This form allows you to generate ROADS inverted index entries for templates
that have <strong>NOT</strong> been generated with the ROADS template editor.
Note that you do not need to use this form to generate an inverted index entry
for a template that has already been entered into your database using the
ROADS template editor.
</P>

<P>
Note that if a large number of templates are being indexed then the process
can take several minutes.
</P>
<HR>
<FORM ACTION="$myurl" METHOD="GET">
Index all templates: <INPUT TYPE="radio" NAME="all" VALUE="Y"><BR>
Index specific templates: <INPUT TYPE="radio" NAME="all" VALUE="N" CHECKED><BR>
Specific template handles:<BR>
<TEXTAREA NAME="handles" ROWS="6" COLS="40"></TEXTAREA><BR>
<INPUT TYPE="submit" VALUE="Do index">
</FORM>
<HR>
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EndOfHTML
    exit;
}

# Index all the templates in the default source directory.
if($CGIvar{all} eq "Y") {
    system("$ROADS::Bin/mkinv.pl" ,"-a", $debug ? "-d" : "");
    $status = $?;

    print <<"EndOfHTML";
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Indexing all templates</TITLE>
</HEAD>
<BODY>
<H1>Indexing all templates</H1>

<P>
All the templates in the default source directory have
EndOfHTML

    if ($status eq 0) {
	print "been added to the inverted index.\n";
    } else {
	print "<STRONG>NOT</STRONG> been added to the inverted index.\n";
	print "Consult the error log to find out why!\n";
    }

    print <<"EndOfHTML";
</P>
<HR>
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EndOfHTML

    exit;
}

# Index the templates with the specified handles.
($handles = $CGIvar{handles}) =~ tr/a-zA-Z0-9\-/ /c;
system("$ROADS::Bin/mkinv.pl", split(/\s+/,$handles));
$status = $?;

print <<"EndOfHTML";
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Indexing specified templates</TITLE>
</HEAD>
<BODY>
<H1>Indexing specified templates</H1>
<P>
The requested templates <EM>$handles</EM> have
EndOfHTML

if ($status eq 0) {
    print "been added to the inverted index.\n";
} else {
    print "<STRONG>NOT</STRONG> been added to the inverted index.\n";
    print "Consult the error log to find out why.\n";
}

print <<"EndOfHTML";
</P>
<HR> 
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EndOfHTML

exit;
__END__


=head1 NAME

B<admin-cgi/mkinv.pl> - WWW front end to index generator

=head1 SYNOPSIS

  admin-cgi/mkinv.pl [-d] [-u url]
 
=head1 DESCRIPTION

This Perl program runs B<mkinv.pl> in the background to re-generate
the ROADS database index.  It is intended for use when new templates
have been added manually to the database, the database contents have
been altered manually, or the index is suspected to be corrupt - and
for reindexing the database after a bulk upload of new templates.

An HTML form is generated, and the user is given the choice of either
re-indexing the entire database, or just nominated records.

=head1 OPTIONS

These options are intended only for debugging use.

=over 4

=item B<-d>

Generate debugging information

=item B<-u> I<myurl>

The URL of this program.

=back

=head1 CGI VARIABLES

=over 4

=item B<all>

Boolean variable which indicates whether to index all templates.

=item B<debug>

Boolean variable which causes debugging output to be generated if
enabled.

=item B<handles>

Template handles to index, if not indexing all templates.

=back

=head1 SEE ALSO

L<bin/mkinv.pl>

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

