#!/usr/bin/perl

# z3950_centroid.pl - extract centroid from collection of objects harvested
#                     by the NWI/EWI Combine system
#                     <URL:http://www.ub2.lu.se/combine/>

# Author: Martin Hamilton <martinh@gnu.org>
# $Id: z3950_centroid.pl,v 3.2 1998/09/10 17:25:45 jon Exp $

use DB_File;
use Getopt::Std;
use POSIX;
getopt("dh:H:s:");

$debug = $opt_d || 0;
$serverhandle = $opt_s || "undefined";
$hashtemp1 = $opt_h || "hashtemp1";
$hashtemp2 = $opt_H || "hashtemp2";

tie %HASH1, 'DB_File', "$hashtemp1", O_CREAT|O_RDWR, 0644
  || die "$0: couldn't open DB database $hashtemp1: $!";

tie %HASH2, 'DB_File', "$hashtemp2", O_CREAT|O_RDWR, 0644
  || die "$0: couldn't open DB database $hashtemp2: $!";

sub catch_signal {
  untie %HASH1;
  untie %HASH2;
  unlink $hashtemp1;
  unlink $hashtemp2;
  exit -1;
}

$SIG{INT} = \&catch_signal;
$SIG{ILL} = \&catch_signal;
$SIG{TRAP} = \&catch_signal;
$SIG{ABRT} = \&catch_signal;
$SIG{KILL} = \&catch_signal;
$SIG{BUS} = \&catch_signal;
$SIG{SEGV} = \&catch_signal;
$SIG{TERM} = \&catch_signal;

# phase 1 - create hash array based on attribute value pairs in the
#           EWI/NWI records

while (<STDIN>) {
  chop;
  s/[\r\n]//g;

  # sorry, but most of this info is no use to us :-(
  next if
      m!</?(robot|av|avli|ty|dm|ci|si|lc|by|srvr|inf|nh|nl|cr|li|cp)>!i;
  next if
      m!</?(lsi|dh)>!i;

  if (/<wir>i/) {
      $title = $text = "";
  }

  if (/<ti>\s+(.*)/i) {
      $title = $1;

      # @ signs are delimiters
      $title =~ s/@/ /g;

      # we don't want control characters to slip in
      $title =~ tr/[\000-\037]//d;
      $title =~ tr/[\177-\200]//d;
      next;
  }

  if (/<ip>/i) {
      $text = "";
      while (<STDIN>) {
	  chop;
	  last if m!</ip>!i;
          s/[\r\n]//g;
	  $text .= " $_";
      }
      $text =~ s/^\s+//;
  }

  if (m!</wir>!i) {
      # @ signs are delimiters
      $text =~ s/@/ /g;

      # we don't want control characters to slip in
      $text =~ tr/[\000-\037]//d;
      $text =~ tr/[\177-\200]//d;

      foreach $term (split(/\s+/, $title)) {
          next if length($term) <= 2;
          $term =~ s/^[!"#\$%&'()*+,-.\/]//;
          $term =~ s/[!"#\$%&'()*+,-.\/]$//;

	  unless ($HASH1{"$term"}) {
	      $HASH1{"$term"} = 1;
	      warn "added HASH1{$term}\n" if $debug;
	  }
      }
      
      foreach $term (split(/\s+/, $text)) {
          next if length($term) <= 2;
          $term =~ s/^[!"#\$%&'()*+,-.\/]//;
          $term =~ s/[!"#\$%&'()*+,-.\/]$//;

	  unless ($HASH2{"$term"}) {
	      $HASH2{"$term"} = 1;
	      warn "added HASH2{$term}\n" if $debug;
	  }
      }
  }
}

# phase 2 - dump out our centroid based on this info

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
$mon++;
$year += 1900;
$NowTime = sprintf("%04d%02d%02d%02d%02d",$year,$mon,$mday,$hour,$min);

print <<EOF;
# CENTROID-CHANGES\r
 Version-number: 1.0\r
 Start-time: 000000000000\r
 End-time: $NowTime\r
 Case-Sensitive: FALSE\r
 Server-handle: $serverhandle\r
# BEGIN TEMPLATE\r
 Template: NWI\r
 Field: Any-Field\r
EOF

print "# BEGIN FIELD\r\nField-Name: title\r\nValue: ";
$line = 0;
foreach $term (sort keys %HASH1) {
  print "-" unless $line eq 0;
  $line++;
  print "$term\r\n"; 
}
print "# END FIELD\r\n";

print "# BEGIN FIELD\r\nField-Name: description\r\nValue: ";
$line = 0;
foreach $term (sort keys %HASH2) {
  print "-" unless $line eq 0;
  $line++;
  print "$term\r\n"; 
}
print "# END FIELD\r\n";

print "# END TEMPLATE\r\n";
print "# END CENTROIDS\r\n";

untie(%HASH1);
untie(%HASH2);
unlink("$hashtemp1");
unlink("$hashtemp2");

exit 0;
__END__


=head1 NAME

B<bin/z3950_centroid.pl> - extract centroid from NWI/EWI objects

=head1 SYNOPSIS

  bin/z3950_centroid.pl [-d] [-h hashtemp1] [-H hashtemp2]
    [-s serverhandle] < filename

=head1 DESCRIPTION

This Perl program creates a WHOIS++ compatible centroid from the
attributes and values in a collection of NWI/EWI index objects,
as created by the Combine harvester.  Note that you should give
a server handle when invoking this program, or the default value
of 'undefined' will be used.

The Combine harvester creates its database in a two level
directory hierarchy, with a separate file for each indexed
object.  You can combine them together for feeding into this
program using a simple I<find> invocation :-

  find HDB/hdb -type f -exec cat {} \; | z3950_centroid.pl -s test01

Or perhaps something more complicated!

=head1 OPTIONS

=over 4

=item B<-d>

Turn on debugging output - very verbose!

=item B<-h> I<hashtemp1>

Filename to use for temporary DB hash database used in the
construction of the centroid.  This defaults to I<hashtemp1>,
and is used to hold a list of the document titles being
indexed.

=item B<-H> I<hashtemp2>

Filename to use for temporary DB hash database used in the
construction of the centroid.  This defaults to I<hashtemp2>,
and is used to hold a list of the terms in the document text
being indexed.

=item B<-s> I<serverhandle>

=back

=head1 BUGS

We could traverse the filesystem and look at the timestamps on
the index objects - this would let us do a relative centroid.

We don't do anything special about character sets/encodings.

Not up to date with current CIP specifications - this is really
intended for use with a WHOIS++ server which speaks the old RFC
1913 indexing protocol.

=head1 SEE ALSO

L<bin/harvest_centroid.pl>, RFC 1913

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

