#
# mktemp-selectview.pl
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# Description: Subroutine to let the user select a view for editing the
#   template if a set of views exists.
#
# $Header: /home/roads2/lib/RCS/mktemp-selectview.pl,v 1.8 1998/09/05 13:59:29 martin Exp $
#

use ROADS::ReadTemplate;

sub SelectEditingView {
    print STDOUT "<EM>--Entering SelectEditingView<BR>\n" if($debug);
    print STDOUT "ViewDir = $ViewDir<BR>tt = $tt</EM><BR>\n" if($debug);

    if ($CGIvar{mode} eq "edit" && defined($CGIvar{originalhandle})) {
	%THISTEMP = &readtemplate($CGIvar{originalhandle});
	$tt = $THISTEMP{"Template-Type"};
	$tt =~ tr/[A-Z]/[a-z]/;
	$CGIvar{"templatetype"} = $tt;
    }

    if (-f "$ViewDir/$tt") {
        open(VIEW,"$ViewDir/$tt");
        $line = <VIEW>;
        while(!eof(VIEW)) {
            chomp $line;
            ($attr,$value)=split(":",$line,2);
            if($attr ne "Template-Type") {
                foreach $viewname (split(":",$value)) {
                    $views{$viewname} = 1;
                }
            }
            $line = <VIEW>;
        }
        close(VIEW);
        &OutputHTML("mktemp", "selectview.html",$Language,$CharSet);
        exit;
    } else {
        $CGIvar{view} = "ALL";
    }
}

1;
__END__


=head1 NAME

B<lib/mktemp-selectview.pl> - return available template editor views

=head1 SYNOPSIS

  require "$ROADS::Lib/mktemp-selectview.pl";
  &SelectEditingView;

=head1 DESCRIPTION

This package defines a function which returns a list of the available
template editing views for this particular template type.

=head1 METHODS

=head2 SelectEditingView;

This function uses the CGI variables I<originalhandle> and
I<templatetype> to determine the views which are available in addition
to the default "ALL" view which includes all attributes in the
template.

The list of views is stored in a global hash array I<views>, and a
page of HTML which may have these interpolated by variable
substitution.

=head1 FILES

I<config/mktemp-views/*> - the available views, see the B<mktemp.pl>
manual page for more information on the file format.

I<config/multilingual/*/mktemp/selectview.html> - the HTML form which
lets the template editor user select the editing view to use.

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
