# default.al - default ROADS ranking algorithm
# Original code by Martin Hamilton
# Modifications to allow autoloading by 
#  Tracy Gardner <t.a.gardner@ukoln.ac.uk>
# $Id: default.al,v 1.1 1999/07/29 14:41:16 martin Exp $

package ROADS::Rank;

# The default ROADS ranking algorithm

sub default {
    my ($query, @results) = @_;
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

1;

