#
# ROADS::Override - read in list of protocol schemes to override and
#               what page to display in their stead
#
# Authors: Martin Hamilton <martinh@gnu.org>
# $Id: Override.pm,v 3.9 1998/08/18 19:21:25 martin Exp $

package ROADS::Override;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(Override);

use ROADS::ErrorLogging;

sub Override {
    $protocols = "$ROADS::Config/protocols" unless $protocols;

    unless (open(PROTOCOLS, "$protocols")) {
        WriteToErrorLog($0, "Can't open protocols file $protocols: $!");
        return;
    }

    while(<PROTOCOLS>) {
        next if /^#/;
        chomp;

        ($scheme,$page) = split(":");
        $override{"$scheme"}="$page";
    }

    close(PROTOCOLS);
}

1;
__END__


=head1 NAME

ROADS::Override - A class to override unusual/odd URL protocol schemes

=head1 SYNOPSIS

  use ROADS::Override;
  Override;
  if ($override{"wais"}) {
    $page_to_return = $override{"wais"};
  } else {
    $page_to_return = $regular_page;
  }

=head1 DESCRIPTION

This class defines a method which constructs a hash array keyed on the
protocol scheme element of a URL.  Looking up a protocol scheme which
have been overridden returns a filename which should be used instead
of the filename which would normally be used.  This provides a simple
mechanism for insinuating intermediate pages of HTML when (for
example) rendering search results into HTML, which can be used to add
instructions or additional information as necessary.

=head1 METHODS

=head2 Override;

This method loads the list of protocols to override and HTML pages to
return into the hash array I<override>.

=head1 FILES

I<config/protocols> unless overridden by the I<protocols> variable.

=head1 FILE FORMAT

The I<protocols> file is formatted with one entry per line.  Each
entry contains the following fields :-

=over 4

=item B<scheme>

The protocol scheme to override.

=item B<page>

The intermediary HTML page to return when this protocol scheme is
requested.

=back

=head1 SEE ALSO

L<admin-cgi/lookupcluster.pl>, L<cgi-bin/search.pl>,
L<cgi-bin/tempbyhand.pl>, L<cgi-bin/waylay.pl>

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

