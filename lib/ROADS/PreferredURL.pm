#
# ROADS::PreferredURL - determine the preferred URL from a resource.
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: PreferredURL.pm,v 3.3 1998/08/18 19:21:25 martin Exp $

package ROADS::PreferredURL;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(preferredURL);

sub preferredURL {
    my(%TEMPLATE) = @_;

    my($loop,$level,$preferred)=0;
    my(@attr);

    @attr = keys(%TEMPLATE);
    $preferred = "";
    foreach $loop (@attr) {
        $_ = $loop;
        if (/^UR[LI]/i) {
            $check = $TEMPLATE{"$loop"};
            $check =~ s/\s//g;
            $url = $check;
            $check =~ s/\s*(\w+):(.*)/$1/;
warn "In preferredURL with check = '$check'.\n" if $debug;
            if ($check eq "http") {
                $preferred = $url;
                $level = 6;
            }
            if (($check eq "gopher") && ($level < 6)) {
                $preferred = $url;
                $level = 5;
            }
            if (($check eq "ftp") && ($level < 5)) {
                $preferred = $url;
                $level = 4;
            }
            if (($check eq "telnet") && ($level < 4)) {
                $preferred = $url;
                $level = 3;
            }
            if (($check eq "wais") && ($level < 3)) {
                $preferred = $url;
                $level = 2;
            }
            if (($check eq "mailto") && ($level < 2)) {
                $preferred = $url;
                $level = 1;
            }
        }
    }
    $preferred =~ s/^\s*//;
    return $preferred;
}

1;
__END__


=head1 NAME

ROADS::PreferredURL - A class to extract the URL we prefer most

=head1 SYNOPSIS

  use ROADS::PreferredURL;
  # %TEMPLATE is a hash array we read in earlier...
  $like_this_best = preferredURL(%TEMPLATE);

=head1 DESCRIPTION

This class defines a mechanism for examining the URLs contained in a
template (loaded into a hash array which is keyed on attribute name),
and returned the most desirable one.

=head1 METHODS

=head2 $preferredURL = preferredURL(%HASH_ARRAY);

This method examines the template attributes encoded in I<HASH_ARRAY>
(keys are attribute names, values are attributes' values from
template), and discards all those which aren't URIs or URLs.  It sorts
the values of the remaining attributes according to a simple scheme
whereby :-

  http is preferred over
    gopher is preferred over
      ftp is preferred over
        telnet is preferred over
          wais is preferred over
            mailto

The preferred URL is then returned as a string.

=head1 SEE ALSO

L<bin/addsl.pl>, L<bin/addwn.pl>, L<bin/cullsl.pl>

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

