#
# mktemp-lookupcluster.pl : Let the user look up a cluster for inclusion in
#                           another template.
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: mktemp-lookupcluster.pl,v 1.8 1999/05/04 15:57:37 jon Exp $
#

sub LookupCluster {
    local($type) = @_;

    # Output the top part of the form (probably some human readable blurb).
    &OutputHTML("mktemp","lookupclusterhead.html",$Language,$CharSet);

    # Generate the form itself, with loads of hidden fields for passing all
    # the contents of the partially completed template in.
    print STDOUT <<"HeadOfForm";
<FORM ACTION="/$ROADS::WWWAdminCgi/lookupcluster.pl" METHOD="POST">
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
      if ($TEMPLATE{RecordCreatedDate} && $TEMPLATE{RecordCreatedEmail}) { # ANH 1999-05-03
        $rcd = $TEMPLATE{RecordCreatedDate};    # ANH 1999-05-03
        $rce = $TEMPLATE{RecordCreatedEmail};   # ANH 1999-05-03
      } elsif ($CGIvar{IAFARecordCreatedDate} &&
             $CGIvar{IAFARecordCreatedEmail}) { # ANH 1999-05-03
        $rcd = $CGIvar{IAFARecordCreatedDate};  # ANH 1999-05-03
        $rce = $CGIvar{IAFARecordCreatedEmail}; # ANH 1999-05-03
      } else {                                  # ANH 1999-05-03
        $rcd = "eaten by a bug";                # ANH 1999-05-03
        $rce = "eaten by a bug";                # ANH 1999-05-03
      }                                         # ANH 1999-05-03

      $rce =~ s/\n//g;                          # ANH 1999-05-03
      $rcd =~ s/\n//g;                          # ANH 1999-05-03
      print STDOUT <<"HeadOfForm";
<INPUT TYPE="hidden" NAME="IAFARecordCreatedDate" VALUE="$rcd">
<INPUT TYPE="hidden" NAME="IAFARecordCreatedEmail" VALUE="$rce">
HeadOfForm
    }
    #
    # Output the plain fields of the template
    #
    if ($HavePlainFields == 1) {
        foreach $Field (@PlainFields) {
            $value = $PlainValues{$Field};
            $value =~ s/"/\0376/g;
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
                    $value =~ s/"/\0376/g;
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
                $value =~ s/"/\0376/g;
                $real = $RealFields{$Field};
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
    # bottom part of the form and any other human readable bits that have
    # been added.  Then exit.
    print STDOUT "<INPUT TYPE=\"hidden\" NAME=\"type\" VALUE=\"$type\">\n";
    &OutputHTML("mktemp","lookupclusterform.html",$Language,$CharSet);
    exit;
}

1;
__END__


=head1 NAME

B<lib/mktemp-lookupcluster.pl> - returns the template editor cluster search form

=head1 SYNOPSIS

  require "$ROADS::Lib/mktemp-lookupcluster.pl";
  &LookupCluster($type);

=head1 DESCRIPTION

This package implements a function which returns a cluster search form.

=head1 METHODS

=head2 LookupCluster( type );

This function creates a new HTML form which lets the template editor
end user search for a cluster to include in a template being
edited/created.  The attribute/value pairs from the in-progress
template are included as hidden fields so as to pass on state from the
previous stages in the editing process.

=head1 FILES

I<config/multilingual/*/mktemp/lookupclusterhead.html> - the beginning
of the HTML form which is returned.

I<config/multilingual/*/mktemp/lookupclusterform..html> - the end of
the HTML form returned.

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
