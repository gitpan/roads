#
# ROADS::Rank - rank a list of WHOIS++ templates into order
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: Rank.pm,v 3.12 1998/09/05 13:58:57 martin Exp $

package ROADS::Rank;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(rank %TEMPLATE);

#
# To add your own plug-in ranking code, replace this module
#
sub rank {
    my ($query,@results) = @_;
    my ($fullhandle,$term,@terms,@ranked_results,$count,$key,%RANK,$line);

    $query =~ s/"//g;                       # zap quotes
    $query =~ tr/[A-Z]/[a-z]/;              # convert to lower case
    $query =~ s/\s+/ /g;                    # compress spaces down
    $query =~ s/:[^:]+$//;                  # zap global constraints
    $query =~ s/;[^\s]+\s/ /g;              # zap local constraints

    foreach $term (split (/\W/, $query)) {
	next if $term =~ /^(and|or|not)$/;  # skip booleans
	s/^[^=]+=(.*)/$1/;                  # zap attribute names
	next if grep(/^$term$/i, $::STOPLIST); # zap stoplisted terms
	push (@terms, $term);
    }

    foreach $fullhandle (@results) {
        $count = 0;
        foreach $line (split(/\n/, $::TEMPLATE{"$fullhandle"})) {
            next if $line =~ /^#/;
            if ($line =~ /^\s/) { s/\s[^:]+://; }    # zap attribute name
	    foreach $term (@terms) {
		$count += grep(/^$term/i,split(/\s+/,$line));
	    }
	}

        if ($RANK{$count}) {
            $RANK{$count} .= ",$fullhandle";
        } else { 
            $RANK{$count} = "$fullhandle";
        }
    }

    foreach $key (reverse (sort bynumber (keys %RANK))) {
        push(@ranked_results, (split/,/, $RANK{$key}));
    }

    return (@ranked_results);
}

sub bynumber {$a <=> $b;}

1;
__END__


=head1 NAME

ROADS::Rank - A class to rank WHOIS++ search results

=head1 SYNOPSIS

  use ROADS::Rank;
  # @results are the results of a WHOIS++ query done already
  @ranked_results = rank($query, @results);

=head1 DESCRIPTION

This class defines a mechanism for sorting the results of a WHOIS++
search according to the number of occurrences of the search terms in
the resulting templates.

=head1 METHODS

=head2 rank( query, @results );

This method takes an array of WHOIS++ template handles I<results>, and
the original search terms I<query> which gave rise to them.  It sorts
the handles according to the frequency of the search terms in the
templates which they point to, and returns the sorted list.

=head1 BUGS

We probably don't cope very well with some of the possible
permutations of search terms and punctuation.  Perhaps we should strip
them down to just alphanumerics before doing the comparison ?

=head1 SEE ALSO

L<admin-cgi/admin.pl>, L<cgi-bin/search.pl>

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

