#
# ROADS::Centroid - Library routines for generating and using centroids
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: Centroid.pm,v 3.5 1999/01/26 18:45:10 jon Exp $

package ROADS::Centroid;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(doreferrals PollCommand);

#
# Subroutine to check for referrals for the query
#
sub doreferrals {
  my($query) = @_;
  my($serverhandle,@serverstoask);
   
  opendir(WIGDIR,"$ROADS::Guts/wig");
  foreach $serverhandle (readdir(WIGDIR)) {
    next if ($serverhandle =~ /^\./);
    dbmopen(%CENTROID,"$ROADS::Guts/wig/$serverhandle/index.dbm",0644);
    @serverstoask = (@serverstoask, $serverhandle)
      if (&referrallookup($query));
    dbmclose(%CENTROID);
  }
  return(@serverstoask);
}  

#
# Subroutine to actually do a referral lookup
#
sub referrallookup {
  my($query) = @_;
  my($phrase,$replacement,$conjunction,$word); 
  my($origquery) = $query;
        
  while($query =~ /\"(.*?)\"/){
    $phrase = $1;
    $replacement = "";
    $conjunction = "";
    foreach $word (split(/\s+/,$phrase)) {
      if ($CENTROID{$word}) {
        $replacement .= "$conjunction\377";
      } else {
        $replacement .= "$conjunction\376";
      }
      $conjunction = "&";
    }
    $query =~ s/\".*?\"/\($replacement\)/;
  }
  while($query =~ /(\w+[\_\w+]+)/) {
    $phrase = $1;
    $replacement = "";
    $conjunction = "";
    foreach $word (split(/\_/,$phrase)) {
      if ($CENTROID{$word}) {
        $replacement .= "$conjunction\377";
      } else {
        $replacement .= "$conjunction\376";
      }
      $conjunction = "&";
    }
    $query =~ s/\w+[\_\w+]+/\($replacement\)/;
  }
  $query =~s/\w*?=(\w+)/$1/g;
    
  while($query =~ /([\w0-9]+)/) {
    $word = $1;
    if (defined($CENTROID{$word})) {
      $query =~ s/(\w+)/\377/;
    } else {
      $query =~ s/(\w+)/\376/;
    }
  }     
 
  $query =~ s/&/&&/g;
  $query =~ s/ /&&/g;
  $query =~ s/\|/||/g; 
  $query =~ s/\377/1/g;
  $query =~ s/\376/0/g;
  $query =~ s/[\$\%\@]//g; # Get rid of anything that could do something nasty
  return(eval($query));
} 

#
# Subroutine to handle the POLL command in the wppd.pl
# A single argument is the reference to the file handle on which to read
# in the poll request (usually a socket).
#
sub PollCommand {
  my($fh,$IafaSource,$TargetIndex) = @_;
  my($PollerVersionNumber,$PollerStartTime,$PollerEndTime,
        $PollerServerHandle,$PollerTypeOfPoll,$PollerPollScope,
        $PollerTemplate,$PollerField,$PollerHierarchy,$PollerDescription,
        $PollerHostName,$PollerHostPort,$PollerAuthenticationType,
        $PollerAuthenticationData,$EpochTime,$NowTime,$StartTime,$EndTime,
        $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst,$handle,
        $AuthStatus,$AuthType,$AuthData,$last_t,$last_f,$t,$a,$v,$h);

  while(<$fh>) {
    last if /^# END/; # gobble up poll request
    s/[\r\n]$//g;
    /^\s*Version-number:\s*(.*)/i && ($PollerVersionNumber = $1);
    /^\s*Start-Time:\s*([0-9]+)/i && ($PollerStartTime = $1);
    /^\s*End-Time:\s*([0-9]+)/i && ($PollerEndTime = $1);
    /^\s*Server-Handle:\s*(.*)/i && ($PollerServerHandle = $1);
    /^\s*Type-Of-Poll:\s*(.*)/i && ($PollerTypeOfPoll = $1);
    /^\s*Poll-Scope:\s*(.*)/i && ($PollerPollScope = $1);
    /^\s*Template:\s*(.*)/i && ($PollerTemplate = $1);
    /^\s*Field:\s*(.*)/i && ($PollerField = $1);
    /^\s*Hierarchy:\s*(.*)/i && ($PollerHierarchy = $1);
    /^\s*Description:\s*(.*)/i && ($PollerDescription = $1);
    /^\s*Host-Name:\s*(.*)/i && ($PollerHostName = $1);
    /^\s*Host-Port:\s*(.*)/i && ($PollerHostPort = $1);
    /^\s*Authentication-Type:\s*(.*)/i && ($PollerAuthenticationType = $1);
    /^\s*Authentication-Data:\s*(.*)/i && ($PollerAuthenticationData = $1);
  }
   
  # Check to make sure that we got all the REQUIRED parameters to the
  # request as per RFC1913
  if ($PollerVersionNumber eq "" || $PollerTypeOfPoll eq ""
    || $PollerPollScope eq "" || $PollerTemplate eq "" || $PollerField eq ""
    || $PollerServerHandle eq "" || $PollerHostName eq ""
    || $PollerHostPort eq "") {
    print <<EOF if $::debug;
% 204-ERROR DUMP\r
% 204-VersionNumber = $PollerVersionNumber\r
% 204-TypeOfPoll = $PollerTypeOfPoll\r
% 204-PollScope = $PollerPollScope\r
% 204-Template = $PollerTemplate\r
% 204-Field = $PollerField\r
% 204-ServerHandle = $PollerServerHandle\r
% 204-HostName = $PollerHostName\r
% 204 HostPort = $PollerHostPort\r
EOF
    print "% 503 Required attribute missing\r\n% 203 Bye\r\n";
    exit;
  }

  # Canonicalise and check some of the parameters
  $PollerTypeOfPoll =~ tr/a-z/A-Z/;
  if ($PollerTypeOfPoll ne "CENTROID" && $PollerTypeOfPoll ne "QUERY") {
    print "% 500 Syntax Error\r\n% 203 Bye\r\n";
    exit;
  }
  $PollerPollScope =~ tr/a-z/A-Z/ if ($PollerTypeOfPoll eq "CENTROID");
  if ($PollerTypeOfPoll eq "CENTROID" && ($PollerPollScope ne "FULL" &&
    $PollerPollScope ne "RELATIVE")) {
    print "% 500 Syntax Error\r\n% 203 Bye\r\n";
    exit;
  }
  
  # Check the authentication data for this poller
  ($AuthStatus, $AuthType,$AuthData) =
    &AuthenticatePoll($PollerAuthenticationType,$PollerAuthenticationData,
      $PollerServerHandle);
  if ($AuthStatus == 0) { 
    print "% 530 Authentication failed\r\n% 203 Bye\r\n";
    exit;
  }

  $EpochTime = "197001010000";
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
  $mon++;
  $year += 1900;
  $NowTime = sprintf("%04d%02d%02d%02d%02d",$year,$mon,$mday,$hour,$min);
   
  $StartTime = $PollerStartTime || $EpochTime;
  $EndTime = $PollerEndTime || $NowTime;
   
  print <<EOF ;
# CENTROID-CHANGES\r
 Version-number: 1.0\r
 Start-time: $StartTime\r
 End-time: $EndTime\r
 Case-Sensitive: FALSE\r
 Server-handle: $ROADS::Serverhandle\r
EOF

  # If we're interested in the change dates for the data we'd better
  # stat all the template files.
  if (($StartTime ne $EpochTime) || ($EndTime ne $NowTime)) {
    opendir(TMPLDIR,$IafaSource);
    while($handle = readdir(TMPLDIR)) {
      next if ($handle =~ /^\./);
      chomp($handle);
      $TemplateStat{$handle} = (stat("$ROADS::IafaSource/$handle"))[9];   
      ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        gmtime($TemplateStat{$handle});
      $mon++;
      $year += 1900;
      $TemplateStat{$handle} = sprintf("%04d%02d%02d%02d%02d",
        $year,$mon,$mday,$hour,$min);
  
      print "% 204 stat for $handle = $TemplateStat{$handle}\r\n" if $::debug;
    }
    closedir(TMPLDIR);
  }
  if (open(INDEX, $TargetIndex)) {
    $last_t = $last_f = "";
    while(<INDEX>) {
      chomp;
      ($t,$a,$v,$h) = split /:/;
      if (($StartTime ne $EpochTime) || ($EndTime ne $NowTime)) {
        $doit = 0;
        foreach $handle (split(" ",$h)) {
          if (($StartTime <= $TemplateStat{$handle})
            && ($EndTime >= $TemplateStat{$handle})) {
            print "% 204 $handle: $StartTime <= $TemplateStat{$handle} " .
              "<= $EndTime\n" if $debug;
            $doit = 1;
            last;
          }
        }
        next if ($doit == 0);
      }
      if ($t ne $last_t) {
        if ($last_t ne "") {
          print "# END TEMPLATE\r\n";
        }
        $last_t = $t;
        print "# BEGIN TEMPLATE\r\n";
        print " Template: $t\r\nAny-Field: FALSE\r\n";
      }
      if ($a ne $last_a) {
        if ($last_a ne "") {
          print "# END FIELD\r\n";
        }
        $last_a = $a; 
        print "# BEGIN FIELD\r\n";
        print " Field: $a\r\n";
        print " Data: $v\r\n";
        next;
      }
      print "-$v\r\n";
    }
    close(INDEX); 
    print "# END FIELD\r\n";
    print "# END TEMPLATE\r\n";
  }
  print "# END CENTROID-CHANGES\r\n";
  return;
}

#
# Subroutine to authenticate a polling server
# 
# arguments are authentication type, authentication data and remote
#   indexing server's handle, as received in the request.
# returns 0 on failure, 1 on success.
# 
sub AuthenticatePoll {
  my($AuthType,$AuthData,$PollerHandle) = @_;

  # We currently don't do anything here - anyone can poll this server  
  return(1)
}


1;
__END__


=head1 NAME

ROADS::Centroid - A class to generate and process centroids

=head1 SYNOPSIS

  use ROADS::Centroid;
  # public methods
  @servers_to_ask = doreferrals("sex and drugs");
  PollCommand(FILEHANDLE, "/roads/source", "/roads/guts/index");
  # private methods
  if (ROADS::Centroid::referrallookup("sex and drugs")) { ... }
  ROADS::Centroid::AuthenticatePoll("FULL", "foobar", "yourserverhandle");

=head1 DESCRIPTION

This class implements support for generating RFC 1913 style centroids
from ROADS databases and for doing referral lookups within a collection
of centroids.

=head1 METHODS

=over 4

=item @servers_to_ask = doreferrals("sex and drugs");

Given a query, this method checks any available centroids for servers
which can satisfy it.  A list of these servers' handles is returned
as the result.  I<referrallookup> is called behind the scenes for
each centroid.

=item PollCommand( FILEHANDLE, "/roads/source", "/roads/guts/index" );

This method is used to process an incoming request (via FILEHANDLE)
for a poll of a ROADS database, and generates an RFC 1913 style centroid
using the ROADS templates and index specified in the second and third
arguments respectively.  The centroid is returned on STDOUT.

=item referrallookup("sex and drugs")

This method is used to perform the actual check for a given query in a
given centroid.

=item AuthenticatePoll( "FULL", "foobar", "yourserverhandle" );

Process authentication information in the poll request.  The first 
argument is the poll type, the second is the authentication data
(e.g. clear text password) and the third is the server handle of
the polling server.  This routine is called behind the scenes by
I<PollCommand>.

=back

=head1 BUGS

The referral lookup code only lets you search across all of the centroids
which are available - it should let you specify just certain servers'
centroids and ideally all centroids except those from certain servers.

The authentication code is a NOOP - but the ROADS WHOIS++ server has its
own access control list mechanism based on ip addresses / domain names /
password protection.  We should also be passing the authentication type
as well, though only "password" (clear text passwords) has been defined
so far.

I<PollCommand> assumes that it should be sending its output on STDOUT,
which isn't necessarily a good thing.

=head1 SEE ALSO

L<bin/wppd.pl>, RFC 1913, L<bin/wig.pl>

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

