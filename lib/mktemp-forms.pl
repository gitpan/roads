#
# mktemp-forms.pl : Subroutines to output the various forms required by
#                   the mktemp.pl CGI script.
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: mktemp-forms.pl,v 1.11 1998/09/05 14:10:05 martin Exp $
#

#
# Subroutine to send an HTML FORM if there is no QUERY_STRING env var.
#
sub SendIntroForm {
    &OutputHTML("mktemp", "introform.html",$Language,$CharSet);
}  

#
# Subroutine to generate a FORM asking the user for the number of cluster
# and variant fields to be presented in a template.
#
sub sendsizeform { 
    local($displayed,$variants,$clusters) = 0;
    local($attributename,$attributetype) = "";
        
    # Open the appropriate template outline
    if (!open(OUTLINE,"$OutlineDir/$tt")) {
        &OutputHTML("mktemp", "notemplateoutline.html",$Language,$CharSet);
        &WriteToErrorLog("mktemp.pl",
			 "Can't open template outline $OutlineDir/$tt");
        exit(-1);
    }

    &WriteToErrorLog("mktemp.pl", "Opened $OutlineDir$tt OK...\n") if($debug);

    # If we're editing templates then we want the form to look a little
    # different.  Lets set up some variables with the alternate text in them.
    if($CGIvar{mode} eq "edit") {
        $additional = "<em>additional</em>";
        $default = 0;
    } else {
        $additional = "";
        $default = 1;
    }

    # Read all the lines from the template outline
    if(!$displayed) {
      &OutputHTML("mktemp", "clusterhead.html",$Language,$CharSet);
      $displayed = 1;
    }
    $hidden = "";
    while(<OUTLINE>) {
        &WriteToErrorLog("mktemp.pl", $_) if($debug);
        $line = $_;
        # It's got at least one variant field
        if (/([a-zA-Z\-]*)-v\*:/) {
             $attributename = $1;
             $variants = 1 if ((grep(/^$attributename/,@viewattr) != 0) 
              || ($CGIvar{view} eq "ALL"));
        }
        $_ = $line;
        if (/([a-zA-Z\-]*)-\(([a-zA-Z]*)\*\):/) {
            $attributename=$1;
            $attributetype=$2;
            if((grep(/^$attributename/,@viewattr) != 0) || 
              ($CGIvar{view} eq "ALL")) {
                print STDOUT "<A HREF=\"/$ROADS::WWWHtDocs/IAFA-help/$tt.html#$$attributename-($attributetype)\">";
                print STDOUT "$attributename-($attributetype) :</A>";
                $attributename =~ s/-//g;
                print STDOUT "<INPUT TYPE=\"text\" NAME=\"cluster$attributename\" ";
                print STDOUT "VALUE=\"$default\" SIZE=\"4\"><P>\n";
            } else {
                $attributename =~ s/-//g;
                print STDOUT "<INPUT TYPE=\"hidden\" NAME=\"cluster$attributename\" ";
                print STDOUT "VALUE=\"$default\" SIZE=\"4\">\n";
            }
        }
    }
    if($variants) {
        if(!$displayed) {
            &OutputHTML("mktemp", "variantsizeonlytop.html",$Language,$CharSet);
            print STDOUT $hidden;
            &OutputHTML("mktemp", "variantsizeonlybottom.html",$Language,$CharSet);
        } else {
            print STDOUT $hidden;
            &OutputHTML("mktemp", "clustervariantsize.html",$Language,$CharSet);
        }
        $displayed = 1;
   } elsif($displayed) {
        &OutputHTML("mktemp", "clusteronlybottom.html",$Language,$CharSet);
   }
   if ($displayed) {
        exit;
   }
}

1;
__END__


=head1 NAME

B<lib/mktemp-forms.pl> - return miscellaneous template editor HTML forms.

=head1 SYNOPSIS

  require "$ROADS::Lib/mktemp-forms.pl";
  &SendIntroForm;
  &sendsizeform;  

=head1 DESCRIPTION

This package implements routines for sending back miscellaneous HTML
forms to the end user.

=head1 METHODS

=head2 SendIntroForm;

This function returns the form I<introform> in the program call
I<mktemp>.

=head2 sendsizeform;

This function returns a form which is generated partly from the
customisable HTML in the I<mktemp> messages collection, with
additional HTML dynamically generated if necessary.  If the template
being edited already exists, and it is possible to add additional
clusters and/or variant elements, the HTML form returned will include
fields asking the user to choose how many (if any) additional clusters
of each type and/or variants they would like to add.

If the template is being created, the user will be prompted (if
applicable) for the number of clusters of each type and variants they
would like to include in it.

=head1 FILES

I<config/multilingual/*/mktemp/introform.html> - introductory form.

I<config/multilingual/*/mktemp/notemplateoutline.html> - returned
when no outline (schema) definition could be found for the template type
being edited could be found.

I<config/multilingual/*/mktemp/clusterhead.html> - the beginning of the
HTML document created when the template being edited contains clusters.

I<config/multilingual/*/mktemp/variantsizeonly.html> - HTML returned
when the template being edited contains variants but not clusters.

I<config/multilingual/*/mktemp/clustervariantsize.html> - HTML returned
when the template being edited contains both clusters and variants.

I<config/multilingual/*/mktemp/clusteronlybottom.html> - HTML returned
when the template being edited contains clusters but not variants.

I<config/outlines/*> - outline (schema) definitions of the available
templates.

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
