#!/usr/bin/perl
use lib "/home/roads2/lib";

# review.pl - WWW front end to review date checker
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: review.pl,v 3.11 1998/08/18 19:24:45 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;

&cleaveargs;
&CheckUserAuth("review_users");

print <<EOF;
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Review dates check</TITLE>
</HEAD>
<BODY>

<H1>Review dates check</H1>
<PRE>
EOF

open(IN, "$ROADS::Bin/review.pl -r|")
  || &WriteToErrorLogAndDie("review",
       "Can't open pipe to $ROADS::Bin/review.pl: $!");
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

B<admin-cgi/review.pl> - WWW front end to review date checker

=head1 SYNOPSIS

  admin-cgi/review.pl
 
=head1 DESCRIPTION

This Perl program runs B<review.pl>, the tool which checks to see
which records in the ROADS database are due for review, and generates
an HTML document from its results.

=head1 OPTIONS

None.

=head1 OUTPUT

List of due-for-review templates.

=head1 SEE ALSO

L<bin/review.pl>

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


