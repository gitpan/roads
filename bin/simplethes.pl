#!/usr/bin/perl
use lib "/home/roads2/lib";

# simplethes.pl - A simple demo thesaurus expansion program
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: simplethes.pl,v 3.6 1998/08/18 19:31:28 martin Exp $

use POSIX;
use Getopt::Std;
# Handle command line parameters
getopts('f:d');

require ROADS;

# Get the location of the thesaurus file.
$ThesaurusFile = $opt_f || "$ROADS::Config/Thesaurus";

# Attach the thesaurus file (which is a DBM database) to an associative array
dbmopen(%THES,$ThesaurusFile,undef);

$query = $ENV{"QUERY_STRING"};

foreach $word (split(/\s+/,$query)) {
    warn "word = '$word'\n" if($opt_d);
    next if($word =~ /AND/i);
    next if($word =~ /OR/i);
    next if($word =~ /NOT/i);
    $newwords = $THES{$word};
    warn "newwords = '$newwords'\n" if($opt_d);
    next if($newwords eq "");
    print STDOUT "$newwords\n";
}

exit 0;
__END__


=head1 NAME

B<bin/simplethes.pl> - simple sample thesaurus plug-in

=head1 SYNOPSIS

  bin/simplethes.pl [-d] [-f filename]
 
=head1 DESCRIPTION

This is a simple example program which is intended to illustrate the
possibilities for using Perl and DB(M) databases to perform query
expansion.  The query to be expanded is passed as an environmental
variable I<QUERY_STRING>, as per the CGI specification.

=head1 OPTIONS

=over 4

=item B<-d>

Turn on debugging mode.

=item B<-f> I<filename>

The name of the thesaurus DB(M) database which should be used.

=back

=head1 SEE ALSO

L<bin/wppd.pl>, L<admin-cgi/dumpdbm.pl>, L<bin/makethes.pl>

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

