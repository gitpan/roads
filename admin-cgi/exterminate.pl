#!/usr/bin/perl
use lib "/home/roads2/lib";

# exterminate.pl - WWW front end to link checker zapping of persistently
# stale templates
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: exterminate.pl,v 2.16 1998/09/05 14:01:07 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;

&cleaveargs;
&CheckUserAuth("exterminate_users");

if ($ROADS::DBAdminEmail eq $ROADS::SysAdminEmail) {
    $emailto = "<EM>$ROADS::DBAdminEmail</EM>"
} else {
    $emailto = "<EM>$ROADS::DBAdminEmail</EM> and "
	. "<EM>$ROADS::SysAdminEmail</EM>";
}

print <<EOF;
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Removing stale templates</TITLE>
</HEAD>
<BODY>

<H1>Removing stale templates</H1>

Scheduled background reindexing of ROADS database, without these
templates (status changed to "stale")<P>

Email will be sent to $emailto when this has finished<P>

<HR>
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EOF

close(STDOUT);
system("$ROADS::Bin/bg_exterminate.pl");
exit;
__END__


=head1 NAME

B<admin-cgi/exterminate.pl> - Zapping of persistently stale templates

=head1 SYNOPSIS

  admin-cgi/exterminate.pl
 
=head1 DESCRIPTION

This Perl program schedules a background run of B<exterminate.pl>, the
ROADS tool which automatically removes stale templates from the
database.  Stale templates are deemed to be those whose URLs have not
been available for the last three runs of the ROADS link checking tool.

=head1 OPTIONS

None.

=head1 OUTPUT

Mail message to ROADS server and database maintainers.

=head1 SEE ALSO

L<bin/exterminate.pl>

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

