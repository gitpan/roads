#!/usr/bin/perl
use lib "/home/roads2/lib";

# mkinv.pl: New Improved Indexer (with added zing and zang!)
#
# Authors: Jon Knight <jon@net.lut.ac.uk>
#          Martin Hamilton <martinh@gnu.org>
#
# $Id: mkinv.pl,v 3.23 1998/08/28 17:36:21 martin Exp $

use Getopt::Std;
getopts('adhi:m:s:t:ux:y:z:');

require ROADS;
use ROADS::ErrorLogging;

if ($opt_h) {
    die <<EOF;
Usage: $0 [-adhu] [-i index-dir] [-m min-size] [-s source-dir]
  [-t tmp dir] [-x stoplist] [-y stopattr] [-z alltemps]
EOF
}

# override globals if necessary...
$IndexDir = $opt_i || "$ROADS::Guts";
$SourceDir = $opt_s || "$ROADS::IafaSource";
$TmpDir = $opt_t || "$ROADS::TmpDir";
$IndexSplitPattern = "$ROADS::IndexSplitPattern" || '[^\w\x80-\xff]';

# local stuff
$debug = $opt_d || 0;
$minsize  = $opt_m || 2;
$stoplist = $opt_x || "$ROADS::Config/stoplist";
$stopattr = $opt_y || "$ROADS::Config/stopattr";
$alltemps = $opt_z || "$ROADS::Guts/alltemps";

# What we think we're doing!
print STDERR <<EOF if $debug;
>> All files: $opt_a
>> Making index in directory: $IndexDir
>> Source files in directory: $SourceDir
>> Temporary directory: $TmpDir
>> Split pattern: $IndexSplitPattern
>> Stoplist: $stoplist
>> Stoplist for attribute names: $stopattr
>> All templates list: $alltemps
EOF

chomp($PWD = `pwd`); # just in case those were relative path names

$tmpfile1 = "$TmpDir/roadstmp1.$$";
$tmpfile2 = "$TmpDir/roadstmp2.$$";
$tmpfile3 = "$TmpDir/roadstmp3.$$";
$tmpfile4 = "$TmpDir/roadstmp4.$$";
$tmpfile5 = "$TmpDir/roadstmp5.$$";
$tmpfile6 = "$TmpDir/roadstmp6.$$";

unless (open(TMPFILE, ">$tmpfile1")) {
  &WriteToErrorLogAndDie("mkinv",
     "Can't create temporary file $tmpfile1: $!");
}

unless (open(ALLTEMPS, $opt_a ? ">$alltemps" : ">>$alltemps")) {
  &WriteToErrorLogAndDie("mkinv",
    "Can't create/append to $alltemps file: $!");
}

if (open(STOPLIST, "$stoplist")) {
  warn ">> Reading in stoplist\n" if $debug;
  while(<STOPLIST>) {
    chomp;
    $_ =~ tr/[A-Z]/[a-z]/;
    $STOPLIST{"$_"} = "y";
  }
  close(STOPLIST);
}

if (open(STOPATTR, "$stopattr")) {
  warn ">> Reading in stopattr\n" if $debug;
  while(<STOPATTR>) {
    chomp;
    $_ = lc($_);
    $STOPATTR{"$_"} = "y";
  }
  close(STOPATTR);
}

# Process all the files in the source directory - this must come after the
# source directory is selected!
warn ">> Changing directory to $SourceDir\n" if $debug;
chdir "$SourceDir" || 
  &WriteToErrorLogAndDie("mkinv", "Couldn't change to $SourceDir: $!");
if ($opt_a) {
  warn ">> Reading all files\n" if $debug;
  undef @ARGV;
  unless (opendir(ALLFILES, ".")) {
    &WriteToErrorLogAndDie("mkinv", "Can't open $SourceDir directory: $!");
  }
  @ARGV = readdir(ALLFILES);
  closedir(ALLFILES);
}

warn ">>files: @ARGV<<\n" if $debug;

$SIG{'QUIT'} = handler;
$SIG{'INT'} = handler;

sub handler {
  warn "\n>> Cleaning up temp files and exiting\n" if $debug;
  chdir "$PWD";
  unlink $tmpfile1;
  unlink $tmpfile2;
  unlink $tmpfile3;
  unlink $tmpfile4;
  unlink $tmpfile5;
  unlink $tmpfile6;
  $SIG{'QUIT'} = ignore;
  exit;
}

$|=1;

foreach $filename (@ARGV) {
  $_ = $filename;
  next if /^\./;
  next if($filename =~ /\.core$/);
  next if($filename eq "core");
  
  print STDERR "." if $debug;

  $status = "no";
  open(TEMPLATE, "$filename") || 
    &WriteToErrorLogAndDie("mkinv", "Can't open $filename: $!");
  while(<TEMPLATE>) { # first pass looking for "Status: stale"
    chomp;
    if (/^Status:\s+stale/i) { $status = "stale"; last; }
  }
  close(TEMPLATE);

  next if $status eq "stale";

  open(TEMPLATE, "$filename") || 
    &WriteToErrorLogAndDie("mkinv", "Can't open $filename: $!");
  $attr = "none";
  $tt = "";
  while(<TEMPLATE>) {
    chomp;
    next if /^Record-/i;
    next if /^\s*$/;

    if (/^Handle:\s*(.*)/i) {
      $handle = $1;
      $handle =~ s/\s//g;
      print ALLTEMPS "$handle $filename\n";
      next;
    }

    if (/^Template-Type:\s*(.*)/i) {
      $tt = lc($1);
      $outtt = 1;
      next;
    }

    if($outtt) {
      print TMPFILE "$tt:template-type:$tt:$handle\n";
    } 

    if (/^([^\s:]+):\s*(.*)/) { # don't try indexing stoplisted attributes
      $attr = $1;
      $value = $2;
      $attr =~ s/-v\d+//;
      $attr = lc($attr);
      next if $STOPATTR{"$attr"}; 
    } else {
      $value = $_;
    }

    $value =~ tr/[\/\\]/ /;
    foreach $term (split(/$IndexSplitPattern/, $value)) {
      $term =~ s/\.+$//;
      next if $term =~ /^(\s+|)$/; # skip blanks
      next if length($term) < $minsize;
      $test = lc($term);
      next if $STOPLIST{"$test"}; # skip terms in stoplist
      print TMPFILE "$tt:$attr:$term:$handle\n";
    }
  }
  close(TEMPLATE);
}

close(ALLTEMPS);
close(TMPFILE);

warn "\n" if $debug;

unless ($opt_a) {
  warn ">> snarfing current index and appending to temp file\n" if $debug;
  if(system("$ROADS::CatPath $IndexDir/index >>$tmpfile1") != 0) {
    &WriteToErrorLogAndDie("mkinv",
     "Can't append current index to $tmpfile1: $!");
  }
}

warn ">> sorting and uniqing the alltemps file\n" if $debug;
if(system("$ROADS::SortPath -T $TmpDir -u $alltemps > $alltemps.new")!=0) {
  &WriteToErrorLogAndDie("mkinv",
   "Can't sort/uniq $alltemps into $alltemps.new: $!");
}

warn ">> sorting 1st temporary file into second\n" if $debug;
if(system("$ROADS::SortPath -t':' -u -T $TmpDir $tmpfile1 > $tmpfile2") != 0) {
  &WriteToErrorLogAndDie("mkinv",
   "Can't sort/uniq $tmpfile1 into $tmpfile2: $!");
}
unlink $tmpfile1 if ($opt_u || !$debug);

warn ">> generating a combined index entry for each attribute/term pair\n"
    if $debug;

$last_tt = $last_attr = $last_term = "";

unless (open(TMPFILE2, "$tmpfile2")) {
  &WriteToErrorLogAndDie("mkinv", "Can't open temporary file $tmpfile2: $!");
}

unless (open(TMPFILE3,">$tmpfile3")) {
  &WriteToErrorLogAndDie("mkinv", "Can't create temporary file $tmpfile3: $!");
}

# Open a temporary file for the indirection index file
unless (open(TMPFILE4,">$tmpfile4")) {
  &WriteToErrorLogAndDie("mkinv", "Can't create temporary file $tmpfile4: $!");
}

$indexpos = 0; # position in index file;
while(<TMPFILE2>) {
  chomp;
  ($tt,$attr,$term,$handle) = split(/:/,$_,4);

  $last_tt = $tt if $last_tt eq "";

  if ($attr ne $last_attr || $term ne $last_term) {
    if(!($last_attr eq "" || $last_term eq "")){
      print TMPFILE3 "$last_tt:$last_attr:$last_term:$handles\n";
      print TMPFILE4 "$last_term:$indexpos\n";
      $indexpos = $indexpos+length("$last_tt:$last_attr:$last_term:$handles\n");
    }
    $last_tt = $tt;
    $last_attr = $attr;
    $last_term = $term;
    $handles = $handle;
    next;
  }

  $handles = $handles ? "$handles $handle" : $handle;
}
print TMPFILE3 "$tt:$attr:$term:$handles\n";
print TMPFILE4 "$last_term:$indexpos\n";
close(TMPFILE2);
unlink $tmpfile2 if ($opt_u || !$debug);
close(TMPFILE3);
close(TMPFILE4);

warn ">> sort temporary indirection file\n" if $debug;
if(system("$ROADS::SortPath -t':' -T $TmpDir $tmpfile4 > $tmpfile5")) {
  &WriteToErrorLogAndDie("mkinv",
   "Can't sort $tmpfile4 into $tmpfile5: $!");
}
unlink $tmpfile4 if ($opt_u || !$debug);

warn ">> building indirection index\n" if $debug;

# Open the sorted temporary file for the indirection index file
unless (open(TMPFILE5,"$tmpfile5")) {
  &WriteToErrorLogAndDie("mkinv", "Can't read temporary file $tmpfile5: $!");
}

# Open a new temporary file for the merged indirection index file
unless (open(TMPFILE6,">$tmpfile6")) {
  &WriteToErrorLogAndDie("mkinv", "Can't create temporary file $tmpfile6: $!");
}

dbmopen(%IDX,"$ROADS::Guts/index.dbm",0666)
  || &WriteToErrorLogAndDie("mkinv", 
      "Couldn't create DBM file $ROADS::Guts/index.dbm: $!");

$indexpos = 0; # position in index file;
undef %IDX;
while(<TMPFILE5>) {
  chomp;
  ($term,$position) = split(/:/);

  $last_term = $term if $last_term eq "";
  $caseless_term = lc($last_term);

  if ($term ne $last_term) {
    print TMPFILE6 "$last_term:$positions\n";
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

  $positions = ($positions ne "") ? "$positions $position" : $position;
}
print TMPFILE6 "$term:$positions\n";
$caseless_term = $term;
$caseless_term =~ tr/a-z/A-Z/;
$IDX{$caseless_term} = $indexpos;
close(TMPFILE5);
unlink $tmpfile5 if ($opt_u || !$debug);
close(TMPFILE6);
dbmclose(%IDX);

warn ">> updating ROADS index\n" if $debug;

if (-s "$tmpfile3") {
  warn ">> renaming '$IndexDir/index' to '$IndexDir/index.FCS'\n" if $debug;
  rename "$IndexDir/index", "$IndexDir/index.FCS";
  warn ">> copying new index into place\n" if $debug;
  system("$ROADS::CpPath $tmpfile3 $IndexDir/index");
  unlink $tmpfile3 if ($opt_u || !$debug);
  warn ">> renaming '$alltemps' to '$alltemps.FCS'\n" if $debug;
  rename "$alltemps", "$alltemps.FCS";
  warn ">> copying new alltemps into place\n" if $debug;
  system("$ROADS::CpPath $alltemps.new $alltemps");

  warn ">> renaming '$IndexDir/index.idr' to '$IndexDir/index.idr.FCS'\n" if $debug;
  rename "$IndexDir/index.idr", "$IndexDir/index.idr.FCS";
  warn ">> copying new index into place\n" if $debug;
  system("$ROADS::CpPath $tmpfile6 $IndexDir/index.idr");
  unlink $tmpfile6 if ($opt_u || !$debug);
}

warn ">> done!\n" if $debug;

exit;
__END__

=head1 NAME

B<bin/mkinv.pl> - build ROADS database index

=head1 SYNOPSIS

  bin/mkinv.pl [-adhu] [-i directory] [-m minsize]
    [-s directory] [-t directory] [-x stoplist]
    [-y stopattr] [-z alltemps] [handle1 handle2 ... handleN]

=head1 DESCRIPTION

The B<mkinv.pl> program generates an index of IAFA templates which can
be searched using the B<search.pl> and B<admin.pl> CGI programs.  The
index is used by these programs to rapidly match keywords and boolean
expressions in a large number of IAFA templates.

=head1 OPTIONS

A number of options are available to the B<mkinv.pl> program to
control where it looks for its files:

=over 4

=item B<-a> 

Index all the templates in the specified source directory.

=item B<-d>

Turn on debugging mode.

=item B<-h>

Provides online help and exits.

=item B<-i> I<directory>

Set the I<absolute> pathname of the directory in which the resulting
inverted index is to be placed.

=item B<-m> I<minsize>

Don't index terms which are shorter than this - default is two
characters.

=item B<-s> I<directory>

Set the I<absolute> pathname of the directory containing the
source IAFA templates.

=item B<-t> I<directory>

Set the I<absolute> pathname of the directory to be used for
intermediate temporary files.  This option is useful if you find that
you are running out of room in the system default temporary directory
during particularly large indexing runs.

=item B<-u>

Unlink temporary files when in debug mode.  Gives visual feedback
without leaving lots of unsightly junk lying around.

=item B<-x> I<stoplist>

The I<absolute> pathname of a file containing a list of terms which
should not be indexed.

=item B<-y> I<stopattr>

The I<absolute> pathname of a file containing a list of attributes
which should not be indexed.

=item B<-z> I<alltemps>

The I<absolute> pathname of the file to which the list of template
handle to filename mappings should be saved.

=back

If the B<-a> option is not used, the B<mkinv.pl> script expects one or
more filenames containing IAFA templates to be given.  These files are
then processed, and all the templates in them are indexed.

=head1 FILES

I<config/stopattr> - default list of attributes to exclude from
the index.

I<config/stoplist> - default list of terms to exclude from the
index.

I<guts/index*> - index files themselves.

I<guts/alltemps> - list of template handle to filename mappings.

I<source> - the source templates themselves.

=head1 SEE ALSO

L<admin-cgi/admin.pl>, L<bin/deindex.pl>, L<admin-cgi/deindex.pl>,
L<cgi-bin/search.pl>, L<admin-cgi/mktemp.pl>

=head1 BUGS

The indexer will only correctly index IAFA templates that have a
B<Template-Type> attribute first and a B<Handle> attribute second.
All other attributes can be in any order.  All templates generated by
the ROADS software are in this format but the actual IAFA Internet
Draft is not as strict.  If you are processing templates derived from
outside the ROADS system, be sure to ensure that these conditions hold
before attempting to index them with B<mkinv.pl>.

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

=head1 AUTHORS

Jon Knight E<lt>jon@net.lut.ac.ukE<gt>,
Martin Hamilton E<lt>martinh@gnu.orgE<gt>

