#!/usr/bin/perl
use lib "/home/roads2/lib";

# freq.pl - WWW front end to term frequency counter
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: freq.pl,v 3.10 1998/08/18 19:24:45 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;

&cleaveargs;
&CheckUserAuth("freq_users");

print <<EOF;
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Frequency count</TITLE>
</HEAD>
<BODY>

<H1>Frequency count</H1>

<P>The <EM>fifty</EM> most common terms:</P>
<PRE>
EOF

open(IN, "$ROADS::Bin/freq.pl|")
  || &WriteToErrorLogAndDie("freq",
       "Can't open pipe to $ROADS::Bin/freq.pl: $!");
while(<IN>) { print $_; }
close(IN);

print <<EOF;
</PRE>
<HR>
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EOF

exit;
__END__


=head1 NAME

B<admin-cgi/freq.pl> - WWW front end to term frequency counter

=head1 SYNOPSIS

  admin-cgi/freq.pl
 
=head1 DESCRIPTION

This Perl program launches the ROADS term frequency counter tool,
B<freq.pl>, and renders its results as an HTML document.  The
default setting is to return the fifty most commonly occurring
terms from the ROADS database.

=head1 OPTIONS

None.

=head1 OUTPUT

List of commonly found terms.

=head1 SEE ALSO

L<bin/freq.pl>

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

