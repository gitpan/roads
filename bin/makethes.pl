#!/usr/bin/perl
use lib "/home/roads2/lib";

# makethes.pl - generate a DBM based thesaurus from a plain text file
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: makethes.pl,v 3.2 1998/08/18 19:31:28 martin Exp $

use POSIX;
use Getopt::Std;
# Handle command line parameters
getopts('f:d');

require ROADS;

# Get the location of the thesaurus file.
$ThesaurusFile = $opt_f || "$ROADS::Config/Thesaurus";

# Attach the thesaurus file (which is a DBM database) to an associative array
dbmopen(%THES,$ThesaurusFile,0644);

# Read in the plain text file from standard input and write it into the
# associative array associated with the thesaurus DBM file
while(<STDIN>) {
    chomp;
    ($keyword,$newwords) = split(/ /,$_,2);
    $THES{$keyword} = $newwords;
}

dbmclose(%THES);
exit 0;
__END__


=head1 NAME

B<bin/makethes.pl> - create thesaurus file or another DB(M) database

=head1 SYNOPSIS

  bin/makethes.pl [-d] [-f filename]

=head1 DESCRIPTION

This program will create a DB(M) database based on a series of
whitespace separated attribute/value pairs in a line delimited text
file.

=head1 OPTIONS

=over 4

=item B<-d>

Turn on debugging.

=item B<-f> I<filename>

DB(M) database filename to operate on.

=back

=head1 FILES

I<config/Thesaurus*> - default DB(M) database and input files

=head1 SEE ALSO

L<admin-cgi/mktemp.pl>, L<admin-cgi/dumpdbm.pl>

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

Martin Hamilton E<lt>martinh@gnu.orgE<gt>
