#!/usr/bin/perl
use lib "/home/roads2/lib";

# register.pl - WWW front end to server registration
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: register.pl,v 2.15 1998/08/18 19:24:45 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;

&cleaveargs;
&CheckUserAuth("register_users");

system("$ROADS::Bin/info.pl|$ROADS::MailerPath -s registration $ROADS::RegEmail");


print <<EOF;
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Server registration</TITLE>
</HEAD>
<BODY>

<H1>Server registration</H1>

Registration sent to $ROADS::RegEmail!<P>

<HR>
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EOF

exit;
__END__


=head1 NAME

B<admin-cgi/register.pl> - WWW front end to server registration

=head1 SYNOPSIS

  admin-cgi/register.pl
 
=head1 DESCRIPTION

This Perl program provides a World-Wide Web interface to
B<register.pl>, the ROADS tool for server registration.  If you want
to see the details which would be sent to the ROADS developers when
your server is registered, use the B<info.pl> tool - this also has a
WWW front end.

=head1 OPTIONS

None.

=head1 SEE ALSO

L<bin/register.pl>

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

