#
# ROADS::LookupRender - render WHOIS++ template into HTML
# 
# Authors: Jon Knight <jon@net.lut.ac.uk>
#          Martin Hamilton <martinh@gnu.org>
# $Id: LookupRender.pm,v 3.11 1998/09/05 13:58:57 martin Exp $

package ROADS::LookupRender;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(methodcheck lookuprender);

use ROADS::ErrorLogging;
use ROADS::HTMLOut;

#
# Subroutine to check whether we have a correct URL method in the match
#
sub methodcheck {
    my ($check) = @_;

    if($CGIvar{method} eq "any") {
        return 1;
    } else {
        if (index($CGIvar{method},$check) != -1 ) {
            return 1;
        }
    }
    return 0;
}


#
# Subroutine to display full template matches
#
sub lookuprender {
    my ($query,$view,@ranked_results) = @_;
    my (@SUBS,%URI,$rule,$fullhandle,$attrib,$sub,$default,$line);
    my (@terms,$term,$protocol,$write,$wrote,$rhs,$for_each,$this_attrib);

    print "[<EM>render called with query '$query', view '$view' and "
      . "#ranked_results: $#ranked_results</EM>]\n" if $debug;

    $ct = $ClusterType;
    $ct =~ tr/A-Z/a-z/;
    $view = "$view/$ct";
    open (VIEW, "$view")
	|| &WriteToErrorLogAndDie($0, "couldn't open view $view: $!");
    while(<VIEW>) {
	last if m!<RESULTS>!;
	s/<QUERY>/$query/g;
	s/<ROADSSERVICENAME>/$ROADS::ServiceName/g;
	s/<MYURL>/http:\/\/$ROADS::MyHostname:$ROADS::MyPortNumber\//g;
	print ;
    }

    # hit the <RESULTS> section by now, hopefully...
    while(<VIEW>) {
	chomp;
	last if m!</RESULTS>!;
	push (@SUBS, $_);
    }

    foreach $term (split(/\W/, $query)) {
	next if $term =~ /^(and|or|not)$/;
	s/^[^=]+=(.*)/$1/;
	push (@terms,$term);
    }

    # hit the end of the <RESULTS> section and loaded any substitution
    # patterns into the $SUBS array
    foreach $fullhandle (@ranked_results) {
	print "its... <<$TEMPLATE{\"$fullhandle\"}>>\n" if $debug;
        $drop = 0;
        foreach $line (split(/\n/, $TEMPLATE{"$fullhandle"})) {
            if($line =~ /^# FULL ([A-Za-z]+)/) {
                if($1=~/$ClusterType/i) {
                    $drop = 1;
                }
            }
        }
        next if ($drop == 0);

	foreach $rule (@SUBS) {

	    unless ($rule =~ m!\<\@!) { # no subs needed at all
		print "$rule\n";
		next;
	    }

            $for_each_default = "Not supplied";
 	    if ($rule =~ /^<FOREACH/i) { # record loop info
 		$for_each = "yes";
 		if ($rule =~ /^<FOREACH\s+"([^"]+)">/i) {
                     $for_each_default = $1;
                     $rule =~ s/^<FOREACH\s+"([^"]+)">\s+//i;
                }
 		$rule =~ s/^<FOREACH>\s+//i;
 	    }
	    if ($rule =~ /(.*)\<\@([^\s]+)\s+"([^"]+)"\>(.*)/) {
                $first = $1;
    		$attrib = $2;
                $default = $3;
                $last = $4;
    	    } elsif ($rule =~ /(.*)\<\@([^>]+)\>(.*)/) {
                $first = $1;
		$attrib = $2;
                $default = "Not supplied";
                $last = $3;
	    } else {
                next;
            }
            $wrote = "no";

            if ($attrib =~ /UR[IL]/i) { # required to sort these.  blech!
                undef (%URI);
                foreach $line (split(/\n/, $TEMPLATE{"$fullhandle"})) {
                    next unless $line =~ /^ $attrib:\s+(.*)/i;
                    $rhs = $1 || $default;
                    $write = $first . $rhs . $last;
                    $write =~ s/\<\@$attrib\>/$rhs/g;

                    if ($rhs =~ /^(http|gopher|ftp|telnet|wais|mailto):/) {
                        $protocol = $1;
                        $protocol =~ tr/[A-Z]/[a-z]/;
                    } else {
                        $protocol = "other";
                    }

                    if ($URI{"$protocol"}) {
                        $URI{"$protocol"} .= "\n$write";
                    } else {
                        $URI{"$protocol"} = "$write";
                    }
                }

                foreach $protocol ("http", "gopher", "ftp", "telnet",
                                   "wais", "mailto", "other") {
                    if ($URI{"$protocol"}) {
                        if ($override{"$protocol"}) {
                            $*=1;
                            $URI{"$protocol"} =~ 
                                s/HREF="([^:]+):/HREF="$waylay?url=/gi;
                            $*=0;
                        }
                        if ($for_each eq "yes") {
                            print "$URI{\"$protocol\"}\n";
                        } else {
                            last if ($wrote eq "yes");
                            $*=1; $URI{$protocol} =~ s/\n.*//; $*=0;
                            print "$URI{\"$protocol\"}\n";
                        }
                        $wrote = "yes";
                    }
		    last unless $for_each eq "yes";
                }

                print "$default\n" if $wrote eq "no";
                next;
            }

            foreach $line (split(/\n/, $TEMPLATE{"$fullhandle"})) {
	        next unless $line =~ /^ $attrib:\s+(.*)/i;
                $rhs = $1 || $default;
		foreach $term (@terms) {
		    if ($caseful) {
			$rhs =~ s/([ >])($term)/$1<B>$2<\/B>/g;
		    } else {
			$rhs =~ s/([ >])($term)/$1<B>$2<\/B>/gi;
		    }
		}

                $write = $first . $rhs . $last;
                $write =~ s/\<\@$attrib\>/$rhs/g;
		print "$write\n";
		$wrote = "yes";
	        last unless $for_each eq "yes";
            }
            print "$default\n" if $wrote eq "no";

            if ($for_each eq "yes" && $wrote eq "no") {
 	        print "$for_each_default\n";
	        next;
	    }
        }

        # Output the form to let the use choose to use this cluster.
        # First we output the unaffected CGI variables.
        print "<FORM ACTION=\"$editorurl\" METHOD=\"POST\">\n";
        foreach $key (keys %::CGIvar) {
            next if($key =~ /^IAFA$ClusterName[A-Za-z]*$ClusterNumber/);
            print "<INPUT TYPE=\"hidden\" NAME=\"$key\" ";
            print "VALUE=\"$CGIvar{$key}\">\n";
        }

        print "<BR>---------------<BR>\n" if($debug);

        # Now output the data for the new cluster
        $tt=$ClusterType;
        $tt=~tr/A-Z/a-z/;
        if (!open(OUTLINE,"$OutlineDir/$tt")) {
            &OutputHTML("mktemp","notemplateoutline.html",$Language,$CharSet);
            &WriteToErrorLogAndDie($0,
              "Can't open template outline $OutlineDir/$tt");
        }
        <OUTLINE>;
        while(/Template-type:/i) {
            <OUTLINE>;
        }

        while(!eof(OUTLINE)) {
            $line = <OUTLINE>;
            chomp $line;
            ($fieldname,$xsize,$ysize,$defaultvalue,$optional) 
              = split(/:/,$line);
            print "fieldname = '$fieldname'<BR>\n" if ($debug);
            $value = "";
            foreach $line (split(/\n/, $TEMPLATE{"$fullhandle"})) {
                print "line = $line<BR>\n" if ($debug);
                if($line =~ /^ ($fieldname):(.*)/i) {
                    $value = $2;
                    last;
                }
            }
            $fieldname =~ s/-//g;
            print "<INPUT TYPE=\"hidden\" ";
            print "NAME=\"IAFA$ClusterName$fieldname$ClusterNumber\" ";
            print "VALUE=\"$value\">\n";
        }
        close(OUTLINE);
        
        print "<BR><INPUT TYPE=\"submit\"></FORM>\n";
        $clustersshown++;
    }

    if($clustersshown == 0) {
        print "<P>No hits</P>\n";
    }
    while(<VIEW>) {
	s/<QUERY>/$query/g;
	s/<ROADSSERVICENAME>/$ROADS::ServiceName/g;
	s/<MYURL>/http:\/\/$ROADS::MyHostname:$ROADS::MyPortNumber\//g;
	print ;
    }
    close(VIEW);
}

1;
__END__


=head1 NAME

ROADS::LookupRender - A class to render HTML resulting from a cluster lookup

=head1 SYNOPSIS

  use ROADS::LookupRender;
  # Do a WHOIS++ search or three, then ...
  lookuprender($query, $view, @results);

=head1 DESCRIPTION

This class defines a mechanism for rendering WHOIS++ templates as HTML
- or other formats, though HTML is the primary goal.

=head1 METHODS

=head2 lookuprender( query, view, @results );

=over 4

=item I<query>

The WHOIS++ query which generated these results.

=item I<view>

The view to use when rendering the results - many of the ROADS tools
which generate HTML support multiple versions or 'views' of the same
data using different HTML rendering rules.

=item I<results>

This is a list of results in the format produced by the B<wppd> code
in the B<ROADS::WPPC> class.

=back

=head1 FILES

I<config/multilingual/*/mktemp/notemplateoutline.html> -
if no template outline (schema definition) could be found.

I<config/lookupcluster-views/*> - directory containing HTML rendering
rules for each cluster type.

=head1 BUGS

We're not using the generic HTML rendering code for this, but we
should be.

=head1 SEE ALSO

L<admin-cgi/mktemp.pl>.

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

