#!/usr/bin/perl
use lib "/home/roads2/lib";

# expansions.pl - render list of query expansions as HTML
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: expansions.pl,v 2.15 1998/08/28 17:37:08 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;

&cleaveargs;
&CheckUserAuth("expansions_users");

print <<EOF;
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Query expansions</TITLE>
</HEAD>
<BODY>

<H1>Query expansions</H1>

<PRE>
EOF

open(IN, "$ROADS::Config/expansions")
  || &WriteToErrorLogAndDie("$0", "Can't open $ROADS::Config/expansions: $!");
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

B<admin-cgi/expansions.pl> - render list of query expansions into HTML

=head1 SYNOPSIS

  admin-cgi/expansions.pl
 
=head1 DESCRIPTION

This Perl program generates an HTML document containing the list of
query expansions performed by the WHOIS++ server when stemming is
enabled.

=head1 OPTIONS

None.

=head1 OUTPUT

List of query expansions, in the form

  search_term expanded_term

e.g.

  colour color

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

