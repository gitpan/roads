#
# ROADS::Rank - Autoloader for ROADS ranking algorithms
#
# Author: Tracy Gardner <t.a.gardner@ukoln.ac.uk>
#
# $Id: Rank.pm,v 3.13 1999/07/29 14:40:39 martin Exp $

package ROADS::Rank;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(rank);

use ROADS::CGIvars;

use AutoLoader 'AUTOLOAD'; # Ranking routines are autoloaded by name
                           # new ones can be added and picked up on the
                           # fly

# Note: Selection of ranking algorithm is based on the CGIvar 
# rankingalg 

$debug =  $CGIvar{debug};
 
sub rank
# Call this routine with a query and the results array to get default
# behaviour. 
# To invoke an alternative ranking algorithm pass in a reference to 
# an array in which the first element is the name of the ranking algorithm
# (as it appears in the rankingalgs hash above, the remaining elements
# can be any arguments required by your algorithm. Again, the second
# argument is the results array to be ranked.  
{
    my ($query, @results) = @_;

    my $rankinginfo = $CGIvar{rankingalg}; 
    $rankinginfo =~ tr /[A-Za-z0-9:]//dc; # make parameter safe
    unless($rankinginfo){ $rankinginfo = 'default'; };

    print "ranking: $rankinginfo <BR>\n" if $debug; 

    my ($rankingalg, $rankingargs); 

    if($rankinginfo =~ /([^:]*):(.*)/)
    {
	$rankingalg = $1; 
	$rankingargs = $2; 

	print "extended ranking: $rankingalg - $rankingargs<BR>\n" if $debug; 
 
	return (&$rankingalg($query, $rankingargs, @results)); 
    }    
    else
    # Ranking algorithm takes no additional arguments
    {
	return (&$rankinginfo($query, @results)); 
    }
}

sub bynumber {$a <=> $b;}


1;
__END__


=head1 NAME

ROADS::Rank - Autoloader for ROADS ranking algorithms

=head1 SYNOPSIS

  use ROADS::Rank;
  # @results are the results of a WHOIS++ query done already
  @ranked_results = rank($query, @results);

=head1 DESCRIPTION

This class provides a mechanism for autoloading ranking algorithms
depending on the information in $CGIvar{rankingalg} (intended to be
set by the search form). This variable should contain the name of the
ranking algorithm (used to autoload the routine) and any further
information that should be passed to the routine separated by a colon,
the colon may be omitted if no further information is
required. E.g. alphabetic or quality:totalimgsize. The original ROADS
ranking algorithm has the name 'default' and will be used if no
ranking algorithm is specified.

=head1 METHODS

=head2 rank( query, @results );

This method takes an array of WHOIS++ template handles I<results>, and
the original search terms I<query> which gave rise to them.  It
invokes the appropriate search routine and returns the sorted list.

=head1 SEE ALSO

L<admin-cgi/admin.pl>, L<cgi-bin/search.pl>, L<lib/auto/ROADS/Rank/default.al>

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

It was developed by UKOLN as part of the DESIRE project. DESIRE is
funded under the EU's Telematics Application Programme.

=head1 AUTHOR

Tracy Gardner E<lt>t.a.gardner@ukoln.ac.ukE<gt>

