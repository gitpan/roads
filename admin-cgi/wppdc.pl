#!/usr/bin/perl
use lib "/home/roads2/lib";

# wppdc.pl - WWW based administration for LUT WHOIS++ server
#            (front ends bin/wppdc.pl)
# Author: Martin Hamilton <martinh@gnu.org>
#         Jon Knight <jon@net.lut.ac.uk>
# $Id: wppdc.pl,v 3.12 1998/08/18 19:24:45 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;
require "flush.pl";

use FileHandle;

# An collection of messages relating the tasks we undertake.
%MESSAGES = (
    'coldstart' =>
	"Starting WHOIS++ server on port $ROADS::WHOISPortNumber (coldstart).",
    'stop' =>
	"Shutting down the WHOIS++ server on port $ROADS::WHOISPortNumber.",
    'start' =>
	"Starting WHOIS++ server on port $ROADS::WHOISPortNumber.",
    'restart' =>
	"Restarting WHOIS++ server on port $ROADS::WHOISPortNumber.",
    'status' =>
	"Checking status of WHOIS++ server on port $ROADS::WHOISPortNumber.",
    'safetyfirst' =>
        "Starting WHOIS++ server on port $ROADS::WHOISPortNumber if not "
	     . "running already.",
    'UNKNOWN' =>
	"Unsupported operation.",
);

# Print out the HTTP Content-type header and then cleave the CGI URL into
# an associative array ready for use.
&cleaveargs;
&CheckUserAuth("wppdc_users");
print STDOUT "Content-type: text/html\n\n";

# Munge the operation being done.
$CGIvar{operation} = "UNKNOWN" unless 
    $CGIvar{operation} =~
      /^(coldstart|start|stop|status|restart|safetyfirst)$/;

# Output the (currently fixed) HTML header.
print STDOUT <<"EOF";
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>WHOIS++ server maintenance</TITLE>
</HEAD>
<BODY>
<H1>WHOIS++ server maintenance</H1>

$MESSAGES{$CGIvar{operation}}<P>
EOF

if ( (-e "$ROADS::Guts/wppd.pid" && !-w "$ROADS::Guts/wppd.pid")
  || (!-w "$ROADS::Guts") ) {

  print "Your WWW server doesn't have write access to:<P>\n<UL>\n";

  print "<LI> The temporary file <em>$ROADS::Guts/wppd.pid</em><P>\n"
    unless -w "$ROADS::Guts/wppd.pid";
  print "<LI> The ROADS internals directory <em>$ROADS::Guts</em><P>\n"
    unless -w "$ROADS::Guts";

  print "</UL>\n<STRONG>The WWW based WHOIS++ server administration tool\n";
  print "can't continue!</STRONG><P>\n";

  &WriteToErrorLogAndDie("$0","Can't write to files in $ROADS::Guts: $!\n");
}

$COUNT=0; # how many servers running?

$WPPPID = -1;
if (-f "$ROADS::Guts/wppd.pid") {
  if (open(PIDFILE, "$ROADS::Guts/wppd.pid")) {
    chomp($WPPPID = <PIDFILE>);
    close(PIDFILE);
  }
}

# Grab the name of the operation.
$OP = $CGIvar{operation};

# Kill the currently running WHOIS++ server if necessary.  Note that if we
# do issue a kill command, we also have to unlink the file containing the
# PID, otherwise the script will let you try to kill the same server over
# and over again.
if ($OP eq "stop" || $OP eq "restart") {
  if ($WPPPID ne -1) {
    print STDOUT "Stopping WHOIS++ server with process ID of $WPPPID... ";
    kill 9, $WPPPID;
    print STDOUT "done.\n";
    unlink("$ROADS::Guts/wppd.pid");
    $WPPPID = -1;
  } else {
    print STDOUT "No WHOIS++ server runnning?\n";
  }
}

# Find out what servers are running and output this information if the user
# is looking for status information.
print STDOUT "<LISTING>\n" if ($OP eq "status");
if (($OP eq "status") || ($OP eq "safetyfirst")) {
  chomp(@PS = `ps auwwx 2>/dev/null`);                      # BSD stylee
  chomp(@PS = `ps -eaf 2>/dev/null`) if $#PS == -1;         # ... or SysV

  foreach(@PS) {
    next unless /wppd\.pl/;
  
    $COUNT++ if $OP eq "safetyfirst";
  
    if ($OP eq "status") {
      print STDOUT "$_\n";
    }
  }
}
print STDOUT "</LISTING>\n" if ($OP eq "status");

# This section lets us start a new WHOIS++ server from the Web.  This is
# strange and weird magic because we fork twice to ensure that we don't
# leave zombies lying around and flush STDOUT before doing any forking
# to ensure that we don't get three copies of the STDOUT sent to the 
# HTTP daemon (we also need the flush and a close on STDOUT in the
# grandchild so that we don't have the daemon waiting for output that will
# never come).
if ($OP eq "start" || $OP eq "restart" ||
      ($OP eq "safetyfirst" && $COUNT == 0)) {
  flush(STDOUT);
  if($WPPPID eq -1) {
FORK1:
    if($pid = fork) {
      #parent here, child process ID in $pid
      print STDOUT "Started WHOIS++ server with process ID of $pid\n";
      waitpid($pid,0);
    } elsif(defined($pid)) { # $pid is zero if defined
      # child here
      undef($pid);
FORK2:
      if($pid = fork) {
        #child here, grandchild process ID in $pid
        sleep 2;
        exit;
      } elsif(defined($pid)) { # $pid is zero if defined
        # grandchild here
        setpgrp;
        sleep 1 until getppid == 1;
        close(STDOUT);
        exec "$ROADS::Bin/wppd.pl";
      } elsif($! =~ /No more process/) {
        # EAGAIN, supposedly recoverable fork error
        sleep(5);
        redo FORK2;
      } else {
        # weird fork error
        &WriteToErrorLogAndDie("$0","Can't fork: $!\n");
      }
    } elsif($! =~ /No more process/) {
      # EAGAIN, supposedly recoverable fork error
      sleep(5);
      redo FORK1;
    } else {
      # weird fork error
      &WriteToErrorLogAndDie("$0","Can't fork: $!\n");
    }
  } else {
    print STDOUT "There is already a WHOIS++ server runnning with ";
    print STDOUT "a process ID of $WPPPID.\n";
  }

}

# Output a (currently fixed) footer
print STDOUT <<"EOF";
<HR>
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EOF

# We're done!
close(STDOUT);
exit;
__END__


=head1 NAME

B<admin-cgi/wppdc.pl> - WWW front end to start LUT WHOIS++ server

=head1 SYNOPSIS

  admin-cgi/wppdc.pl

=head1 DESCRIPTION

This Perl program runs the LUT WHOIS++ server management program,
B<wppdc.pl>.

=head1 CGI VARIABLES

B<wppdc.pl> understands serveral options, as detailed below.  These
should be supplied in the CGI variable I<operation>.

=over 4

=item B<coldstart>

Start the WHOIS++ server from cold (e.g. when booting up), ignoring
any existing I<guts/wppd.pid> files.

=item B<restart>

Restarts the WHOIS++ server by stopping it, then starting it.

=item B<safetyfirst>

Restarts the WHOIS++ server, but not if it was running already.

=item B<start>

Starts the WHOIS++ server.

=item B<status>

Returns the status of the WHOIS++ server, if one is running.  This
is done by querying the results of I<ps>.

=item B<stop>

Stops the WHOIS++ server.

=back

=head1 OUTPUT

Short confirmation message, formatted in HTML.

=head1 FILES

I<guts/wppd.pid> - WHOIS++ server process ID is stored here

=head1 SEE ALSO

L<bin/wppdc.pl>

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

Martin Hamilton E<lt>martinh@gnu.orgE<gt>,
Jon Knight E<lt>jon@net.lut.ac.ukE<gt>

