#!/usr/bin/perl
use lib "/home/roads2/lib";

# Program to deindex IAFA templates from the inverted filesystem index
#
# Author: Jon Knight <jon@net.lut.ac.uk>
# $Id: deindex.pl,v 3.14 1998/08/28 17:36:21 martin Exp $

use Getopt::Std;

# Process the command line options
getopts('c:dhi:s:t:');

require ROADS;
use ROADS::ErrorLogging;
use ROADS::ReadTemplate;

if ($opt_h) {
  die "Usage: $0 [-c ci_path] [-d] [-h] [-i index-dir] [-s source-dir] "
    . " [-t tmp-dir] template-handle [template-handle...]\n";
}

# Location of the RCS ci command
$ci = $opt_c || "$ROADS::RCSCiPath";
$inverted_index = $opt_i || "$ROADS::IndexDir";
$iafa_source = $opt_s || "$ROADS::IafaSource";
# Location of default temporary directory
$tmpdir = $opt_t || "$ROADS::TmpDir" || "/tmp";

chdir $iafa_source
  || &WriteToErrorLogAndDie("deindex", "Can't chdir($iafa_source): $!");

# The top secret hackers switch.  Only set to non-zero if you want to see lots
# of crap, erm, debugging output and you're not using a Netscape server.
$debug = $opt_d || 0;

%ALLTEMPS = &readalltemps;

foreach $handle (@ARGV) {
  $filename = $ALLTEMPS{"$handle"};

  if(!open(TEMPLATES,$filename)) {
    &WriteToErrorLogAndDie("deindex", "Can't open $filename: $!");
  }
  undef %TEMPLATE;
  $current_type = $current_attr = "";
  $matched = 0;
  if(!open(TMPFILE,">$tmpdir/tmp1.$$")) {
    &WriteToErrorLogAndDie("deindex",
      "Can't open tmp file $tmpdir/tmp1.$$: $!");
  }
  while(<TEMPLATES>) {
    chomp;
    $line = $_;
    if (/^Template-Type:\s+(\w+)/) {
      undef %TEMPLATE;
      @words = "";
      $TEMPLATE{"Template-Type"}=$1;
      $current_type = $1;
    } else {
      if (/^([\w-]+)\:\s+(.*)/) { # regular attrib/value pair
        $current_attr=$1;
        $line = $2;
        $real_attr = $current_attr;
        $current_attr =~ y/A-Z/a-z/;
        $REALFIELD{"$current_attr"} = $real_attr;
      } elsif (/^\s+(.*)/) {        # continuation line
	  $line = $1;
      } else {                      # bogus!  log for info
  	 &WriteToErrorLog("deindex",
           "bogus attribute '$_' in template $handle");
         $line = "";
      }
      $TEMPLATE{"$current_attr"} =~ s/$/$line/;
      (@newwords) = split(/\W/,$line);
      @words = (@words,@newwords);
    }

    if (/^\n$/ || eof(TEMPLATES)) {
      if ($current_type ne "") {
        $TEMPLATE{"handle"} =~ s/^\s*//;
        if ($TEMPLATE{"handle"} eq $handle) {
          # We've found the template we don't want.
          $matched = 1;
          mkdir(".archive", 0755) if (! -d ".archive");
          if(!open(RCSFILE, ">.archive/$handle")) {
            &WriteToErrorLogAndDie("deindex",
              "Can't open archive .archive/$handle: $!");
          }
          print RCSFILE "Template-Type: $TEMPLATE{\"Template-Type\"}\n";
          print RCSFILE "Handle: $handle\n";
          foreach $field (keys %TEMPLATE) {
            $_ = $field;
            next if /Template-Type/;
            next if /handle/;
            next if $field eq "0";
            print RCSFILE "$REALFIELD{\"$field\"}: $TEMPLATE{\"$field\"}\n";
          }
          print RCSFILE "\n\n";
          close (RCSFILE);
          if($ci ne "" && -x "$ci") {
            chdir(".archive");
            mkdir("RCS", 0755) if (! -d "RCS");
            open(CI,"|$ci -l -q $handle");
            print CI ".\n";
            close (CI);
            chdir "..";
          }
        } else {
          print TMPFILE "Template-Type: $TEMPLATE{\"Template-Type\"}\n";
          print TMPFILE "Handle: $TEMPLATE{\"handle\"}\n";
          foreach $field (keys %TEMPLATE) {
            $_ = $field;
            next if /Template-Type/;
            next if /handle/;
            next if $field eq "0";
            print TMPFILE "$REALFIELD{\"$field\"}: $TEMPLATE{\"$field\"}\n";
          }
          print TMPFILE "\n\n";
        }
      }
      $current_type = "";
      undef %TEMPLATE;
      @words = "";
    } 
  }
  close(TMPFILE);
  if ($matched == 1) {
    system "$ROADS::MvPath", "$tmpdir/tmp1.$$", "$filename";
    unlink ("$filename") if (-z "$filename");
    warn "Configure: Deindexed $handle in $filename\n" if($debug);
  }
}

open(INDEXLOCK,">>$ROADS::Guts/index.lock")
  || &WriteToErrorLogAndDie("deindex",
       "Can't open $ROADS::Guts/index.lock: $!");
flock(INDEXLOCK,2)
  || &WriteToErrorLogAndDie("deindex", 
       "Can't lock $ROADS::Guts/index.lock: $!");

open(INDEX1, "$ROADS::Guts/index")
  || &WriteToErrorLogAndDie("deindex",
       "Can't open $ROADS::Guts/index: $!");

open(INDEX2, ">$ROADS::Guts/index.new")
  || &WriteToErrorLogAndDie("deindex",
       "Can't open $ROADS::Guts/index.new: $!");

$tmpfile4 = "$tmpdir/roadstmp4.$$";
$tmpfile5 = "$tmpdir/roadstmp5.$$";
 
open(TMPFILE4,">$tmpfile4")
  || &WriteToErrorLogAndDie("deindex", "Can't open $tmpfile4: $!");

$indexpos = 0;

while(<INDEX1>) {
  chomp;
  ($template,$attribute,$term,$handles) = split /:/;

  foreach $zappa (@ARGV) {
    if ($handles =~ /^$zappa( |$)/) {
      $handles =~ s/^$zappa//;
      $handles =~ s/^\s+//;
      next;
    }
    if ($handles =~ /(^| )$zappa$/) {
      $handles =~ s/$zappa$//;
      $handles =~ s/\s+$//;
      next;
    }
    if ($handles =~ / $zappa /) {
      $handles =~ s/ $zappa / /;
      next;
    }
  }
  print INDEX2 "$template:$attribute:$term:$handles\n"
    unless $handles =~ /^$/ || $handles =~ /^\s+$/;
}

close(INDEX1);
close(INDEX2);
close(TMPFILE4);

warn ">> sort temporary indirection file\n" if $debug;
if(system("$ROADS::SortPath -t':' -T $tmpdir $tmpfile4 > $tmpfile5")) {
  &WriteToErrorLogAndDie("deindex",
   "Can't sort $tmpfile4 into $tmpfile5: $!");
}
unlink $tmpfile4 unless $debug;

warn ">> building indirection index\n" if $debug;

# Open the sorted temporary file for the indirection index file
unless (open(TMPFILE5,"$tmpfile5")) {
  &WriteToErrorLogAndDie("deindex", "Can't read temporary file $tmpfile5: $!");
}

# Open a new temporary file for the merged indirection index file
unless (open(INDEX3,">$ROADS::Guts/index.idr.new")) {
  &WriteToErrorLogAndDie("deindex",
    "Can't create temporary file $ROADS::Guts/index.idr.new: $!");
}

dbmopen(%IDX,"$ROADS::Guts/index.dbm",0644)
  || &WriteToErrorLogAndDie("deindex",
      "Couldn't create DBM file $ROADS::Guts/index.dbm: $!");

$indexpos = 0; # position in index file;
undef %IDX;
while(<TMPFILE5>) {
  chomp;
  ($term,$position) = split(/:/);

  $last_term = $term if $last_term eq "";
  $caseless_term = $last_term;
  $caseless_term =~ tr/a-z/A-Z/;

  if ($term ne $last_term) {
    print INDEX3 "$last_term:$positions\n";
    if(!(defined $IDX{$caseless_term})) {
      $IDX{$caseless_term} = $indexpos;
    } else {
      $donotadd = 0;
      foreach $oldpos (split(",",$IDX{$caseless_term})) {
        if($oldpos == $indexpos) {
          $donotadd = 1;
          last;
        }
      }
      $IDX{$caseless_term} .= ",$indexpos" if(!$donotadd);
    }
    $indexpos = $indexpos+length("$last_term:$positions\n");
    $last_term = $term;
    $positions = $position;
    next;
  }

  $positions = $positions ? "$positions $position" : $position;
}
print INDEX3 "$term:$positions\n";
$caseless_term = $term;
$caseless_term =~ tr/a-z/A-Z/;
$IDX{$caseless_term} = $indexpos;
close(TMPFILE5);
unlink $tmpfile5 unless $debug;
close(INDEX3);
dbmclose(%IDX);
 
rename("$ROADS::Guts/index", "$ROADS::Guts/index.FCS")
  || &WriteToErrorLogAndDie("deindex",
       "Can't rename $ROADS::Guts/index to $ROADS::Guts/index.FCS: $!");
rename("$ROADS::Guts/index.new", "$ROADS::Guts/index")
  || &WriteToErrorLogAndDie("deindex",
       "Can't rename $ROADS::Guts/index.new to $ROADS::Guts/index: $!");
rename("$ROADS::Guts/index.idr", "$ROADS::Guts/index.idr.FCS")
  || &WriteToErrorLogAndDie("deindex",
       "Can't rename $ROADS::Guts/index.idr to $ROADS::Guts/index.idr.FCS: $!");
rename("$ROADS::Guts/index.idr.new", "$ROADS::Guts/index.idr")
  || &WriteToErrorLogAndDie("deindex",
       "Can't rename $ROADS::Guts/index.idr.new to $ROADS::Guts/index.idr: $!");
close(INDEXLOCK);
flock(INDEXLOCK,8);

exit;
__END__


=head1 NAME

B<bin/deindex.pl> - remove templates from index

=head1 SYNOPSIS

  bin/deindex.pl [-c ci_path] [-dh] [-i index_dir]
    [-s source_dir] [-t tmp_dir] handle1 handle2 ... handleN

=head1 DESCRIPTION

The B<deindex.pl> script removes one or more templates from a
filesystem based inverted index of IAFA templates created by
B<mkinv.pl>.  The inverted index allows the B<search.pl> and
B<admin.pl> programs programs to rapidly match keywords and boolean
expressions in a large number of IAFA templates.  The B<deindex.pl>
program removes all keywords from the inverted index associated with
the specifed template(s).

=head1 OPTIONS

A number of options are available for the B<deindex.pl> program to
control where it looks for its files:

=over 4

=item B<-c> I<ci_path>

Location of the RCS I<ci> program.

=item B<-d>

Enable debugging mode.

=item B<-h>

Display usage.

=item B<-i> I<index_dir>

Set the I<absolute> pathname of the directory in which the resulting
inverted index is to be placed.  By default this is the I<guts>
directory of the ROADS installation.

=item B<-s> I<source_dir>

Set the I<absolute> pathname of the directory containing the IAFA
templates.  By default this is the I<source> directory of the ROADS
installation.

=item B<-t> I<temp_dir>

Set the I<absolute> pathname of the temporary directory used to hold a
working copy of the template(s) being de-indexed.

=back

The options are then followed by one or more template handles to be
deindexed.  The B<deindex.pl> script removes all traces of these
templates from the selected inverted index.  The script also archives
a copy of the template in a I<.archive> subdirectory of the IAFA
template source directory.  This archiving uses the I<GNU> Revision
Control System (RCS) if available, allowing multiple copies of a
template's change history to be recorded.

=head1 FILES

I<config/guts> - default location of index data

I<config/source> - default location of template database

I<config/source/.archive> - location of archived templates

=head1 SEE ALSO

L<bin/admin.pl>, L<bin/mkinv.pl>, L<bin/search.pl>

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

