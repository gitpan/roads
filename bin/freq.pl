#!/usr/bin/perl
use lib "/home/roads2/lib";

# Author: Martin Hamilton <martinh@gnu.org>
# $Id: freq.pl,v 3.10 1998/09/05 14:00:05 martin Exp $

require ROADS;
use ROADS::ErrorLogging;

# docs in POD format - use perldoc et al to extricate

=head1 NAME

B<bin/freq.pl> - term frequency counter for IAFA style templates

=head1 SYNOPSIS

  freq.pl [-ad] [-f maxhits] [-m min-count] [-s sourcedir]
    [-t tmpdir] [-A attrib1|attrib2|...|attribN]

=head1 DESCRIPTION

This Perl program will look at all the IAFA style templates in a given
directory, and count the number of times each term found in the
templates occurs.  This has a number of uses - notably in determining
an appropriate stop-list of words which should not be indexed, and in
helping the user to devise an effective query.

Frequently appearing terms such as I<a>, and I<the> will likely
cause large numbers of spurious hits when people search your
database.  To reduce the likelihood of this, we have added a
``stoplist'' feature to the ROADS search back end - this lets you
arrange for certain search terms to be automatically removed, and we
ship a sample stop list with the ROADS distribution.

The default behaviour is to sort the frequency count into order, and
return the top fifty terms.  This can be overridden by a set of
command-line options.

=cut

use Getopt::Std;
getopts('adf:m:s:t:A:');

$debug = $opt_d || 0;
$TMPDIR = $opt_t || $ROADS::TmpDir; # default temporary directory is /tmp
$SOURCEDIR = $opt_s || $ROADS::IafaSource;
$FIRST = $opt_f || 50; # default is to return top 50

&WriteToErrorLogAndDie("freq",
  "sort program '$ROADS::SortPath' doesn't work.  Panic!")
    unless -x "$ROADS::SortPath";

=head1 OPTIONS

=over 4

=item B<-a>

send back a complete frequency count, rather than just the most
frequently used terms

=item B<-d>

produce verbose debugging output

=item B<-f> I<maxhits>

send back at most the top I<maxhits> most frequently used terms,
e.g. to see the top 100 with debugging info

  freq.pl -df 100 

=item B<-m> I<min-count>

stop once the frequency count falls below I<min-count>, e.g. to
get a list of all the terms which occur more than 999 times

  freq.pl -m 999 | cut -f2 -d' '

=item B<-s> I<sourcedir>

look for the templates in the directory I<sourcedir>, e.g. to use
the templates in the directory I</work2/WWW/roads> and return a
complete frequency breakdown

  freq.pl -as /work2/WWW/roads

=item B<-t> I<tmpdir>

use I<tmpdir> as temporary directory.  This defaults to I</tmp>,
but you may need to change the default if your machine does not
have enough room in I</tmp> for any temporary files generated
by I<freq.pl>, e.g.

  freq.pl -t /var/tmp

=item B<-A> I<attribute-list>

only produce frequency list for the attributes listed in I<attribute-list>.
I<attribute-list> is a '|' (pipe) separated list of attribute names, e.g.

  freq.pl -A 'description|keywords'

=back

=cut

# suck in the terms from the templates in $SOURCEDIR
opendir(TEMPLATEDIR, "$SOURCEDIR") 
  || &WriteToErrorLogAndDie("freq", "Can't open $SOURCEDIR: $!");
foreach $template (readdir(TEMPLATEDIR)) {
  next if $template =~ /^(\.|\.\.)/;

  # suck in the terms for an individual template
  $cum = ""; # the terms in this template
  open(TEMPLATE, "$SOURCEDIR/$template") 
    || &WriteToErrorLogAndDie("freq", "Can't open $SOURCEDIR/$template: $!");
  print ">> Opened $SOURCEDIR/$template\n" if $debug;
  while (<TEMPLATE>) {
    chomp;
    if ($opt_A) {
      unless (/^($opt_A):/i || (/^\s/ && $inatt) || /^\+/) {
          $inatt = 0;
          next;
      }
    }
    else {
      next if /^(Template-Type|Handle):/;
    }

    if (/^\+/) { # continues after last line
      s/^.//;
      $cum .= $_;
      next;
    }

    $inatt = 1;

    s/^-//;
    s/^[^:]+:\s*(.*)/$1/;
    s/^\s+//;
    s/\s+$//;
    $cum .= " $_";
  }
  close(TEMPLATE);

  # update term frequency count for the terms in this template
  foreach $term (split(/\W/, $cum)) {
    next if $term =~ /^\s+$/;
    next if $term =~ /^$/;
    $debug && print ">>> new term $term\n" unless $HITS{$term};
    $HITS{$term} = $HITS{$term} ? $HITS{$term} + 1 : 1;
  }
}
closedir(TEMPLATEDIR);

# dump results out to a temporary file
$TMPFILE="$TMPDIR/freq$$";
open(OUT, ">$TMPFILE") || &WriteToErrorLogAndDie("freq",
                           "Can't open temporary file $TMPFILE: $!");
foreach (keys %HITS) { print OUT "$HITS{$_} $_\n"; }
close(OUT);

# sort into numerical order
@RESULTS = `$ROADS::SortPath -nr -T $TMPDIR $TMPFILE`; 

=head1 OUTPUT FORMAT

The output of B<freq.pl> consists of the frequency count for a term,
followed by a single space character, followed by the term itself,
e.g.

  310 research
  283 mailing
  270 available
  268 University

=cut

# now post-process the results
$count=0; # how many terms we've seen so far
foreach (@RESULTS) { 
  print $_; # dump it out
  next if $opt_a; # don't bother counting if we want all of them
  $count++;

  $FIRST && last if ($count > ($FIRST - 1)); # stop after this many
  $opt_m && do {
    ($freq, $term) = split;
    last if $freq < $opt_m;
  }
}

unlink($TMPFILE) # now remove any traces of our presence!
  || &WriteToErrorLogAndDie("freq",
       "Couldn't unlink temporary file $TMPFILE: $!");


=head1 DEPENDENCIES

An external program called "sort" is used to sort the frequency
count into descending order.  This is a standard feature of most
(all?) implementations of Unix, but the command line options it
takes may differ from version to version.  Let us know if you
find a version which does not understand B<-r>, B<-n> or B<-T>!

=head1 TODO

Nothing ? :-)

=head1 SEE ALSO

L<admin-cgi/freq.pl>

=head1 COPYRIGHT

Copyright (c) 1988, Martin Hamilton E<lt>martinh@gnu.orgE<gt> and Jon
Knight E<lt>jon@net.lut.ac.ukE<gt>.  All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

It was developed by the Department of Computer Studies at Loughborough
University of Technology, as part of the ROADS project.  ROADS is funded
under the UK Electronic Libraries Programme (eLib), the European
Commission Telematics for Research Programme, and the TERENA
development programme.

=head1 AUTHOR

Martin Hamilton E<lt>martinh@gnu.orgE<gt>

=cut

