#!/usr/bin/perl
use lib "/home/roads2/lib";

# bogus.pl - WWW front end to installation bogosity checker
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: bogus.pl,v 2.16 1998/08/18 19:24:45 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;

&cleaveargs;
&CheckUserAuth("admincentre_users");

print <<EOF;
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>ROADS sanity check</TITLE>
</HEAD>
<BODY>
EOF

open(IN, "$ROADS::Bin/bogus.pl -h|")
  || &WriteToErrorLogAndDie("$0", 
      "Can't open pipe to $ROADS::Bin/bogus.pl: $!");
while(<IN>) { print $_; }
close(IN);

print <<EOF;
<HR>
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EOF

exit;
__END__


=head1 NAME

B<admin-cgi/bogus.pl> - WWW front end to installation bogosity checker

=head1 SYNOPSIS

  admin-cgi/bogus.pl
 
=head1 DESCRIPTION

This Perl program runs the ROADS installation checking tool,
I<bogus.pl>, and presents the results of the check as an HTML
document.

=head1 OPTIONS

None.

=head1 OUTPUT

List of installation problems, if any.

=head1 SEE ALSO

L<bin/bogus.pl>

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

