#
# mktemp-authority.pl : Let the user look up an attribute value in an 
#                       authority file listing.
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: mktemp-authority.pl,v 1.11 1998/09/05 13:59:29 martin Exp $
#

sub AuthorityLookup {
    local($type) = @_;

    # Output the top part of the form (probably some human readable blurb).
    &OutputHTML("mktemp","authlookuphead.html",$Language,$CharSet);

    # Generate the form itself, with loads of hidden fields for passing all
    # the contents of the partially completed template in.
    print STDOUT <<"HeadOfForm";
<FORM ACTION="/$ROADS::WWWAdminCgi/mktemp.pl" METHOD="POST">
<INPUT TYPE="hidden" NAME="templatetype" VALUE="$CGIvar{templatetype}">
<INPUT TYPE="hidden" NAME="view" VALUE="$CGIvar{view}">
<INPUT TYPE="hidden" NAME="op" VALUE="$CGIvar{op}">
<INPUT TYPE="hidden" NAME="mode" VALUE="$CGIvar{mode}">
<INPUT TYPE="hidden" NAME="originalhandle" VALUE="$CGIvar{originalhandle}">
<INPUT TYPE="hidden" NAME="language" VALUE="$CGIvar{language}">
<INPUT TYPE="hidden" NAME="charset" VALUE="$CGIvar{charset}">
<INPUT TYPE="hidden" NAME="asksize" VALUE="$CGIvar{asksize}">
<INPUT TYPE="hidden" NAME="partdone" VALUE="true">
HeadOfForm
    #
    # Output the hidden record creation/verification attributes
    #
    if($CGIvar{mode} eq "edit") {
        print STDOUT <<"HeadOfForm";
<INPUT TYPE="hidden" NAME="IAFARecordCreatedDate" VALUE="$TEMPLATE{RecordCreatedDate}">
<INPUT TYPE="hidden" NAME="IAFARecordCreatedEmail" VALUE="$TEMPLATE{RecordCreatedEmail}">
HeadOfForm
    }
    #
    # Output the plain fields of the template
    #
    if ($HavePlainFields == 1) {
        foreach $Field (@PlainFields) {
            $value = $PlainValues{$Field};
            # Now for a little fudge to ensure that any double quotes in
            # value don't inadvertently end the hidden attribute of the HTML
            # input element.
            $value =~ s/\"/\0376/g;
            $real = $RealFields{$Field};
            print STDOUT "<INPUT TYPE=\"hidden\" NAME=\"IAFA$Field\" ";
            print STDOUT "VALUE=\"$value\">\n";
        }
    }
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
                    $Element =~ s/-//g;
                    $index = "$Cluster$Element$Number";
                    $value = $ClusterValue{$index};
                    # Now for a little fudge to ensure that any double quotes 
                    # in the value don't inadvertently end the hidden 
                    # attribute of the HTML input element.
                    $value =~ s/\"/\0376/g;
                    print STDOUT "<INPUT TYPE=\"hidden\" ";
                    print STDOUT "NAME=\"IAFA$Cluster$Element$Number\" ";
                    print STDOUT "VALUE=\"$value\">\n";
                }
                $Number++;
            }
            print STDOUT "<INPUT TYPE=\"hidden\" NAME=\"cluster$Cluster\" ";
            $Element = $CGIvar{"cluster$Cluster"};
            print STDOUT "VALUE=\"$Element\">\n";
        }
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
                $index="$Field$Variant";
                $value = $VariantValue{$index};
                $real = $RealFields{$Field};
                # Now for a little fudge to ensure that any double quotes 
                # in the value don't inadvertently end the hidden 
                # attribute of the HTML input element.
                $value =~ s/\"/\0376/g;
                print STDOUT "<INPUT TYPE=\"hidden\" ";
                print STDOUT "NAME=\"IAFA$Field$Variant\" ";
                print STDOUT "VALUE=\"$value\">\n";
            }
            $Variant++;
        }
        print STDOUT "<INPUT TYPE=\"hidden\" NAME=\"variantsize\" ";
        print STDOUT "VALUE=\"$CGIvar{variantsize}\">\n";
    }

    # Output the type of cluster being searched for and then output the
    # any other human readable bits that have been added.  Then exit.
    print STDOUT "<INPUT TYPE=\"hidden\" NAME=\"type\" VALUE=\"$type\">\n";
    
    $tt = $CGIvar{templatetype};
    $tt =~ tr/A-Z/a-z/;
    $cluster = $instance = "";
    if($type =~ /:/) {
        ($cluster,$tt,$type,$instance)=split(':',$type);
    }
    $authfile = "$ROADS::Config/authority/$tt/$type";
    if(!(open(AUTHFILE,"$authfile"))) {
        print STDOUT "Oops!  No authority file<BR>\n";
    } else {
	$type =~ s/-//;
        while(<AUTHFILE>) {
            chomp;
            next if /^#/;
            next if /^$/;
            print STDOUT "<INPUT TYPE=\"checkbox\" ";
            print STDOUT "NAME=\"IAFA$cluster$type$instance\" VALUE=\"$_\">$_<BR>\n";
        }
        close(AUTHFILE);
        print STDOUT
	    "<INPUT TYPE=\"submit\" VALUE=\"Use selected values\"><BR>\n";
    }

    &OutputHTML("mktemp","authlookupform.html",$Language,$CharSet);
    exit;
}

1;
__END__


=head1 NAME

B<lib/mktemp-authority.pl> - Template editor authority file lookups

=head1 SYNOPSIS

  require "$ROADS::Lib/mktemp-authority.pl";
  &AuthorityLookup($cluster,$tt,$type,$instance);

=head1 DESCRIPTION

This package implements a routine which returns an HTML rendered
version of the authority file for a given template type and element.

=head1 METHODS

=head2 AuthorityLookup( type );

This function renders a page of HTML to STDOUT containing the
authority file choices for the given template type and attribute.  If
it contains one or more colon ":" characters, the I<type> parameter is
expanded to :-

=over 4

=item I<cluster>

The cluster being edited.

=item I<tt>

The template type being edited, e.g. B<DOCUMENT>.

=item I<type>

The attribute type being controlled by the authority file,
e.g. B<Keywords>.

=item I<instance>

The particular instance of this attribute type being edited.

=back

=head1 FILES

I<config/authority/*> - default location for the authority files.
There are subdirectories for each template type and a separate file
for each attribute.  The files themselves consist of a line for each
possible value of the attribute being controlled by the authority
file.

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
