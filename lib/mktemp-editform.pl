#
# Mktemp-editform.pl : The actual editing form for the template editor.
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: mktemp-editform.pl,v 1.31 1998/12/03 17:17:25 martin Exp $
#

sub editform {
    &OutputHTML("mktemp","editformhead.html",$Language,$CharSet);
    if ($HavePlainFields == 1) {
        print STDOUT "<UL><LI><A HREF=\"#plain\">Goto the Plain Fields</A></UL>\n";
    }
    if ($HaveClusters == 1) {
        print STDOUT "<UL><LI><A HREF=\"#clusters\">Goto the Clusters</A></UL>\n";
    }
    if ($HaveVariantFields == 1) {
        print STDOUT "<UL><LI><A HREF=\"#variants\">Goto the Variant Fields</A></UL>\n";
    }
    print STDOUT <<"HeadOfForm";
<FORM ACTION="$myurl" METHOD="POST">
<INPUT TYPE="hidden" NAME="templatetype" VALUE="$CGIvar{templatetype}">
<INPUT TYPE="hidden" NAME="view" VALUE="$CGIvar{view}">
<INPUT TYPE="hidden" NAME="mode" VALUE="$CGIvar{mode}">
<INPUT TYPE="hidden" NAME="originalhandle" VALUE="$CGIvar{originalhandle}">
<INPUT TYPE="hidden" NAME="language" VALUE="$CGIvar{language}">
<INPUT TYPE="hidden" NAME="charset" VALUE="$CGIvar{charset}">
<INPUT TYPE="hidden" NAME="asksize" VALUE="$CGIvar{asksize}">
<INPUT TYPE="hidden" NAME="partdone" VALUE="$CGIvar{partdone}">
HeadOfForm
    #
    # Output the hidden record creation/verification attributes
    #
    if($CGIvar{mode} eq "edit") {
	$TEMPLATE{RecordCreatedEmail} =~ s/\n//g;
        print STDOUT <<"HeadOfForm";
<INPUT TYPE="hidden" NAME="IAFARecordCreatedDate" VALUE="$TEMPLATE{RecordCreatedDate}">
<INPUT TYPE="hidden" NAME="IAFARecordCreatedEmail" VALUE="$TEMPLATE{RecordCreatedEmail}">
HeadOfForm
    }
    #
    # Output the plain fields of the template
    #
    $ROADS::WWWHtDocs = "" if($ROADS::WWWHtDocs eq "/");
    $DisplayedPlains = 0;
    if ($HavePlainFields == 1) {
        foreach $Field (@PlainFields) {
            $value = $PlainValues{$Field};
            $real = $RealFields{$Field};
            $default = $DefaultValues{$Field};
            $displayfield = 0;
            foreach $attr (@viewattr) {
                $attr =~ s/-v\*$/-v/;
                $attr =~ s/\(.*\)//;
                $attr =~ s/-//g;
                next if($attr eq "");
                $_ = $Field;
                if(/^$attr/i) { 
                    $displayfield = 1;
                    last;
                }
            }
            if(($CGIvar{view} eq "ALL") || ($displayfield == 1)) {
                if($DisplayedPlains == 0) {
                    print STDOUT "<HR><A NAME=\"plain\">\n<H1>Plain Fields</H1><TABLE>\n";
                    $DisplayedPlains = 1;
                }
                print "<TR><TD VALIGN=TOP><A HREF=\"/$ROADS::WWWHtDocs/IAFA-help/$tt.html#$real\">";
                printf STDOUT "%-25s:", $real;
                $tt = $CGIvar{templatetype};
                $tt =~ tr/A-Z/a-z/;
                if($default=~/\|/) {
                    print STDOUT "</A><TD VALIGN=TOP><SELECT SIZE=5 NAME=\"IAFA$Field\" MULTIPLE>\n";
                    if($value ne ""  && !($value =~ /\|/)) {
                        print STDOUT "<OPTION SELECTED>$value\n";
                    }
                    foreach $entry (split(/\|/,$default)) {
                        next if($entry eq $value);
                        print STDOUT "<OPTION>$entry\n";
                    }
                    print STDOUT "</SELECT>\n";
                } else {
                    $value =~ s/^\s*//;
 		    if ($YSize{$Field} == "1") {
 			print STDOUT <<EOF
</A><TD VALIGN=TOP><INPUT NAME="IAFA$Field" SIZE="$XSize{$Field}" VALUE="$value">
EOF
;
 		    } else {
 			print STDOUT <<EOF
</A><TD VALIGN=TOP><TEXTAREA NAME="IAFA$Field" ROWS="$YSize{$Field}" COLS="$XSize{$Field}">$value</TEXTAREA>
EOF
;
 		    }
		    $tt = $CGIvar{templatetype};
		    $tt =~ tr/A-Z/a-z/;
                    $authfile = "$ROADS::Config/authority/$tt/$real";
                    if(-f "$authfile") {
                         print STDOUT "<TR><TD VALIGN=TOP><TD VALIGN=TOP><INPUT TYPE=\"submit\" ";
                         print STDOUT "NAME=\"ROADSAuth$real\" ";
                         print STDOUT "VALUE=\"Authority File\">\n";
                    }
                }
                # See if there is a note field to output.
                if(&LangFileExists("mktemp-notes","$tt-$real",$Language,$CharSet)) {
                  &OutputHTML("mktemp-notes","$tt-$real",$Language,$CharSet);
	        } elsif(&LangFileExists("mktemp-notes","all-$real",$Language,$CharSet)) {
                  &OutputHTML("mktemp-notes","all-$real",$Language,$CharSet);
	        }
            } else {
                $value =~ s/^\s*//;
                if($value=~/\|/) {
                    ($value,$junk)=split(/\|/,$value,2);
                }
                # Now for a little fudge to ensure that double quotes in the
                # value don't inadvertently end the hidden attribute of the
                # HTML input element.
                $value =~ s/\"/\0376/g;
                print STDOUT "<INPUT TYPE=\"hidden\" NAME=\"IAFA$Field\" ";
                print STDOUT "VALUE=\"$value\">";
            }
        }
    }
    print STDOUT "</TABLE>\n";
    
    #
    # Output the clusters in the template
    #
    if ($HaveClusters == 1) {
        $DisplayedClusters = 0;
        foreach $Cluster (@ClusterFields) {
            $DisplayedThisCluster = 0;
            $Number = 1;
            local($index) = "";
            while ($Number <= $CGIvar{"cluster$Cluster"}) {
                $DisplayedThisInstance = 0;
                foreach $Element (split(/,/,$RealClusterElements{$Cluster})) {
                    $displayfield = 0;
                    foreach $attr (@viewattr) {
                        $attr =~ s/\*$//;
                        $attr =~ s/v$//;
                        $attr =~ s/\(.*\)//;
                        $attr =~ s/-//g;
                        next if($attr eq "");
                        $_ = "$Cluster$Element";
                        $_ =~ s/-//g;
                        if(/^$attr/i) {
                            $displayfield = 1;
                            last;
                        }
                    }
                    if(($CGIvar{view} eq "ALL") || ($displayfield == 1)) {
                        if($DisplayedClusters == 0) {
                            print STDOUT "<HR><A NAME=\"clusters\">\n<H1>Clusters</H1>\n<UL>\n";
                            $DisplayedClusters = 1;
                        }
                        if($DisplayedThisCluster == 0) {
                            print STDOUT "<LI><H2><A HREF=\"/$ROADS::WWWHtDocs/IAFA-help/$tt.html#$Cluster\">$Cluster</A></H2>\n";
                            $DisplayedThisCluster = 1;
                        }
                        if($DisplayedThisInstance == 0) {
                            print STDOUT "<H2>Instance $Number</H2>\n";
                            print STDOUT "<INPUT TYPE=\"submit\" NAME=\"";
                            print STDOUT "ROADSFind$Cluster$Number\" VALUE=\"";
                            print STDOUT "Search for cluster\"><BR>";
 
 			    print STDOUT "Insert cluster with handle:";
 			    print STDOUT "<INPUT NAME=\"ROADSAdd$Cluster-$Number\" VALUE=\"\"><BR><BR>";
 			    $DisplayedThisInstance = 1;
                            print STDOUT "<TABLE>\n";
                         }
 			unless ($Element eq "Handle"
				  || $Element eq "Template-Type") {
 			    print STDOUT "<TR><TD><A HREF=\"/$ROADS::WWWHtDocs/IAFA-help/$ClusterTypes{$Cluster}.html#$Element\">";
 			    printf STDOUT "%-25s:",$Element;
 			}
                        $AuthElement = $Element;
                        $Element =~ s/-//g;
                        $index = "$Cluster$Element$Number";
                        $value = $ClusterValue{$index};
                        $default = $DefaultValues{$index};
                        if($default=~/\|/) {
                            print STDOUT "</A><TD><SELECT SIZE=5 NAME=\"IAFA$Cluster$Element$Number\" MULTIPLE>\n";
                            if($value ne ""  && !($value =~ /\|/)) {
                                print STDOUT "<OPTION SELECTED>$value\n";
                            }
                            foreach $entry (split(/\|/,$default)) {
                                next if($entry eq $value);

                                print STDOUT "<OPTION>$entry\n";
                            }
                            print STDOUT "</SELECT>\n";
                        } else {
                            $ClusterValue{$index} =~ s/^\s*//;
 			    unless ($Element eq "Handle") {
 				if ($YSize{$index} == "1") {
 				    print STDOUT <<EOF
</A><TD><INPUT NAME="IAFA$Cluster$Element$Number" SIZE="$XSize{$index}" VALUE="$ClusterValue{$index}">
EOF
;
 				} else {
 				    print STDOUT <<EOF
</A><TD><TEXTAREA NAME="IAFA$Cluster$Element$Number" ROWS="$YSize{$index}" COLS="$XSize{$index}">$ClusterValue{$index}</TEXTAREA>
EOF
;
 				}
 			    }
                            $tt = $ClusterTypes{$Cluster};
                            $tt =~ tr/A-Z/a-z/;
                            $authfile = "$ROADS::Config/authority/$tt/$AuthElement";
                            if(-f "$authfile") {
                                print STDOUT "<INPUT TYPE=\"submit\" ";
                                print STDOUT "NAME=\"ROADSAuth$Cluster:$tt:$AuthElement:$Number\" ";
                                print STDOUT "VALUE=\"Authority File\">\n";
                            }
                        }
                        # See if there is a note field to output.
                        $tt = $CGIvar{templatetype};
                        $tt =~ tr/A-Z/a-z/;
                        if(&LangFileExists("mktemp-notes",
			    "$tt-$Cluster$Element",$Language,$CharSet)) {
                          &OutputHTML("mktemp-notes","$tt-$Cluster$Element",
				      $Language,$CharSet);
		        } elsif(&LangFileExists("mktemp-notes",
			    "all-$Cluster$Element",$Language,$CharSet)) {
			  &OutputHTML("mktemp-notes","all-$Cluster$Element",
				      $Language,$CharSet);
	                }
                    } else {
                        $Element =~ s/-//g;
                        $index = "$Cluster$Element$Number";
                        $value = $ClusterValue{$index};
                        if($value=~/\|/) {
                            ($value,$junk)=split(/\|/,$value,2);
                        }
                        # Now for a little fudge to ensure that any double
			# quotes in the value don't inadvertently end the
			# hidden attribute of the HTML input element. 
                        $value =~ s/\"/\0376/g;            
                        $value =~ s/^\s*//;
                        print STDOUT "<INPUT TYPE=\"hidden\" ";
                        print STDOUT "NAME=\"IAFA$Cluster$Element$Number\" ";
                        print STDOUT "VALUE=\"$value\">";
                    }
                }
                print STDOUT "</UL></TABLE>\n";
                $Number++;
            }
            print STDOUT "<INPUT TYPE=\"hidden\" NAME=\"cluster$Cluster\" ";
            $Element = $CGIvar{"cluster$Cluster"};
            print STDOUT "VALUE=\"$Element\">\n";

	    if($DisplayedClusters == 0) {
		print STDOUT "<HR><A NAME=\"clusters\">\n<H1>Clusters"
		    . "</H1>\n<UL>\n";
		$DisplayedClusters = 1;
	    }
	    print STDOUT "<INPUT TYPE=\"submit\" NAME=\"ROADScincr$Cluster\" ".
		"VALUE=\"Add a cluster of type: $Cluster\">";
	    print STDOUT "<INPUT TYPE=\"submit\" NAME=\"ROADScdecr$Cluster\" ".
		"VALUE=\"Remove last $Cluster cluster\">"
		    unless $Element == 0;
	    print STDOUT "\n";
        }
        print STDOUT "</TABLE></UL>\n";
    }
    
    #
    # Output the variant fields of the template
    #
    $DisplayedVariants = 0;
    if ($HaveVariantFields == 1) {
        $Variant = 1;
        while ($Variant <= $CGIvar{variantsize}) {
            $DisplayedThisVariant = 0;
            foreach $Field (@VariantFields) {
                $displayfield = 0;
                foreach $attr (@viewattr) {
                    $attr =~ s/v$//;
                    $attr =~ s/\*$//;
                    $attr =~ s/\(.*\)//;
                    $attr =~ s/-//g;
                    next if($attr eq "");
                    $_ = $Field;
                    if(/^$attr/i) {
                        $displayfield = 1;
                        last;
                    }
                }
                $index="$Field$Variant";
                $value = $VariantValue{$index};
                $default = $DefaultValues{$index};
                $real = $RealFields{$Field};
                if(($CGIvar{view} eq "ALL") || ($displayfield == 1)) {
                    if($DisplayedVariants == 0) {
                        print STDOUT "<HR><A NAME=\"variants\">\n<H1>Variant Fields</H1>\n<UL>\n";
                        $DisplayedVariants = 1;
                    }
                    if($DisplayedThisVariant == 0) {
                        print STDOUT "</TABLE><LI><H2>Variant $Variant</H2><TABLE>\n";
                        $DisplayedThisVariant = 1;
                    }
                    print STDOUT "<TR><TD><A HREF=\"/$ROADS::WWWHtDocs/IAFA-help/$tt.html#$real\">";
                    printf STDOUT "%-25s:", $real;
                    $tt = $CGIvar{templatetype};
                    $tt =~ tr/A-Z/a-z/;
                    if($default=~/\|/) {
                        print STDOUT "</A><TD><SELECT SIZE=5 NAME=\"IAFA$Field$Variant\" MULTIPLE>\n";
                        if($value ne ""  && !($value =~ /\|/)) {
                          print STDOUT "<OPTION SELECTED>$value\n";
                        }
                        foreach $entry (split(/\|/,$default)) {
                            next if ($entry eq $value);
                            print STDOUT "<OPTION>$entry\n";
                        }
                        print STDOUT "</SELECT>\n";
                    } else {
 			if ($YSize{$index} == 1) {
 			    print STDOUT <<EOF
</A><TD><INPUT NAME="IAFA$Field$Variant" SIZE="$XSize{$index}" VALUE="$value">
EOF
;
			} else {
			    print STDOUT <<EOF
</A><TD><TEXTAREA NAME="IAFA$Field$Variant" ROWS="$YSize{$index}" COLS="$XSize{$index}">$value</TEXTAREA>
EOF
;
 			}
			$tt = $CGIvar{templatetype};
			$tt =~ tr/A-Z/a-z/;
                        $authfile = "$ROADS::Config/authority/$tt/$real";
                        if (-f "$authfile") {
                            print STDOUT "<INPUT TYPE=\"submit\" ";
                            print STDOUT "NAME=\"ROADSAuth:$tt:$real:$Variant\" ";
                            print STDOUT "VALUE=\"Authority File\">\n";
                        }
                    }
                    # See if there is a note field to output.
                    if(&LangFileExists("mktemp-notes","$tt-$real",$Language,$CharSet)) {
                      &OutputHTML("mktemp-notes","$tt-$real",$Language,$CharSet);
                    } elsif(&LangFileExists("mktemp-notes","all-$real",$Language,$CharSet)) {
                      &OutputHTML("mktemp-notes","all-$real",$Language,$CharSet);
                    }
                } else {
                    if($value=~/\|/) {
                        ($value,$junk)=split(/\|/,$value,2);
                    }
                    # Now for a little fudge to ensure that any double quotes in the
                    # value don't inadvertently end the hidden attribute of the HTML
                    # input element. 
                    $value =~ s/\"/\0376/g;
                    $value =~ s/^\s*//;
                    print STDOUT "<INPUT TYPE=\"hidden\" ";
                    print STDOUT "NAME=\"IAFA$Field$Variant\" ";
                    print STDOUT "VALUE=\"$value\">";
                }
            }
            $Variant++;
        }
	print STDOUT "</TABLE>\n";
        print STDOUT "<INPUT TYPE=\"hidden\" NAME=\"variantsize\" ";
        print STDOUT "VALUE=\"$CGIvar{variantsize}\">\n</UL>\n";

	if($DisplayedVariants == 0) {
	    print STDOUT "</TABLE><HR><A NAME=\"variants\">\n<H1>Variant Fields"
		."</H1>\n<UL><TABLE>\n";
	    $DisplayedVariants = 1;
	}
        print STDOUT "<INPUT TYPE=\"submit\" NAME=\"ROADSincrvarsize\" ".
          "VALUE=\"Add a variant\">";
        print STDOUT "<INPUT TYPE=\"submit\" NAME=\"ROADSdecrvarsize\" ".
          "VALUE=\"Remove last variant\">" unless $CGIvar{variantsize} == 0;
	print STDOUT "\n";
    }

    &OutputHTML("mktemp","editformtail.html",$Language,$CharSet);
    exit;
}

1;
__END__;


=head1 NAME

B<lib/mktemp-editform.pl> - return the main template editor form

=head1 SYNOPSIS

  require "$ROADS::Lib/mktemp-editform.pl";
  &editform;

=head1 DESCRIPTION

This package implements a routine which returns the main ROADS
template editor form.

=head1 METHODS

=head2 editform;

This function returns the main ROADS template editor form, rendering
only those template fields which have been chosen in the CGI I<view>
variable, and including such context sensitive help, default values,
pick lists and authority files as have been defined.

The user has the option of adding additional clusters (of each type
represented in the template) and variants, or removing the last
variant of cluster of each type which has been entered.  In addition,
one can include a whole template as a cluster within another template,
or search for a template to include.

=head1 FILES

I<config/authority/*> - authority files, if applicable.

I<config/multilingual/*/mktemp/editformhead.html> - the beginning of
the HTML form.

I<config/multilingual/*/mktemp/editformtail.html> - the end of
the HTML form.

I<config/multilingual/*/mktemp-notes/*> - per template type/attribute
context sensitive help, if applicable.  Notes can be specific to a
particular template type and attribute combination by creating a file
say I<document-Keywords>, or applied to all instances of a
particular attribute name by creating a file (say) I<all-Keywords>

=head1 BUGS

The HTML produced by the editor is practically hard coded.  It would
be highly desirable to be able to control the rendering style used for
individual attributes.  This may be possible without too much pain
using CSS.

=head1 SEE ALSO

L<admin-cgi/mktemp.pl>

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
