#
# ROADS::Auth - Check user authentication for admin tools
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#         Martin Hamilton <martinh@gnu.org>
#
# $Id: Auth.pm,v 3.14 1998/09/05 13:58:57 martin Exp $
#

package ROADS::Auth;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(CheckUserAuth);

use ROADS::HTMLOut;

#
# Subroutine to check user authentication during template editing
# and other admin tool type things.
#
sub CheckUserAuth {
    local($registry) = @_;
    local($remoteuser,$handle,$matched,$user);

    $registry = "template_users" unless defined($registry);

    # Pickup the remote user name and authentication type.
    $remoteuser = $ENV{REMOTE_USER};

    # Only bother with this if we've been authenticated (pointless otherwise
    # as there'll be no REMOTE_USER environment variable set).
    return if ($ENV{AUTH_TYPE} eq "");

    # Open the DBM database.
    return unless (dbmopen(%TempAuth,"$ROADS::Config/auth/$registry", 0644));
    
    # Get the original handle of the template and then look through the list
    # of valid users.
    unless ($registry eq "template_users") {  # template editor stuff
        unless (defined($TempAuth{"$remoteuser"})) {
            print "Content-type: text/html\n\n";
            &OutputHTML("lib","authfail.html",$Language,$CharSet);
            exit(-1);
        }
        dbmclose(%TempAuth);
    }

    # Must be template editor related
    $handle = $CGIvar{originalhandle};
    if(defined($TempAuth{$handle})) {
        $matched = 0;
        foreach $user (split(" ",$TempAuth{$handle})) {
            $matched = 1 if($user eq $remoteuser);
            last if($matched == 1);
        }
        if($matched == 0) {
            print "Content-type: text/html\n\n";
            &OutputHTML("lib","authfail.html",$Language,$CharSet);
            exit(-1);
        }
    }
    dbmclose(%TempAuth);
}

1;
__END__


=head1 NAME

ROADS::Auth - A class to check user authentication for admin tools

=head1 SYNOPSIS

  use ROADS::Auth;
  CheckUserAuth("app_users"); # check user against app_users ACL

=head1 DESCRIPTION

This class implements a simple access control list mechanism which
piggybacks on top of the access controls provided by HTTP.  It assumes
that the user has been authenticated already by HTTP, and that the
authenticated user name is available in the REMOTE_USER environment
variable - usually set in the process of launching a CGI program.

=head1 METHODS

=head2 CheckUserAuth( registry_name );

Looks in the user registry I<registry_name>, which is a DB(M) database
keyed on the user name, for a record keyed on the REMOTE_USER
environmental variable.  Exits with an error page if authentication
fails.

=head1 FILES

I<config/multilingual/*/lib/authfail.html> - message returned
on an authentication failure

I<config/auth/*> - DBM databases of per-program registry information.

=head1 BUGS

The CheckUserAuth method should return a response code rather than
bombing out if the user couldn't be authenticated.

This should really be a class to manipulate authentication objects,
rather than just a checker.

=head1 SEE ALSO

L<admin-cgi/mktemp.pl>

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

Jon Knight E<lt>jon@net.lut.ac.ukE<gt>,
Martin Hamilton E<lt>martinh@gnu.orgE<gt>

