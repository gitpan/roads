#
# ROADS::Expand - perform query expansion using simple "thesaurus"
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: Expand.pm,v 3.9 1998/09/05 13:58:57 martin Exp $

package ROADS::Expand;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(expand);

sub expand {
    my ($query) = @_;
    my ($term,$expansions);

    return($query) unless $expansionfile;

    unless (defined(%EXPAND)) {
        open(EXPAND, "$expansionfile")
          || &WriteToErrorLogAndDie("$0", 
               "Couldn't open expansion file $expansionfile: $!");
        while(<EXPAND>) {
            chomp;
            next if /^#/;
            ($term,$expansions) = split;
            $EXPAND{"$term"} = $expansions;
        } 
        close(EXPAND);
    }

    # may not yield anything sensible if the search is a phrase!
    foreach $term (keys %EXPAND) {
        next unless $query =~ /$term/i; # skip unless we find it

        if ($query =~ /^$term$/) {
            $term and $EXPAND{"$term"}/i;
        }

        # attribute/value pair
        $query =~ s/([^=]+)=$term$/$1=$term and $1=$EXPAND{"$term"}/i;

        $query =~ s/$term;(.*)/$term and $EXPAND{"$term"}/i;
    }
    return ($query);
}

1;
__END__


=head1 NAME

ROADS::Expand - A class to perform simple query expansions

=head1 SYNOPSIS

  use ROADS::Expand;
  $expanded_query = expand("color");

=head1 DESCRIPTION

This class defines a simple method to perform limited query expansion.
It is intended to cater for the small number of very common word
substitutions which typically cause problems with Internet searching,
e.g. the use of "colour" versus "color".

=head1 METHODS

=head2 expand( original_query_string );

This method takes the I<original_query_string> variable and performs
query expansion on it, returning the result as a string ready for
variable assignment.

=head1 FILES

I<config/expansions> - list of search terms and expansions, found
using the globally scoped variable I<expansionfile> or pre-initialized
into the hash array EXPAND.

=head1 FILE FORMAT

Each line of the file consists of a term, e.g. "colour", and its
expansions, separated by whitespace, e.g.

  colour color

=head1 BUGS

Now that we have WGI based thesaurus lookup, this seems anachronistic.
Should we make it capable of using a DB(M) lookup, or perhaps junk it?

=head1 SEE ALSO

L<bin/wppd.pl>, L<ROADS::Index>

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

