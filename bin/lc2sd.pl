#!/usr/bin/perl
use lib "/home/roads2/lib";

# lc2sd.pl - Convert Library-Catalog to Subject-Descriptor fields
#
# Author: Jon Knight <jon@net.lut.ac.uk>
# $Id: lc2sd.pl,v 3.6 1998/08/18 19:31:28 martin Exp $

use Getopt::Std;

# Process the command line options
getopts('hs:u:');

require ROADS;

# Spit out some sexy help information
if ($opt_h) {
  die "Usage: $0 [-h] [-s source-dir] [-u scheme-name]\n";
}

$scheme_name = $opt_u || "UDC";
$iafa_source = $opt_s || "$ROADS::IafaSource";

chdir $iafa_source;

opendir(DIR,"$iafa_source") || die "$0: Can't open $iafa_source: $!";
@alltemps = readdir(DIR);
closedir(DIR);

foreach $filename (@alltemps) {
  $_ = $filename;
  next if /^\./;
  if (!open(TEMPLATE,$filename)) {
    die "$0: Can't open template $filename: $!";
  }
  if (!open(NEWTEMP,">.$$")) {
    die "$0: Can't open a temporary template file for writing: $!";
  }
  while(<TEMPLATE>) {
    if (/^Library-Catalog-v([0-9]+):\s*(.*)/) {
      $variant = $1;
      $rest = $2;
      print NEWTEMP "Subject-Descriptor-Scheme-v$variant:\t$scheme_name\n";
      print NEWTEMP "Subject-Descriptor-v$variant:\t$rest\n";
    } else {
      print NEWTEMP $_;
    }
  }
  close(NEWTEMP);
  close(TEMPLATE);
  rename(".$$",$filename);
}

exit;
__END__


=head1 NAME

B<bin/lc2sd.pl> - convert from Library-Catalog to Subject-Descriptor

=head1 SYNOPSIS

  bin/lc2sd.pl [-h] [-s directory] [-u name] 

=head1 SUMMARY

The B<lc2sd.pl> program is intended to change any B<Library-Catalog>
fields in a set of templates into B<Subject-Descriptor> fields.  Older
versions of the ROADS software (prior to v0.2.0) generated
B<Library-Catalog> and they were in several old versions of the
Internet Draft describing IAFA templates.  This program converts these
templates into a format compatible with the latest IAFA Internet
Draft.

=head1 OPTIONS

A number of options are available for the B<lc2sd.pl> program:

=over 4

=item B<-h>

Provide some online help outlining the options available and exit.

=item B<-s> I<directory>

Sets the absolute pathname of the directory containing the IAFA
templates. 

=item B<-u> I<name>

Sets the name of the classification scheme that is to be inserted into
B<Subject-Descriptor-Scheme> fields.

=back

=head1 SEE ALSO

L<bin/addsl.pl>, L<bin/cullsl.pl>

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


