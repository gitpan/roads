#
# ROADS::DatabaseNames - read in list of databases
#
# Authors: Jon Knight <jon@net.lut.ac.uk>
#          Martin Hamilton <martinh@gnu.org>
# $Id: DatabaseNames.pm,v 3.13 1998/08/18 19:21:25 martin Exp $

package ROADS::DatabaseNames;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(ReadDBNames %database %host %port %serverhandle %invserverhandle);

use ROADS::ErrorLogging;

#
# Subroutine to read in the names and paths of the databases in use.
#
sub ReadDBNames {
    print "Entered ReadDBNames...<BR>\n" if($debug);
    $dbnames = "$ROADS::Config/databases" unless $dbnames;

    unless (open(DBS,"$dbnames")) {
        &WriteToErrorLog($0, "Can't open databases config file: $!");
        return;
    }

    while(<DBS>) {
        next if /^#/;
        next if /^\s*$/;
        chomp;

        ($name,$host,$port,$tag,$handle) = split(":");
        $database{$name}=$tag;
        $host{$name}=$host;
        $port{$name}=$port;
        $serverhandle{$name}=$handle;
        $invserverhandle{$handle}=$name;
        if($debug) {
            print "database{$name}='$tag'<BR>\n";
            print "host{$name}='$host'<BR>\n";
            print "port{$name}='$port'<BR>\n";
            print "serverhandle{$name}='$handle'<BR>\n";
            print "invserverhandle{$handle}='$name'<BR>\n";
        }
    }

    close(DBS);
    print "Leaving ReadDBNames...<BR>\n" if($debug);
}

1;
__END__


=head1 NAME

ROADS::DatabaseNames - A class to read in the list of ROADS databases

=head1 SYNOPSIS

  use ROADS::DatabaseNames;
  &ReadDBNames;
  # let's see the database details for the 'cross domain' DB
  print <<EOF;
    database: $database{xdomain}
    host: $host{xdomain}
    port: $port{xdomain}
    serverhandle: $serverhandle{xdomain}
    invserverhandle: $invserverhandle{xdomain}
  EOF

=head1 DESCRIPTION

This method reads the list of WHOIS++ servers/databases which this
ROADS installation knows about and puts their details into hash
arrays.

=head1 METHODS

=head2 ReadDBNames;

When this method is called, it creates the following hash arrays by
parsing the list of known databases :-

=over 4

=item B<database>

Holds the I<Destination> tag (if any) used with this database when
making a WHOIS++ search.  Multiple I<Destination> tags may be used to
differentiate between multiple WHOIS++ databases held in a single
server.

=item B<host>

Holds the Internet domain name or address of the host running the
WHOIS++ server for this database.

=item B<port>

Holds the port number of the WHOIS++ server.

=item B<serverhandle>

Holds the server handle of this WHOIS++ server.

=item B<invserverhandle>

Converts the server handle back into a friendly service name.

=back

All but the last of these arrays are indexed on the friendly service
name, whereas the last is indexed on the server handle.  So, in the
example above...

  $invserverhandle{$serverhandle{"xdomain"}} eq "xdomain"

=head1 FILES

I<config/databases> - default location for databases list, overridden
by I<dbnames> variable if defined.

=head1 FILE FORMAT

The following fields are defined in the I<databases> file, in the
following order :-

=over 4

=item B<name>

Long/friendly name of the service, e.g. "ROADS-U-LIKE".

=item B<host>

Domain name or IP address of the host running the WHOIS++ server.

=item B<port>

Port number of the WHOIS++ server.

=item B<tag>

Tag used in the I<Destination> attribute - used if this server has
multiple virtual databases in one collection of templates.

=item B<handle>

The WHOIS++ server's serverhandle.

=back

=head1 BUGS

We should do something cleverer with this list, like have a "database"
object which included protocol info and hooks for the methods to use
to communicate with it.  This would make it easier to link in other
sources of info ?

=head1 SEE ALSO

L<cgi-bin/search.pl>, L<admin-cgi/admin.pl>, L<cgi-bin/tempbyhand.pl>,
L<admin-cgi/lookupcluster.pl>,

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

