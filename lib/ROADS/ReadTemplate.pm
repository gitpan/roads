#
# ROADS::ReadTemplate - read template from file and cache in array
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: ReadTemplate.pm,v 3.11 1998/09/05 13:58:57 martin Exp $

package ROADS::ReadTemplate;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(readalltemps readtemplate %TEMPLATE %ALLTEMPS);

use ROADS::ErrorLogging;

# Subroutine to read in template handle to filename mappings and
# store in associative array ALLTEMPS
#
sub readalltemps {
    local($filename);
    my($noth,$notf);

    $filename = "$ROADS::Guts/alltemps"
	unless (defined($filename) && -s "$filename");

    unless (open(ALLTEMPS, "$filename")) {
	&WriteToErrorLogAndDie("$0",
			       "couldn't open ALLTEMPS file $filename: $!");
    }

    while(<ALLTEMPS>) {
	chomp;
	s/\s+/ /g; s/^\s//; s/\s$//;
	($noth,$notf) = (split(" ",$_));
	$ALLTEMPS{"$noth"} = $notf;
    }
    close(ALLTEMPS);
    return %ALLTEMPS;
}

# Subroutine to read in a particular template from a file given the handle
# and the filename.  Returns the template in the associative array TEMPLATE.
#
sub readtemplate {
    local($handle,$filename) = @_;

    # Use template handle/filename mappings if filename not provided
    unless (defined($filename)) {
	if (defined(%ALLTEMPS)) {
	    $filename = $ALLTEMPS{"$handle"};
	} else {
	    %ALLTEMPS = &readalltemps;
	    $filename = $ALLTEMPS{"$handle"};
	}
    }

    $filename = "$ROADS::IafaSource/$filename" unless $filename =~ m!^/!;

    undef %TEMPLATE;
    close(MATCH);
    open(MATCH,$filename) || return %TEMPLATE;

    $current_type = "";
    while (<MATCH>) {
	chomp;
        $line = $_;
        if (/^\n$/ || eof(MATCH)) {
            $TEMPLATE{handle} =~ s/^\s*//;
            $handle =~ s/^\s*//;
            if (($current_type ne "") && ($TEMPLATE{handle} eq $handle)) {
                return %TEMPLATE;
            }
        }
        next if /^[\w-]+:$/;                # empty attibute/value pair
        next if /^[\w-]+:[\t\s]+$/;         # ... with trailing whitespace
        next if ($_ !~ /^\s/ && $_ !~ /:/); # no whitespace at start or attrib

        if (/^Template-Type:\s+(\w+)/ || /^Template:\s+(\w+)/) {
            undef %TEMPLATE;
            $current_type = $1;
            $TEMPLATE{"Template-Type"} = $current_type; 
            next;
        }

        if (/^([\w-]+):\s+(.*)/) {
            $current_attr=$1;
            $line = $2;
            $current_attr =~ y/A-Z/a-z/;
        }

        $TEMPLATE{"$current_attr"} =~ s/$/$line/;
    }
    return(%TEMPLATE);
}

1;
__END__


=head1 NAME

ROADS::ReadTemplate - A class to read in templates

=head1 SYNOPSIS

  use ROADS::ReadTemplate;
  %ALLTEMPS = readalltemps();
  # readtemplate should call readalltemps if necessary
  %MYTEMP = readtemplate("XDOM01");
  print $MYTEMP{title}, "\n";

=head1 DESCRIPTION

This class implements two methods associated with reading in IAFA
templates and template handle to filename mappings.

=head1 METHODS

=over 4

=item %ALLTEMPS = realalltemps();

The I<readalltemps> method reads in the list of template handles and
the filenames in which they can be found from the I<alltemps> file,
usually found in the ROADS I<guts> directory.

=item %MYTEMP = readtemplate( handle );

The I<readtemplate> method tries to read in the template with the
handle I<handle>, and returns it as a hash array.  The hash array has
the template's attributes as its keys, and the attributes' values as
its values.

The I<realalltemps> method will be used to discover the filename
corresponding to the template handle, unless the I<ALLTEMPS> variable
has been set already.  Filenames with relative paths are assumed to be
in the ROADS I<source> directory.

=item %MYTEMP = readtemplate( handle, filename );

An alternative invocation of I<readtemplate>, this allows the
programmer to specify the filename which the template should be loaded
from.

=back

=head1 FILES

I<guts/alltemps> - list of template handle to filename mappings.

I<source> - actual templates themselves

=head1 FILE FORMAT

The I<alltemps> file is line structured, with a separate template's
entry on each line.  The fields are :-

=over 4

=item B<handle>

The handle of the template

=item B<filename>

The filename of the template

=back

=head1 BUGS

We tend to assume that the template handle and the filename will be
the same.  This will have to change when we move to a hierarchical
source directory structure - which we'll have to do in order to scale
ROADS to large numbers of records ?

=head1 SEE ALSO

L<bin/addsl.pl>, L<bin/addwn.pl>, L<bin/cullsl.pl>, L<bin/deindex.pl>,
L<bin/rebuild.pl>, L<cgi-bin/suggest.pl>, L<cgi-bin/search.pl>,
L<admin-cgi/admin.pl>, L<admin-cgi/mktemp.pl>

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

