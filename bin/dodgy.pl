#!/usr/bin/perl
use lib "/home/roads2/lib";

# dodgy.pl - find templates which have been stale for the last three 
# visits from the link checker
# 
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: dodgy.pl,v 3.9 1998/08/18 19:31:28 martin Exp $

use Getopt::Std;
getopts("l:n:");

require ROADS;
use ROADS::ErrorLogging;

$LOGFILE = $opt_l || "$ROADS::Logs/lc";
$NUMBER = $opt_n || 3;

unless (-f "$LOGFILE" && -f "$LOGFILE.0" && -f "$LOGFILE.1") {
  &WriteToErrorLogAndDie("dodgy",
    "not enough log files, or logfiles not readable");
  exit;
}

foreach $logfile ("$LOGFILE", "$LOGFILE.0", "$LOGFILE.1") {
  open(LOG, "$logfile")
    || &WriteToErrorLogAndDie("dodgy",
         "couldn't open path to log file $logfile: $!");
  
  while(<LOG>) {
    chomp;
    next if /^200/;
    ($code, $file, $url) = split;

    if ($COUNT{"$file"}) {
      $COUNT{"$file"} += 1;
    } else {
      $COUNT{"$file"} = 1;
    }
  }
  close(LOG);
}

foreach $bogy (keys %COUNT) {
  next unless $COUNT{"$bogy"} >= $NUMBER;
  print "$bogy\n";
}

exit 0;
__END__


=head1 NAME

B<bin/dodgy.pl> - find persistently stale templates

=head1 SYNOPSIS

  bin/dodgy.pl [-l basename] [-n grace]
 
=head1 DESCRIPTION

This Perl program analyses the results of the last three runs of the
ROADS link checking tool, and returns a list of the templates which
have been unreachable at least a given number of times.

It is intended for invocation from the likes of a World-Wide Web CGI
program, a cron job, an at job.  Another tool has been written to take
the results of this program and modify the actual templates so as to
remove them from the portion of the ROADS server's database which is
visible to the end user.

=head1 OPTIONS

=over 4

=item B<-l> I<basename>

This is the path to the link checker log files.  By default it is
assumed to be the I<lc> file in the ROADS logs directory.  A different
number is appended for each log run - I<lc>, I<lc.0>, I<lc.1> and so
on.

=item B<-n> I<grace>

This is the amount of "grace" to allow before removing templates,
e.g. to flag templates when two sessions out of three are bad:

  -n 2

=back

=head1 OUTPUT

List of filenames for the templates which have been persistently
unreachable.

=head1 SEE ALSO

L<admin-cgi/dodgy.pl>

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

