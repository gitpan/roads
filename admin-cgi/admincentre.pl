#!/usr/bin/perl
use lib "/home/roads2/lib";

# admincentre.pl - filter admincentre document for presentation

# Author: Martin Hamilton <martinh@gnu.org>
# $Id: admincentre.pl,v 3.10 1998/08/18 19:24:45 martin Exp martin $

use Getopt::Std;
getopts("C:L:f:");

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::HTMLOut;

&cleaveargs;
&CheckUserAuth("admincentre_users");

# Source for the HTML FORM
$htmlform = $opt_f || "admincentre.html";

# What language to return
$Language = $opt_L || "en-uk";

# What character set to use.
$CharSet = $opt_C || "ISO-8859-1";

# Change the output language if specified in either the HTTP headers or the
# CGI variables passed from the browser.
if ($ENV{"HTTP_ACCEPT_LANGUAGE"} ne "") {
    $Language = $ENV{"HTTP_ACCEPT_LANGUAGE"};
}
if ($CGIvar{language} ne "") {
    $Language = $CGIvar{language};
}

# Change the character set if specified in either the HTTP headers of the
# CGI variables passed from the browser.
if ($ENV{"HTTP_ACCEPT_CHARSET"} ne "") {
    $CharSet = $ENV{"HTTP_ACCEPT_CHARSET"};
}
if ($CGIvar{charset} ne "") {
    $CharSet = $CGIvar{charset};
}

if ($CGIvar{form} ne "") {
    $htmlform = "$CGIvar{form}";
    $htmlform =~ tr/[A-Za-z0-9]//c;
    $htmlform .= ".html";
}

print "Content-type: text/html\n\n";

&OutputHTML("admincentre", "$htmlform", $Language, $CharSet);
exit;
__END__


=head1 NAME

B<admin-cgi/admincentre.pl> - filter admincentre document for presentation

=head1 SYNOPSIS

  admin-cgi/admincentre.pl [-C charset] [-f form]
    [-L language]
  
=head1 DESCRIPTION

This Perl program filters the HTML document which specifies the user
interface to the ROADS software seen by admin users, converting any
ROADS-specific tags into normal HTML.

=head1 OPTIONS

These options are intended for debugging use only.

=over 4

=item B<-f> I<filename>

Alternative file to find the HTML outline in.

=item B<-C> I<charset>

Set character set manually.

=item B<-L> I<language>

Set language manually.

=back

=head1 CGI VARIABLES

=over 4

=item B<htmlform>

The HTML returned to the end user - normally I<admincentre.html>.

=item B<charset>

The character set to use.

=item B<language>

The language to use.

=back

=head1 FILES

I<config/multilingual/*/admincentre/admincentre.html>
- the HTML to return to the end user.

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


