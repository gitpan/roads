#!/usr/bin/perl
use lib "/home/roads2/lib";

# lc.pl - WWW front end to the link checker tool
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: lc.pl,v 3.14 1998/08/18 19:24:45 martin Exp $

use Getopt::Std;
use POSIX;
getopts('b:l:s:');

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
require "flush.pl";

$bindir = $opt_b || $ROADS::Bin;
$logdir = $opt_l || $ROADS::Logs;
$sourcedir = $opt_s || $ROADS::IafaSource;

# Print out the HTTP Content-type header and then cleave the CGI URL into
# an associative array ready for use.
&cleaveargs;
&CheckUserAuth("lc_users");
print "Content-type: text/html\n\n";

unless ($CGIvar{oktorun} eq "yes") {
    print <<EOF;
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>ROADS link checker</TITLE>
</HEAD>
<BODY>
<H1>ROADS link checker</H1>

Checking the links in your ROADS database may take some time, and use
up a lot of network bandwidth.  If you still want to go ahead, tick
the check box below and submit the form.<P>

<FORM ACTION="/$ROADS::WWWAdminCgi/lc.pl" METHOD="GET">
Yes, I really mean it <INPUT TYPE="checkbox" NAME="oktorun" VALUE="yes"><BR>
<INPUT TYPE="submit" VALUE="Do link check">
</FORM>
<HR>
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EOF
    exit;
}

$LOG = "$logdir/lc";

-f "$LOG.6" && (rename("$LOG.6", "$LOG.7"));
-f "$LOG.5" && (rename("$LOG.5", "$LOG.6"));
-f "$LOG.4" && (rename("$LOG.4", "$LOG.5"));
-f "$LOG.3" && (rename("$LOG.3", "$LOG.4"));
-f "$LOG.2" && (rename("$LOG.2", "$LOG.3"));
-f "$LOG.1" && (rename("$LOG.1", "$LOG.2"));
-f "$LOG.0" && (rename("$LOG.0", "$LOG.1"));
-f "$LOG" && (rename("$LOG", "$LOG.0"));

if ($ROADS::DBAdminEmail eq $ROADS::SysAdminEmail) {
    $emailto = "<EM>$ROADS::DBAdminEmail</EM>"
} else {
    $emailto = "<EM>$ROADS::DBAdminEmail</EM> and "
	. "<EM>$ROADS::SysAdminEmail</EM>";
}

$|=0;
print <<EOF;
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>ROADS link checker</TITLE>
</HEAD>
<BODY>
<H1>ROADS link checker</H1>

The link checking tool has been launched as a background process<P>

$emailto will be sent email when it has finished<P>
<HR>
EOF

flush(STDOUT);
FORK1:
if($pid = fork) {
  #parent here, child process ID in $pid
  waitpid($pid,0);
} elsif(defined($pid)) { # $pid is zero if defined
  # child here
   undef($pid);
FORK2:
  if($pid = fork) {
    #child here, grandchild process ID in $pid
    print STDOUT "Launched background link checker with process ID of $pid\n<P>";
    close(STDOUT);
    exit;
  } elsif(defined($pid)) { # $pid is zero if defined
    # grandchild here
    close(STDOUT);
    close(STDERR);
    POSIX::setsid;
    while ($count < 100 && getppid != 1) {
      sleep 1;
      $count++;
    } 
    exec "$bindir/bg_lc.pl";
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
  
print STDOUT <<EOF;
<HR>
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EOF

flush(STDOUT);

# We're done!
close(STDOUT);
exit;
__END__


=head1 NAME

B<admin-cgi/lc.pl> - WWW front end to the link checker tool

=head1 SYNOPSIS

  admin-cgi/lc.pl [-b bindir] [-l logdir] [-s sourcedir]
 
=head1 DESCRIPTION

This Perl program runs the ROADS link checker tool B<lc.pl> as a
background process.  It also recycles any existing link checker logs
- keeping the last 8 for auditing purposes.

The latest link checker log is saved in the ROADS log directory as
F<lc>.

=head1 OPTIONS

These options are intended for debugging use only

=over 4

=item B<-b> I<bindir>

Alternative ROADS I<bin> directory, to look for the link checker in.

=item B<-l> I<logdir>

Alternative log directory.

=item B<-s> I<sourcedir>

Alternative source directory, where the ROADS templates may be found.

=back

=head1 OUTPUT

Mail to the ROADS server maintainers.

=head1 SEE ALSO

L<bin/lc.pl>

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


