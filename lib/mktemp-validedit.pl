#
# mktemp-validedit.pl
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# Description: Routine to ensure that when the mktemp.pl editor is editing
#   an existing template, the template actually really does exist.
#
# $Id: mktemp-validedit.pl,v 1.8 1998/09/05 13:59:29 martin Exp $
#

#
# Subroutine to check to see that we have a valid template handle for an
# existing template
#
sub CheckValidTemplate {
    if($debug) {
        print STDOUT "<EM>--Entering CheckValidTemplate</EM><BR>\n";
        print STDOUT "<EM>[CGIvar{originalhandle} = $CGIvar{originalhandle}]</EM><BR>\n";
    }
    unless (open(ORIGTEMP,"$ROADS::Guts/alltemps")) {
        &OutputHTML("mktemp","notemplates.html",$Language,$CharSet);
        exit 1;
    }
    $done = 0;
    while(!eof(ORIGTEMP) && !$done) {
	$line = <ORIGTEMP>;
	($temphand,$filename)=split(" ",$line);
	if ($temphand eq $CGIvar{originalhandle}) {
            print STDOUT "<EM>Template = $temphand</EM><BR>\n" if($debug);
	    $done = 1;
        }
    }
    close(ORIGTEMP);
    # open up the template with the specified filename if a match was found,
    # nullifying the match if the file doesn't exist
    if($done) {    
        $filename = "$ROADS::IafaSource/$filename" unless $filename =~ /^\//;
        unless (open(ORIGTEMP,$filename)) {
            $done = 0;
        }
    }

    unless ($done) {
        &OutputHTML("mktemp","nonexistent.html",$Language,$CharSet);
        exit 1;
    }
    if($debug) {
        print STDOUT "<BR>--Leaving CheckValidTemplate<BR>\n";
    }
}

1;
__END__


=head1 NAME

B<lib/mktemp-validedit.pl> - Given a template handle, check the template exists

=head1 SYNOPSIS

  require "$ROADS::Lib/mktemp-validedit.pl";
  &CheckValidTemplate;

=head1 DESCRIPTION

This package defines a function I<CheckValidTemplate> which, given a
template handle, tries to find out whether it exists in the ROADS
database.

=head1 METHODS

=head2 CheckValidTemplate;

This function examines the CGI variable I<originalhandle> and tries to
open an existing template with this handle.  If unsuccessful it
returns a page of HTML to explain what went wrong.

=head1 FILES

I<config/multilingual/*/mktemp/notemplates.html> - HTML returned if
no template mappings file (alltemps)  could be found.

I<config/multilingual/*/mktemp/nonexistent.html> - HTML returned if
the template file itself couldn't be opened.

I<guts/alltemps> - default location of template handle to filename
mappings.

=head1 BUGS

We shouldn't be reading alltemps directly - should use the
ROADS::ReadTemplate abstractions instead.  Should also simply return
an error code if the template couldn't be found rather than bombing
out.

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
