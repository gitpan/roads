#
# mktemp-capture.pl
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# Description: Subroutine to capture the attributes and their values that
#   are present a submitted mktemp.pl editing form and also in a template
#   outline for the selected template.
#
# $Id: mktemp-capture.pl,v 2.17 1998/09/10 17:30:59 jon Exp $
#

#
# Subroutine to capture the fieldnames and values in the submitted form
# that correspond to fields in the outline template
#
sub DoField {
    local($line,$BaseName) = @_;

    local($CleanBaseName) = $BaseName;
    $CleanBaseName =~ s/\-//g;
    local($realfieldname,$fieldname,$Number,$index) = "";

    $_ = $line;
    if (/([a-zA-Z\-]*)-v\*/) {
        # Its a variant field
        $HaveVariantFields = 1;
        $fieldname=$1;
        $realfieldname = $fieldname;
        $realfieldname = "$BaseName$realfieldname" if ($InCluster >0);
	$fieldname =~ s/\-//g;
       	$fieldname = "$CleanBaseName$fieldname" if ($InCluster > 0);
        @VariantFields = (@VariantFields,$fieldname) if ($InCluster == 0);
        $Number = 1;
        while ($Number <= $CGIvar{"variantsize"}) { 
            if (($CGIvar{mode} ne "edit") && ($CGIvar{done} ne "yes")
              && ($CGIvar{partdone} eq "yes")){
                $value=$defaultvalue;
            } else {
                $key = "IAFA$fieldname$Number";
                eval "\$value=\$CGIvar{$key}";
                $value =~ s/[\x0A\x0D]+$/ /;
                $value =~ s/\r//g;
		$value =~ s/\0376/"/g;
            }
	    $index="$fieldname$Number";
            $XSize{$index}=$xsize;
            $YSize{$index}=$ysize;
            if(($optional eq "m") && ($value=~/^[\n\r\s]*$/)) {
                $FailedMandatoryTest = 1;
                @MissingMandatory=(@MissingMandatory,"$BaseName$realfieldname-v$Number");
            }
#            &WriteField("$BaseName$realfieldname-v$Number",$value) if ($CGIvar{done} eq "yes");
            if (($CGIvar{done} eq "yes") && ($partdone != 1)) {
              $value =~ s/\n\n/\n/g;
              $value =~ s/\n([^ ].)/\n  \1/g;
              $value =~ s/\0376/"/g;
              print NEWTEMP "$BaseName$realfieldname-v$Number: $value\n" 
            } else {
              $value =~ s/\n  /\n/g;
              $value =~ s/\0376/"/g;
            }
	    if ($InCluster > 0) {
                $ClusterElements{$CleanBaseName} = join(",",$ClusterElements{$CleanBaseName},$index);
                $ClusterValue{$index} = $value;
                $DefaultValues{$index} = $defaultvalue;
                $MaxClusterVariants{$CleanBaseName}=$Number if ($Number > $MaxClusterVariants{$CleanBaseName});
            } else {
                $VariantValue{$index} = $value;
                $DefaultValues{$index} = $defaultvalue;
                $MaxVariants=$Number if ($Number > $MaxVariants);
            }
            $Number++;
        }
        $RealFields{$fieldname} = $realfieldname;
    } elsif (/([a-zA-Z\-]*)-\(([a-zA-Z]*)\*\)/) {
        # Its a cluster field
        $HaveClusters = 1;
        $fieldname = $1;
        $clustername = $2;
        $realfieldname = $fieldname;
        $RealFields{$fieldname} = "$BaseName$realfieldname";
	$fieldname =~ s/-//g;
	$fieldname = "$CleanBaseName$fieldname";
        $clustername =~ y/A-Z/a-z/;
        open(CLUSTER,"$OutlineDir/$clustername") || 
          &WriteToErrorLogAndDie("$0", 
            "Can't open $OutlineDir/$clustername");
        <CLUSTER>;
        while(/Template-type:/i) {
            <CLUSTER>;
        }
        $ClusterTypes{$fieldname}=$clustername;
        @ClusterFields = (@ClusterFields,$fieldname) if ($InCluster == 0);
        $InCluster++;
        local($input);
        while(!eof(CLUSTER)) {
            $input = <CLUSTER>;
            chomp $input;
            ($fieldname,$xsize,$ysize,$defaultvalue,$optional) = split(/:/,$input);
            if ($xsize eq "") {
                $xsize = 45;
            }
            if ($ysize eq "") {
                $ysize = 1;
            }
            &DoField($fieldname,"$realfieldname\-");
        }
        $InCluster--;
        close(CLUSTER);
    } else {
        # Its a plain field
        $HavePlainFields = 1;
        $fieldname=$line;
        $fieldname=~s/:$//;
        $realfieldname = $fieldname;
	$fieldname =~ s/\-//g;
        if ($InCluster > 0) {
            if($ClusterElements{$CleanBaseName} eq "") {
                $ClusterElements{$CleanBaseName} = $fieldname;
                $RealClusterElements{$CleanBaseName} = $realfieldname;
            } else {
                $ClusterElements{$CleanBaseName} = "$ClusterElements{$CleanBaseName},$fieldname";
                $RealClusterElements{$CleanBaseName} = "$RealClusterElements{$CleanBaseName},$realfieldname";
            }
            $Number = 1;
            while ($Number <= $CGIvar{"cluster$CleanBaseName"}) { 
                if (($CGIvar{mode} ne "edit") && ($CGIvar{done} ne "yes") 
                  && ($CGIvar{partdone} eq "yes")) {
                    $value=$defaultvalue;
                } else {
                    $key = "IAFA$CleanBaseName$fieldname$Number";
                    eval "\$value=\$CGIvar{$key}";
                    $value =~ s/[\x0A\x0D]+$/ /;
                    $value =~ s/\r//g;
                    $value =~ s/\0376/"/g;
                }
                $index = "$CleanBaseName$fieldname$Number";
                $XSize{$index}=$xsize;
                $YSize{$index}=$ysize;
                if(($optional eq "m") && ($value=~/^[\n\r\s]*$/)) {
                    $FailedMandatoryTest = 1;
                    @MissingMandatory=(@MissingMandatory,"$BaseName$realfieldname\-v$Number");
                }
                $DefaultValues{$index} = $defaultvalue;
                $MaxClusterVariants{$CleanBaseName}=$Number if ($Number > $MaxClusterVariants{$CleanBaseName});
#                &WriteField("$BaseName$realfieldname\-v$Number",$value) if ($CGIvar{done} eq "yes");
                if (($CGIvar{done} eq "yes") && ($partdone != 1)) {
                  $value =~ s/\n\n/\n/g;
                  $value =~ s/\n([^ ].)/\n  \1/g;
                  $value =~ s/\0376/"/g;
                  print NEWTEMP "$BaseName$realfieldname-v$Number: $value\n"
                } else {
                  $value =~ s/\n  /\n/g;
                  $value =~ s/\0376/"/g;
                }
                $ClusterValue{$index} = $value;
                $Number++;
            }
            if ($Number == 1) {
                $index = "$CleanBaseName$fieldname$Number";
                $ClusterValue{$index} = "";
                $MaxClusterVariants{$CleanBaseName}=$Number if ($Number > $MaxClusterVariants{$CleanBaseName});
#                &WriteField("$BaseName$realfieldname\-v$Number","") if ($CGIvar{done} eq "yes");
                print NEWTEMP "$BaseName$realfieldname-v$Number: \n"
                  if (($CGIvar{done} eq "yes") && ($partdone != 1));
            }
        } else {
            if (($CGIvar{mode} ne "edit") && ($CGIvar{done} ne "yes") 
              && ($CGIvar{partdone} eq "yes")) {
                $value=$defaultvalue;

                # Now for a hack.  We need to plop a date some time in
                # the future into the To-Be-Reviewed-Date attribute (which
                # the admin may wish to change of course).  We'll only do this
                # if the attribute is To-Be-Reviewed-Date AND the default
                # value is empty.
                if(($value eq "") && ($fieldname eq "ToBeReviewedDate")) {
                  $sinceepoch = time;
                  $sinceepoch += $ROADS::ToBeReviewedDate;
                  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdat) = 
                    gmtime($sinceepoch);
                  $year += 1900;
                  $day = (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];
                  $month = (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mon];
                  $value = sprintf ("%s, %2.2d %s %4.4d %2.2d:%2.2d:%2.2d +0000",
                  ($day,$mday,$month,$year,$hour,$min,$sec));
                }
                # And another hack for ADAM's Checked-By-Date attribute.
                if(($value eq "") && ($fieldname eq "CheckedByDate")) {
                  $sinceepoch = time;
                  $sinceepoch += $ROADS::CheckedByDate;
                  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdat) = 
                    gmtime($sinceepoch);
                  $year += 1900;
                  $day = (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];
                  $month = (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mon];
                  $value = sprintf ("%s, %2.2d %s %4.4d %2.2d:%2.2d:%2.2d +0000",
                  ($day,$mday,$month,$year,$hour,$min,$sec));
                }
            } else {
                $key = "IAFA$fieldname";
                eval "\$value=\$CGIvar{$key}";
                $value =~ s/[\x0A\x0D]+$/ /;
                $value =~ s/[\n\r]+$/ /g;
                $value =~ s/\r//g;
                $value =~ s/\0376/"/g;
            }
            if(($fieldname eq "Handle") && ($value=~/^[\n\r\s]*$/)) {
                $value = $Handle;
            }
            @PlainFields = (@PlainFields,$fieldname);
            $PlainValues{$fieldname} = $value;
            $DefaultValues{$fieldname} = $defaultvalue;
            $XSize{$fieldname}=$xsize;
            $YSize{$fieldname}=$ysize;
            if(($optional eq "m") && ($value=~/^[\n\r\s]*$/)) {
                $FailedMandatoryTest = 1;
                @MissingMandatory=(@MissingMandatory,"$BaseName$realfieldname");
            }
#            &WriteField("$BaseName$realfieldname",$value) if ($CGIvar{done} eq "yes");
            $value =~ s/\r//g;
            if (($CGIvar{done} eq "yes") && ($partdone != 1)) {
              $value =~ s/\n\n/\n/g;
              $value =~ s/\n([^ ].)/\n  \1/g;
              print NEWTEMP "$BaseName$realfieldname: $value\n"
            } else {
                $value =~ s/\n  /\n/g;
                $value =~ s/\0376/"/g;
            }
            $PlainValues{$fieldname} = $value;
        }
        $RealFields{$fieldname} = $realfieldname;
    }
}

1;
__END__


=head1 NAME

B<lib/mktemp-capture.pl> - capture attributes and values from a template edit

=head1 SYNOPSIS

  require "$ROADS::Lib/mktemp-authority.pl";
  &DoField($line, $BaseName);

=head1 DESCRIPTION

This package defines a function to capture the attributes and their
values that are present in a submitted B<mktemp.pl> editing form and
also in a template outline for the selected template.

=head1 METHODS

=head2 DoField( line, BaseName );

This function takes the template attributes and values from the form
which is currently being edited and writes them to what will in most
cases be a temporary file for use in the next step of the template
editing process - e.g. emailing, saving for batch update, and so on.

=head1 FILES

I<config/outlines/*> - outline (schema) definitions of the available
template types.

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
