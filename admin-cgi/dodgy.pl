#!/usr/bin/perl
use lib "/home/roads2/lib";

# dodgy.pl - WWW front end to link checker report on consistently
# unreachable URLs
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: dodgy.pl,v 3.11 1998/08/18 19:24:45 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;

&cleaveargs;
&CheckUserAuth("dodgy_users");

print <<EOF;
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Consistently unreachable URLs</TITLE>
</HEAD>
<BODY>

<H1>Consistently unreachable URLs</H1>

<PRE>
EOF

open(IN, "$ROADS::Bin/dodgy.pl|")
  || &WriteToErrorLogAndDie("dodgy",
       "Can't open pipe to $ROADS::Bin/dodgy.pl: $!");
while(<IN>) { print $_; }
close(IN);

print <<EOF;
</PRE>
<HR>
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EOF

__END__
exit;


=head1 NAME

B<admin-cgi/dodgy.pl> - WWW front end to link checker report on
  consistently unreachable URLs

=head1 SYNOPSIS

  admin-cgi/dodgy.pl
 
=head1 DESCRIPTION

This Perl program runs B<dodgy.pl>, and post-processes its results into
an HTML document.  B<dodgy.pl> takes the three most recent link checker
summary reports and looks for resources which have been consistently
unavailable.

=head1 OPTIONS

None.

=head1 OUTPUT

List of stale resources.

=head1 SEE ALSO

L<bin/dodgy.pl>

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

