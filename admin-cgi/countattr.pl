#!/usr/bin/perl
use lib "/home/roads2/lib";

# countattr.pl - WWW front end to template statistics gatherer
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: countattr.pl,v 3.10 1998/08/18 19:24:45 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;

&cleaveargs;
&CheckUserAuth("countattr_users");

print <<EOF;
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Template statistics</TITLE>
</HEAD>
<BODY>

EOF

open(IN, "$ROADS::Bin/countattr.pl -ah|")
  || &WriteToErrorLogAndDie("countattr",
       "Can't open pipe to $ROADS::Bin/countattr.pl: $!");
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


=head1 NAME

B<admin-cgi/countattr.pl> - WWW front end to template statistics gatherer

=head1 SYNOPSIS

  admin-cgi/countattr.pl
 
=head1 DESCRIPTION

This Perl program runs B<countattr.pl>, the ROADS template statistics
gathering tool, and renders its results as an HTML document.

=head1 OPTIONS

None.

=head1 OUTPUT

Template statistics.

=head1 SEE ALSO

L<bin/countattr.pl>

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

