#!/usr/bin/perl
use lib "/home/roads2/lib";

# templateadmin.pl : Administer the users allowed to edited a template
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: templateadmin.pl,v 3.10 1998/08/18 19:31:28 martin Exp $
#

require "getopts.pl"

require ROADS;

# Pickup the username and handle and operation desired
&Getopts('h:o:u:');
$handle = $opt_h;
exit(-1) if($handle eq "");
$operation = $opt_o;
$thisuser = $opt_u;

# Open the DBM database.
dbmopen(%TempAuth,"$ROADS::Config/template_users", 0644);

# Get the current list of users for this template into an associate array.
foreach $user (split(" ",$TempAuth{"$handle"})) {
    $UserList{"$user"} = 1;
}

if($operation =~ /^ADD$/) {
    # Add a new user to the list of valid users and write the array back out
    # to the DBM database.
    $UserList{"$thisuser"} = 1;
    $TempAuth{"$handle"} = join(" ",keys(%UserList));
} elsif($operation =~ /^DEL$/) {
    # Delete a user from the list of valid users and write the array back out
    # to the DBM database.
    foreach $user (keys(%UserList)) {
        $NewUsers{"$user"} = 1 unless ($user eq $thisuser);
    }
    $TempAuth{"$handle"} = join(" ",keys(%NewUsers));
} elsif($operation =~ /^LIST$/) {
    # List the valid users for this handle
    $comma = "";
    foreach $user (keys(%UserList)) {
        print STDOUT "$comma$user";
        $comma=", ";
    }
} else {
    # Unknown operation
    exit(-2);
}

# Close the DBM database (exiting Perl should do this but we'll do explicitly
# for safety's sake).
dbmclose(%TempAuth);

# Done
exit(0);
__END__


=head1 NAME

B<bin/templateadmin.pl> - template editor ACL manager

=head1 SYNOPSIS

  bin/templateadmin.pl [-h handle] [-o operation] [-u user]

=head1 DESCRIPTION

This program provides a mechanism for adding users to and removing
users from the access control lists used by the ROADS template editor.
The access control lists (if present) control which users are allowed
to update the nominated templates.

=head1 OPTIONS

=over 4

=item B<-h> I<handle>

This is the handle to be operated on.

=item B<-o> I<operation>

This is the operation to be carried out, one of

  ADD - add user to the ACL for this template
  DELETE - delete user from the ACL for this template
  LIST - list ACL for this template

=item B<-u> I<user>

The user name to add or delete from the ACL for this template.

=back

=head1 FILES

I<config/template_users> - DB(M) database of template ACLs.

=head1 SEE ALSO

L<admin-cgi/tempuserauth.pl>, L<admin-cgi/mktemp.pl>

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

