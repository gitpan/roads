#!/usr/bin/perl
use lib "/home/roads2/lib";

# report.pl - generate report based on link check results
# using libwww-perl HTTP status module
# 
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: report.pl,v 3.9 1998/08/18 19:31:28 martin Exp $

use HTTP::Status;
use Getopt::Std;
getopts("hl:s:");

require ROADS;
use ROADS::ErrorLogging;

$LOGFILE = $opt_l || "$ROADS::Logs/lc";
$SORTPROG = $opt_s || "$ROADS::SortPath" || "sort";

open(SORT, "$SORTPROG $LOGFILE|")
  || &WriteToErrorLogAndDie("report",
       "couldn't open path to sort program $SORTPROG: $!");

$last = "undefined";

while(<SORT>) {
  chomp;
  next if /^200/;
  ($code, $file, $url) = split;

  if ($code ne $last) {
    print "\n" unless $last eq "undefined";
    print "Code: $code (", status_message($code), ")\n\n";
    $last = $code;
  }

  if ($opt_h) {
    print "$file: <A HREF=\"$url\">$url</A>\n";
  } else {
    print "$file: $url\n";
  }
}

close(SORT);
__END__


=head1 NAME

B<bin/report.pl> - generate report based on link check results

=head1 SYNOPSIS

  bin/report.pl [-h] [-l logname] [-s sortpath]

=head1 DESCRIPTION

This Perl program generates a human digestable summary report of the
errors which arose in the specified link checking run, i.e. those
requests for which the response was not HTTP I<200> or equivalent.

The often cryptic response codes are translated into plain English
using the libwww-perl package, and the report is broken into sections,
each of which deals with the occurrences of a particular problem.

=head1 OPTIONS

=over 4

=item B<-h>

Use HTML formatting.

=item B<-l> I<logname>

The name of the file which contains the link checker session log.

=item B<-s> I<sortpath>

The location of a B<sort> program to use instead of the default.

=back

=head1 OUTPUT

List of link checker problems.

=head1 FILES

I<logs/lc> - log file created by link checker run.

=head1 DEPENDENCIES

The Unix sort program is used, as is the libwww-perl-5 package.  The
latter is also a dependency for the link checker itself.

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


