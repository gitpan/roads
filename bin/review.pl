#!/usr/bin/perl
use lib "/home/roads2/lib";

# review.pl - check resource descriptions to see whether they have
#             reached their review date
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: review.pl,v 3.15 1998/09/05 14:00:05 martin Exp $

use Getopt::Std;
use POSIX;

require ROADS;
use ROADS::ErrorLogging;

# Process the command line options
getopts('a:dno:rs:v:');

$owner_attrib = $opt_a || "Record-Last-Verified-Email";
$debug = $opt_d || 0;
$match_nodate = $opt_n || "no";
$owner_email  = $opt_o || "no";
$source = $opt_s || "$ROADS::IafaSource";
$view = $opt_v || "$ROADS::Config/review-views/brief";

%MO = (
  Jan => 1,
  Feb => 2,
  Mar => 3,
  Apr => 4,
  May => 5,
  Jun => 6,
  Jul => 7,
  Aug => 8,
  Sep => 9,
  Oct => 10,
  Nov => 11,
  Dec => 12,
);

chomp(@now = split(/\s+/, ctime(time)));
$day = $now[2];
$mon = $MO{"$now[1]"};
$year = $now[4];

print ">> checking directory $source\n" if $debug;
print ">> testing against day: $day, mon: $mon, year: $year\n" if $debug;

opendir(THISDIR, "$source");
@allfiles = readdir(THISDIR);
closedir(THISDIR);

chdir $source;

foreach $template (@allfiles) {
  print ">> checking $template\n" if $debug;
  next if $template =~ /^\./;

  undef ($test_day,$test_mon,$test_year,$review);

  $matched = "no"; $review = "none";
  open(TEMPLATE, "$template") || next;
  while(<TEMPLATE>) {
    chomp;

    unless ($owner_email eq "no") { 
      if ($matched eq "no") {
        /^$owner_attrib:\s+$owner_email/ && ($matched = "yes");
      }
    }
    next unless $opt_r; # want review
    next unless /^To-Be-Reviewed-Date:\s+(.*)/i;

    # this section only gets done if there's a To-Be-Reviewed-Date
    # attribute in the template

    if (length($1) > 0) {
      $review = $1;
      print ">> found review date: $review\n" if $debug;
    } else {
      print ">> skipping bogus review date\n" if $debug;
      last;
    }

    # we understand two forms of the date ...
    #
    #    Mon Aug  1 23:00:00 1994
    #    Tue, 23 May 1995 13:51:41 GMT
    #    23 Jan 1997

    @mybits = split(/\s+/, $review);
    if ($#mybits == 2) {
      $test_day = $mybits[0];
      $test_mon= $mybits[1];
      $test_year = $mybits[2];
    } elsif ($review =~ /,/) {
      $test_day = $mybits[1];
      $test_mon= $mybits[2];
      $test_year = $mybits[3];
    } else {
      $test_day = $mybits[2];
      $test_mon= $mybits[1];
      $test_year = $mybits[4];
    } 

    $test_mon = $MO{"$test_mon"};

    $test_year = "19$test_year" if length($test_year) == 2;
  }
  close(TEMPLATE);

  if ($owner_email ne "no") {
    next if $matched eq "no";
  }
  
  if ($review eq "none") {
    print "!$template\n" if ($match_nodate ne "no");
    next;
  } 

  print ">> test_day: $test_day, test_mon: $test_mon, test_year: $test_year\n"
    if $debug;
  print ">> day: $day, mon: $mon, year: $year\n" if $debug;

  if ($opt_r) { # only do date test if they want review report
    next unless (($year > $test_year)
        || (($year == $test_year) && ($mon > $test_mon))
        || (($year == $test_year) && ($mon == $test_mon)
              && ($day >= $test_day)));
  }

  if ($view eq "handle") {
    print "$template\n";
    next;
  } 

  if ($view eq "full") {
    open(TEMPLATE, "$template") || &WriteToErrorLogAndDie("review",
                                     "can't open $template: $!");
    while(<TEMPLATE>) { print; }
    close(TEMPLATE);
    print "\n";
    next;
  } 

  undef(@viewattrs);
  open(VIEW, "$view") || &WriteToErrorLogAndDie("review",
                           "can't open view $view: $!");
  while(<VIEW>) { 
    chomp;
    push(@viewattrs, "$_"); 
  }
  close(VIEW);

  open(TEMPLATE, "$template") || &WriteToErrorLogAndDie("review",
                                   "can't open $template: $!");
  while(<TEMPLATE>) { 
    chomp;
    foreach $viewattr (@viewattrs) {
      print "$_\n" if /^$viewattr/i;
    }
  }
  close(TEMPLATE);
  print "\n";
}
__END__


=head1 NAME

B<bin/review.pl> - generate template review info breakdown

=head1 SYNOPSIS

  bin/review.pl [-dnr] [-a attribute] [-o owner]
    [-s sourcedir] [-v view]
 
=head1 DESCRIPTION

This Perl program checks resource descriptions to see whether they
have passed their review date.  It is intended for invocation from a
World-Wide Web CGI program, a cron job, or an at job.

The report which this tool generates can be customized via a I<view>
file, which specifies the attributes which should appear in the
listings of templates which are due for review.

=head1 USAGE

The I<review.pl> tool lets you automatically search your
database for templates which are due to be checked.  This works by
scanning the B<To-Be-Reviewed-Date> attribute in each template,
if present.  It has the limitation that it only understands the
following two ways of writing the date and time:

       Fri Aug  1 23:00:00 1997
       Tue, 23 May 98 13:51:41 GMT

To deal with the ``year 2000'' problem, years which are only two
digits will automatically have 1900 added to them.  We've tried to
make the ROADS software immune to year 2000 bugs - please let us know
if you spot any problems in this area so that we can fix them.

=head1 OPTIONS

=over 4

=item B<-a> I<attribute>

Attribute to look in for record owner's email address.

=item B<-d>

Generate debugging information

=item B<-n>

Match templates which have no I<To-Be-Reviewed-Date> attribute.

=item B<-o> I<owner>

Owner to search for - typically email address.  It is assumed
that you know this already.

=item B<-r>

Template must have I<To-Be-Reviewed-Date> attribute.

=item B<-s> I<sourcedir>

Directory where resource descriptions may be found, if not default.

=item B<-v> I<view>

Template view to be used.  This is a file which specifies the
attributes which should be returned (if present) in the summary
report.

=back

=head1 OUTPUT

Summary report on templates which are due for review.

=head1 FILES

I<config/review-views> - alternative sets of attributes to
return in B<review.pl> reports.

=head1 SEE ALSO

L<admin-cgi/review.pl>

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

