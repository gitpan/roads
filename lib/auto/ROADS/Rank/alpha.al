# alpha.al - Sort alphabetically 
# Tracy Gardner <t.a.gardner@ukoln.ac.uk>
# $Id: alpha.al,v 1.1 1999/07/29 14:41:16 martin Exp $

# Invoked by Rank.pm 
# To use this algorithm to rank results alphabetically by title
# the CGI variable rankingalg should be set to 'alpha:title' on the
# search page.
# The attribute can be varied, e.g. 'alpha:description'. 

use lib "/opt/metadata/roads/qualityranking/lib"; 

package ROADS::Rank;

sub alpha {
    my ($query, $attrib, @results) = @_;
    my ($fullhandle,$line, %titles, @ranked_results);

    RESULT: foreach $fullhandle (@results) {
	$titles{$fullhandle} = "";

        foreach $line (split(/\n/, $::TEMPLATE{"$fullhandle"})) {
             if ($line =~ /^\s*$attrib:(.*)/i) 
	     { 
		 $titles{$fullhandle} = $1;
		 next RESULT;
	     }    
	 }
    }
	
    # results without a value for $attrib should appear last
    @ranked_results =  reverse(sort { lc($titles{$b}) cmp lc($titles{$a}) } 
                            keys %titles); 

    return (@ranked_results);
}

1;

