#!/usr/bin/perl
use lib "/home/roads2/lib";

# tempuserauth.pl : do user authentication for template editor
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: tempuserauth.pl,v 3.11 1998/08/18 19:24:45 martin Exp $
#

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::HTMLOut;

# Fix for stupid Netscape server bug/misfeature
close(STDERR) if $ENV{"SERVER_NAME"} =~ /netscape/i;

use Getopt::Std;
getopts('C:L:du:');

# The URL of this program
$myurl = $opt_u || "/$ROADS::WWWAdminCgi/tempuserauth.pl";

# The location of the real program that we call to do the business.
$prog = "$ROADS::Bin/templateadmin.pl";

# Print out the HTTP Content-type header and then cleave the CGI URL into
# an associative array ready for use.
&cleaveargs;
&CheckUserAuth("tempuserauth_users");
print "Content-type: text/html\n\n";
# Debugging
$debug = $CGIvar{debug} || $opt_d;

$Handle = $CGIvar{handle};
$Username = $CGIvar{username};
$Handle =~ s/[\r\n]//g;
$Username =~ s/[\r\n]//g;
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

if($CGIvar{"operation"} eq "") {
    &OutputHTML("tempuserauth","mainform.html",$Language,$Charset);
} elsif($Handle eq "") {
    &OutputHTML("tempuserauth","missinghandle.html",$Language,$Charset);
} elsif($CGIvar{"operation"} eq "ADD") {
    if($Username eq "") {
        &OutputHTML("tempuserauth","missinguser.html",$Language,$Charset);
    } else {
        $res = system("$prog -h $Handle -o ADD -u $Username");
        &OutputHTML("tempuserauth","added.html",$Language,$Charset);
    }
} elsif($CGIvar{"operation"} eq "DEL") {
    if($Username eq "") {
        &OutputHTML("tempuserauth","missinguser.html",$Language,$Charset);
    } else {
        $res = system("$prog -h $Handle -o DEL -u $Username");
        &OutputHTML("tempuserauth","deleted.html",$Language,$Charset);
    }
} elsif($CGIvar{"operation"} eq "LIST") {
    &OutputHTML("tempuserauth","listinghead.html",$Language,$Charset);
    open(PROG,"$prog -h $Handle -o LIST |");
    $res = <PROG>;
    print STDOUT $res;
    print STDOUT "No users registered" if($res eq "");
    &OutputHTML("tempuserauth","listingtail.html",$Language,$Charset);
} else {
    &OutputHTML("tempuserauth","unknownop.html",$Language,$Charset);
}

exit(0);
__END__


=head1 NAME

B<admin-cgi/tempuserauth.pl> - WWW front end to template ACL editor

=head1 SYNOPSIS

  admin-cgi/tempuserauth.pl [-C charset] [-d] [-L language]
    [-u url]
 
=head1 DESCRIPTION

This CGI program is actually a front end to the B<templateadmin.pl>
program, which lets authenticated users update the access controls
associated with a particular template.

=head1 OPTIONS

=over 4

=item B<-C> I<charset>

The character set to use.

=item B<-d>

Boolean variable which controls debugging mode.

=item B<-L> I<language>

The language to use.

=item B<-u> I<url>

Specifies the URL of the program itself.

=back

=head1 CGI VARIABLES

=over 4

=item B<charset>

The character set to use.

=item B<debug>

Boolean variable which controls debugging mode.

=item B<handle>

Template whose access control list is being edited.

=item B<language>

The language to use.

=item B<operation>

The operation to carry out, normally one of :-

  ADD - add user to ACL for this template
  DELETE - remove user from the ACL for this template
  LIST - list users who can change this template

=item B<username>

The user name in question - corresponding to user names registered for
HTTP authentication.

=back

=head1 FILES

I<config/multilingual/*/tempuserauth/mainform.html>
- main HTML form returned when calling B<tempuserauth.pl>
with no parameters.

I<config/multilingual/*/tempuserauth/missinghandle.html>
- main form submitted with no handle parameter.

I<config/multilingual/*/tempuserauth/missinguser.html>
- main form submitted with no user name parameter.

I<config/multilingual/*/tempuserauth/added.html>
- HTML returned when ACL added successfully.

I<config/multilingual/*/tempuserauth/deleted.html>
- HTML returned when ACL deleted successfully.

I<config/multilingual/*/tempuserauth/listinghead.html>
- beginning of ACL listing for the template

I<config/multilingual/*/tempuserauth/listingtail.html>
- end of the ACL listing for the template

I<config/multilingual/*/tempuserauth/unknownop.html>
- an unknown operation was requested

=head1 SEE ALSO

L<admin-cgi/mktemp.pl>, L<admin-cgi/mktemp-config-editor.pl>

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

Jon Knight E<lt>jon@net.lut.ac.ukE<gt>

