#!/usr/bin/perl
use lib "/home/roads2/lib";

# search_restrict.pl - show list of search restrictions for end users
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: search_restrict.pl,v 3.10 1998/08/18 19:24:45 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;

&cleaveargs;
&CheckUserAuth("search_restrict_users");

print <<EOF;
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Search restrictions for end users</TITLE>
</HEAD>
<BODY>

<H1>Search restrictions for end users</H1>

<PRE>
EOF

open(IN, "$ROADS::Config/search-restrict")
  || &WriteToErrorLogAndDie("search_restrict",
       "Can't open $ROADS::Config/search-restrict: $!");
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

B<admin-cgi/search_restrict.pl> - show list of search restrictions for
  end users

=head1 SYNOPSIS

  admin-cgi/search_restrict.pl

=head1 DESCRIPTION

This Perl program reads in the list of search restrictions which apply
to end users, and renders it as part of an HTML document.

=head1 OPTIONS

None

=head1 FILES

I<config/search-restrict> - user search restrictions.

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


