#!/usr/bin/perl
use lib "/home/roads2/lib";

# wppdc.pl - remote control for WHOIS++ server 

# Author: Martin Hamilton <martinh@gnu.org>
# $Id: wppdc.pl,v 3.10 1998/08/18 19:31:28 martin Exp $

require ROADS;
use ROADS::ErrorLogging;

die "usage: $0: <coldstart|status|restart|start|stop|safetyfirst>\n" unless
  $ARGV[0] =~ /^(coldstart|status|restart|start|stop|safetyfirst)$/i;

($OP = $ARGV[0]) =~ tr/[A-Z]/[a-z]/;

if ( (-e "$ROADS::Guts/wppd.pid" && !-w "$ROADS::Guts/wppd.pid")
  || (!-w "$ROADS::Guts") ) {

  print "You don't have write access to:\n\n";

  print "  . The temporary file '$ROADS::Guts/wppd.pid'\n"
    unless -w "$ROADS::Guts/wppd.pid";
  print "  . The ROADS internals directory '$ROADS::Guts'\n"
    unless -w "$ROADS::Guts";

  print "\nThe WHOIS++ server administration tool can't continue!\n";

  &WriteToErrorLogAndDie("$0","Can't write to files in $ROADS::Guts: $!\n");
}

$COUNT=0; # how many servers running?

unlink "$ROADS::Guts/wppd.pid" if $OP eq "coldstart";

if (-f "$ROADS::Guts/wppd.pid") {
  if (open(PIDFILE, "$ROADS::Guts/wppd.pid")) {
    chomp($WPPPID = <PIDFILE>);
    close(PIDFILE);
  } else {
    $WPPPID = -1;
  }
}

if ($OP eq "stop" || $OP eq "restart") {
  if ($WPPPID ne -1) {
    print "Stopping... $WPPPID\n";
    kill 9, $WPPPID;
  } else {
    print "No WHOIS++ server runnning ?\n";
  }
}

if ($OP eq "status") {
  chomp(@PS = `ps auwwx 2>/dev/null`);                      # BSD stylee
  chomp(@PS = `ps -eaf 2>/dev/null`) if $#PS == -1;         # ... or SysV

  foreach(@PS) {
    next unless /wppd\.pl/;
  
    $COUNT++ if $OP eq "safetyfirst";
  
    if ($OP eq "status") {
      print "$_\n";
      next;
    }
  }
}

if ($OP eq "coldstart" || $OP eq "start" || $OP eq "restart" ||
      ($OP eq "safetyfirst" && $COUNT == 0)) {
  print "Starting WHOIS++ server on port $ROADS::WHOISPortNumber\n";
  unless (fork) {
    # I am child
    unless (fork) {
      # I am grandchild
      sleep 1 until getppid == 1;
      exec "$ROADS::Bin/wppd.pl";
    }
    exit; # first child exits quickly
  }
  wait; # parent waits for first child
}

exit;
__END__


=head1 NAME

B<bin/wppdc.pl> - control B<wppd.pl> WHOIS++ server

=head1 SYNOPSIS

  bin/wppdc.pl [coldstart|status|restart|start|stop|safetyfirst]

=head1 DESCRIPTION

This program lets you drive your LUT WHOIS++ server by remote control,
making it possible to have it automatically restarted, shutdown and so
on from things like cron jobs and WWW CGI programs.

=head1 OPTIONS

There is only one option, which is the operation to be performed.
This may be one of the following:

=over 4

=item B<coldstart>

Start from scratch, ignoring any I<wppd.pid> status files which might
be present in the ROADS I<guts> directory.

=item B<status>

Dump out some status information about any LUT WHOIS++ servers which
happen to be running

=item B<restart>

Restart any WHOIS++ servers which happen to be running.  This consists
of a I<stop> followed by a I<start>.

=item B<start>

Start the LUT WHOIS++ server.

=item B<stop>

Stop any LUT WHOIS++ servers which happen to be running.

=item B<safetyfirst>

Start a new WHOIS++ server if there don't appear to be any running
already.

=back

=head1 BUGS/CAVEATS

This program uses the B<ps> command to find out what processes are
running.  The options this program takes and the results it produces
typically vary quite a bit between different versions of Unix.  If you
find that this program fails on your system, please get in touch so
that we can fix it!

=head1 SEE ALSO

L<bin/wppd.pl>, L<admin-cgi/wppdc.pl>

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

