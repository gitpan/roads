#!/usr/bin/perl
use lib "/home/roads2/lib";

# dup_urls.pl - WWW front end to duplicate URL checker
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: dup_urls.pl,v 3.11 1998/08/18 19:24:45 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;

$cleaveargs;
&CheckUserAuth("dup_urls_users");

$myurl = "/$ROADS::WWWCgiBin/tempbyhand.pl";
$svcname = "$ROADS::ServiceName";  $svcname =~ s/ /+/g;

print <<EOF;
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Resource descriptions sanity check</TITLE>
</HEAD>
<BODY>

<H1>Resource descriptions sanity check</H1>
<PRE>
EOF

open(IN, "$ROADS::Bin/dup_urls.pl -a|")
  || &WriteToErrorLogAndDie("dup_urls",
       "Can't open pipe to $ROADS::Bin/dup_urls.pl: $!");
while(<IN>) { 
  chomp;
  s/ ([^\s]+)/ <A HREF="$myurl\?query\=$1&database=$svcname">$1<\/A>/g;
  print "$_\n"; 
}
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

B<admin-cgi/dup_urls.pl> - WWW front end to IAFA template checker

=head1 SYNOPSIS

  admin-cgi/dup_urls.pl
 
=head1 DESCRIPTION

This Perl program launches the ROADS duplicate URL checking tool, and
generates an HTML document from its results.

=head1 OPTIONS

None.

=head1 OUTPUT

List of URLs and templates in which they occur.

=head1 SEE ALSO

L<bin/dup_urls.pl>

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

