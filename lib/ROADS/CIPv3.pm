#
# ROADS::CIPv3 - Library routines for generating and responding to 
#                CIPv3 requests.  These routines DO NOT deal with
#                the generation or interpretation of any specific
#                CIPv3 index MIME types - these require separate
#                modules.
#
# NOTE: This is based on the Internet Draft draft-ietf-find-cip-trans-00.txt
# ("CIP Transport Protocols") and is merely a proof of concept implementation.
# The protocol in the I-D can and probably will change and for that reason
# production services should stick to using the standardised WHOIS++
# centroids for use in ROADS index meshes.
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: CIPv3.pm,v 1.8 1998/12/09 17:42:02 martin Exp $

package ROADS::CIPv3;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(pollserver);

use Socket;
use Sys::Hostname;

#
# Subroutine to handle the CIPv3 polling in the wppd.pl
# The arguments are the reference to the file handle on which to read
# in the poll request (usually a socket) and the location of the ROADS
# index file that the CIP payload should be generated from.
#
sub ::CIPv3PollHandler {
  local($fh,$IafaSource,$TargetIndex) = @_;
  local($PollerVersionNumber,$PollerStartTime,$PollerEndTime,
        $PollerServerHandle,$PollerTypeOfPoll,$PollerPollScope,
        $PollerTemplate,$PollerField,$PollerHierarchy,$PollerDescription,
        $PollerHostName,$PollerHostPort,$PollerAuthenticationType,
        $PollerAuthenticationData,$EpochTime,$NowTime,$StartTime,$EndTime,
        $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst,$handle,
        $AuthStatus,$AuthType,$AuthData,$last_t,$last_f,$t,$a,$v,$h);

  # We need to have a DSI.  We'll create this from the Loughborough Dept.
  # Computer Studies Private Enterprise Number (registered with IANA),
  # 10 (for ROADS), the dotted quad of the IP address of the server and
  # the port number that this server is running on.
  $thisiaddr = gethostbyname($::ROADS::MyHostname); 
  $thisiaddr = inet_ntoa($thisiaddr);
  $OurDSI = "1.3.6.1.4.1.1828.10.".$thisiaddr.".$::ROADS::WHOISPortNumber";

  # Tell the client that we understand CIPv3
  print STDOUT "% 300  CIPv3 OK!\r\n";

  # Suck in the request.
  $request = "";
  $WantMoreParameters = 0;
  while(<$fh>) {
    last if $_ eq ".\r\n"; 
    if(/^\s*Content-type:\s*([\.\/\w]+);*\s*(.*)/i) {
      $ContentType = $1;
      $Parameters = $2;
      $Parameters =~ s/[\r\n]+//g;
      $WantMoreParameters = 1 if($Parameters =~ /;\s*$/);
      next;
    }
    if($WantMoreParameters) {
      $Parameters .= $_;
      $Parameters =~ s/[\r\n]+//g;
      $WantMoreParameters = 0;
      $WantMoreParameters = 1 if($Parameters =~ /;\s*$/);
      next;
    }
    next if(/^\s*Mime-Version:/i);
    next if($ContentType eq "");
    $Request .= $_;
  }

  # Check to see if the CIPv3 Request-Content type
  if($ContentType =~ /application\/index.cmd.(\w+)/) {
    $Command = lc($1);
    if($Command eq "noop") {
      print "% 200 MIME request received and processed\r\n";
      print "Mime-Version: 1.0\r\n";
      print "Content-type: application/index.response; code=200\n\r\n.\r\n";
    } elsif($Command eq "poll") {
      if($Parameters =~ /type="(.*?)"/i) {
        $Type = $1;
      } else {
        print "% 502 Request is missing required CIP attributes\r\n";
        print "Mime-Version: 1.0\r\n";
        print "Content-Type: application/index.response; code=502\n";
        print "\nRequest is missing required CIP attributes\n\r\n.\r\n";
        exit;
      }
      if($Parameters =~ /dsi="(.*?)"/i) {
        $WantedDSI = $1;
      } else {
        print "% 502 Request is missing required CIP attributes\r\n";
        print "Mime-Version: 1.0\r\n";
        print "Content-Type: application/index.response; code=502\n";
        print "\nRequest is missing required CIP attributes\n\r\n.\r\n";
        exit;
      }

      # We can only send some index data back if the DSI matches ours
      # (actually we should also check other ones that we hold so that
      # we can pass on and aggregate index objects that we've gathered
      # ourselves).    
      if($WantedDSI ne $OurDSI) {
        print "% 200 MIME request received and processed\r\n";
        print "Mime-Version: 1.0\r\n";
        print "Content-type: application/index.response; code=200\r\n";
        print "\r\nYou wanted DSI: $WantedDSI\r\n";
        print "We have DSI: $OurDSI\r\n";
        print "\r\n.\r\n";
        exit;  
      }

      if($Parameters =~ /base-uri="(.*?)"/i) {
        $BaseURI = $1;
      }

      $Type = lc($Type);
      if($Type eq "application/index.obj.tagged") {
        print "% 201 MIME request received and processed, output follows\r\n";
        print "Mime-Version: 1.0\r\n";
        print "Content-type: multipart/mixed; boundary=wibblywotsit\r\n";
        print "--wibblywotsit\r\n";
        print "Content-type: application/index.response; code=201\r\n";
        print "\r\n.\r\n";
        print "--wibblywotsit\r\n";
        print "Content-type: application/index.obj.tagged; \r\n";
        print "  dsi=$WantedDSI;\r\n";
        print "  base-uri=\"whoispp://$ROADS::MyHostname:"
             ."$ROADS::WHOISPortNumber/\"\r\n";

#        print "Type = $Type\r\nDSI = $WantedDSI\r\nBaseURI = $BaseURI\r\n";
#        print "\r\nRequest = $Request\r\n";

        opendir(OUTLINES,"$::ROADS::Config/outlines");
        @outlines = readdir(OUTLINES);
        closedir(OUTLINES);
        undef %HandleHash;
        $HandleCounter = 1;
        foreach $templatetype (@outlines) {
          next if($templatetype =~ /^\./);
          $UpdateTime = time;
          open(INDEX,"$::ROADS::Guts/index");
          $currentattr = "";
          $sendheader = 1;
          while($inline = <INDEX>) {
            $inline =~ /(.+):(.+):(.+):(.+)/;
            $thistt = $1;
            $thisattr = $2;
            $thisval = $3;
            $thishdl = $4;
            next if($templatetype ne $thistt);
            if($sendheader == 1) {
              print "version: x-tagged-index-1\r\nupdatetype: total\r\n";
              print "thisupdate: $UpdateTime\r\n\r\n\r\n";
              print "BEGIN IO-Schema\r\n";
              &OutputSchema($templatetype,"");
              print "END IO-Schema\r\nBEGIN Index-Info\r\n";
              $sendheader = 0;
            }
            if($currentattr ne $thisattr) {
              print "$thisattr:";
            } else {
              print "-";
            }
            $currentattr = $thisattr;
            $comma = "";
            foreach $handle (split(" ",$thishdl)) {
              if($HandleHash{$handle} == 0) {
                $HandleHash{$handle} = $HandleCounter++;
              }
              print "$comma$HandleHash{$handle}";
              $comma = ",";
            }
            print "/$thisval\r\n";
          }
          print "END Index-Info\r\n" if($sendheader == 0);
        }

        print "\r\n.\r\n";
        print "--wibblywotsit--\r\n";
        exit;
      }
      # If we get to this point, we don't support the index type
      # the poller asked for.
      print "% 200 Operation Successful - no output to return\r\n";
      print "Mime-Version: 1.0\r\n";
      print "Content-type: application/index.response; code=200\n\r\n.\r\n";
    } elsif ($Command eq "datachanged") {
      print "% 200 Operation Successful - no output to return\r\n";     
      print "Mime-Version: 1.0\r\n";  
      print "Content-type: application/index.response; code=200\n\r\n.\r\n";
    } else {
      print "% 500 Didn't understand the MIME request type\r\n";
      print "Mime-Version: 1.0\r\n";
      print "Content-type: application/index.response; code=500\n";
      print "\nDidn't understand the MIME request type\r\n.\r\n";
    }
  } else {
    print "% 500 Didn't understand the MIME request type\r\n";
    print "Mime-Version: 1.0\r\n";
    print "Content-type: application/index.response; code=500\n";
    print "\nDidn't understand the MIME request type\r\n.\r\n";
  }
  return;
}


sub OutputSchema {
  local($outline,$firstbit) = @_;
 
  local($newoutline,$attribute,$junk);

  local *OUTLINE;

  open(OUTLINE,"$::ROADS::Config/outlines/$outline");
    while(<OUTLINE>) {
    chomp;
    ($attribute,$junk) = split(":",$_,2);
    next if($attribute eq "");
    $attribute =~ s/-v\*//;
    if($attribute =~ /\((.+)\*\)/) {
      $newoutline = lc($1);
      $attribute =~ s/\(.+\*\)//;
      OutputSchema($newoutline,"$firstbit$attribute")
    } else {
      print "$firstbit$attribute:DNS\r\n";
    }
  }
  close(OUTLINE);
}

#
# Subroutine to poll a CIP v3 server
#
sub PollCIPv3Server {

}

#
# subroutine to send a request to a CIP v3 server
#
sub ::SendCIPv3Request {
    my($FD) = @_;

    $FD = "::$FD"; # The file descriptor is in the main package
    $line = <$FD>;
    $debug = $::debug;
    print $FD "# CIP-Version: 3\r\n";
    $line = <$FD>;
    warn "Got '$line' from CIPv3 server\n" if $debug;
    if($line =~ /^% 500/) {
        WriteToErrorLogAndDie("wppd",
          "Host $::PollTargetHostName\:$::PollTargetHostPort doesn't talk ".
            "CIP v3 - bailing out!");
        exit(0);
    }
    warn "Content-type: application/index.cmd.poll;type=\"$::CIPv3IndexType\";\r\n" if($debug);
    warn "  dsi=\"$::DSI\";\r\n" if($debug);
    warn "  base-uri=\"whoispp://$::PollTargetHostName\:$::PollTargetHostPort/\"\r\n" if($debug);
    warn "Mime-Version: 1.0\r\n" if($debug);
    warn ".\r\n" if($debug);

    print $FD "Content-type: application/index.cmd.poll;type=\"$::CIPv3IndexType\";\r\n";
    print $FD "  dsi=\"$::DSI\";\r\n";
    print $FD "  base-uri=\"whoispp://$::PollTargetHostName";
    print $FD ":$::PollTargetHostPort/\"\r\n";
    print $FD "Mime-Version: 1.0\r\n";
    print $FD ".\r\n";

}

#
# subroutine to read a response from a CIP v3 server
#
sub ::ReadCIPv3Response {
    my($FD) = @_;
    my $boundary;

    $debug = $::debug;
    $boundary = "";
    warn "In ReadCIPv3Response with DSI = $::DSI\n" if($debug);
    $FD = "::$FD"; # The file descriptor is in the main package
    $line = <$FD>;
    return if($line !~ /% 201/);
    warn "$line" if $debug;

    # Initialise any operations we need for the index
    &::InitialiseCentroid($::DSI,"FULL",
      $::PolleeStartTime,$::PolleeEndTime,$::PolleeCaseSensitive,
      $::PolleeAuthenticationType,$::PolleeAuthenticationData,
      $::PolleeCompressionType,$::PolleeSizeOfCompressedData);

#    while(<$FD>) { print $_; };exit;

    # Read in the outer MIME headers and pick up the boundary string.
    while($line = <$FD>) {
        last if($line =~ /^--$boundary[\r\n]+$/);
        warn $line if($debug);
        if ($line =~ /Content-type: multipart\/mixed; boundary=(.*)/i) {
            $boundary = $1;
            $boundary =~ s/[\r\n]+$//g;
            warn "Found a boundary of '$boundary'\n" if ($debug);
        }
    }
    # Read in MIME bodies
    while($line !~ /^--$boundary--[\r\n]+$/) {
        $ContentType = "";
        $request = "";
        $WantMoreParameters = 0;
        $Parameters = "";
        $InSchema = 0;
        $InIndexData = 0;
        $Skip = 0;
        while(($line = <$FD>) && ($line !~ /^--$boundary/)) {
          warn "\$line=$line" if $debug;
          next if($Skip);
          next if($line =~ /^\s*Mime-Version/);
          if ($line =~ /Content-type: ([a-zA-Z0-9\.\/]+)(.*)/i) {
              $ContentType = $1;
              $Parameters = $2;
              $Parameters =~ s/[\r\n]+//g;
              $WantMoreParameters = 1 if($Parameters =~ /;\s*$/);
              next;
        }
        if($WantMoreParameters) {
            $Parameters .= $line;
            $Parameters =~ s/[\r\n]+//g;
            $WantMoreParameters = 0;
            $WantMoreParameters = 1 if($Parameters =~ /;\s*$/);
            next;
        }
        if($ContentType ne "application/index.obj.tagged") {
            &::WriteToErrorLog("wig.pl","Got a Content-type of "
              ."'$ContentType' which I don't understand.");
            $Skip = 1;
            next;
        }
        if(!($InSchema || $InIndexData)) {
            warn "processing header line...\n";
            if($line =~ /^version:\s+([a-zA-Z0-9\-]+)[\r\n]+/) {
                $IndexVersion = $1;
                if($IndexVersion ne "x-tagged-index-1") {
                    &::WriteToErrorLog("wig.pl","Don't recognise the version "
                      ."'$IndexVersion' of the application/index.obj.tagged "
                      ."CIPv3 response.");
                    $Skip = 1;
                    next;
                }
            } elsif($line =~ /^updatetype:\s+(.*)[\r\n]+/) {
                $UpdateType = $1;
                next;
            } elsif($line =~ /^thisupdate:\s+(.*)[\r\n]+/) {
                $ThisUpdate = $1;
                next;
            } elsif($line =~ /^BEGIN IO-Schema/) {
                $InSchema = 1;
                next;
                exit;
            }
        } elsif($InSchema) {
            warn "processing schema line...\n" if $debug;
            if($line =~ /^END IO-Schema/) {
                $InSchema = 0;
                $InIndexData = 1;
                $templatetype = "UNKNOWN";
                open(INDEXTMP,">$ROADS::TmpDir/CIPdata.$$") ||
                  &::WriteToErrorLogAndDie("wig.pl",
                    "Can open file $ROADS::TmpDir/CIPdata.$$ : $!");
                next;
            }
        } elsif($InIndexData) {
            next if ($line =~ /^BEGIN Index-Info/);
            if($line =~ /^END Index-Info/) {
                $InIndexData = 0;
                close(INDEXTMP);
                &ProcessTaggedIndexObject($templatetype);
                next;
            }
            if($line =~ /template-type:[0-9\,]+\/([a-zA-Z]+)/) {
                $templatetype = $1;
            }
            print INDEXTMP $line;
         }
      }
      warn "Found end of body part with Content-type $ContentType\n"
        if($debug);
    }
    warn "Read in all MIME body parts\n" if ($debug);
    &::FinishCentroid($::DSI,"FULL",
      $::PolleeStartTime,$::PolleeEndTime,$::PolleeCaseSensitive,
      $::PolleeAuthenticationType,$::PolleeAuthenticationData,
      $::PolleeCompressionType,$::PolleeSizeOfCompressedData);

#    while(<$FD>) { print $_; }
   
}

#
# Subroutine to process an incoming CIPv3 application/index.obj.tagged index
# object into a more ROADS friendly centroid
#
sub ProcessTaggedIndexObject {
    my ($ThisTemplate) = @_;
    my $FieldName = "";
    my $tags = "";
    my @FieldData;

    warn "In ProcessTaggedIndexObject with DSI of $::DSI and Template-Type of $ThisTemplate\n";
    open(INDEXTMP,"$ROADS::TmpDir/CIPdata.$$");
    while($line = <INDEXTMP>) {
      chomp $line;
      if($line =~ /(.+):([0-9,]+)\/(.+)/) {
            if($FieldName ne "") {
                &::InsertCentroidTerms($::DSI,$ThisTemplate,
                  $FieldName,@FieldData);
            }
          $FieldName = $1;
          $tags = $2;
            $value = $3;
            $value =~ s/[\r\n]+//;
          @FieldData = ($value);
      }
        if($line =~ /\-([0-9,]+)\/(.+)/) {
            $tags = $1;
            $value = $2;
            $value =~ s/[\r\n]+//;
            @FieldData = (@FieldData, $value)
        }
    }
    close(INDEXTMP);

}

#
# Subroutine to authenticate a polling server
# 
# arguments are authentication type, authentication data and remote
#   indexing server's handle, as received in the request.
# returns 0 on failure, 1 on success.
# 
sub AuthenticatePoll {
  local($AuthType,$AuthData,$PollerHandle) = @_;

  # We currently don't do anything here - anyone can poll this server  
  return(1)
}


1;
__END__


=head1 NAME

ROADS::CIPv3 - A class to generate and process CIP centroids

=head1 SYNOPSIS

  use ROADS::CIPv3;
  # public methods
  CIPv3PollHandler (FD, $IafaSource, $TargetIndex);
  OutputSchema ($outline, $firstbit);
  SendCIPv3Request (FD);
  ReadCIPv3Response (FD);
  ProcessTaggedIndexObject ($ThisTemplate);

=head1 DESCRIPTION

This class implements support for generating Common Indexing Protocol
(version 3) style centroids from ROADS databases.  It uses some of the
code in the ROADS WHOIS++ centroid library module - see
L<ROADS::Centroid>.

=head1 METHODS

=over 4

=item CIPv3PollHandler ( FD, IafaSource, TargetIndex );

Handle the CIPv3 polling in the ROADS WHOIS++ server.  The arguments
are the reference to the file handle on which to read in the poll
request (usually a socket) and the location of the ROADS
index file that the CIP payload should be generated from.

=item OutputSchema ( outline, firstbit );

Used by I<CIPv3PollHandler> to dump out the CIP tagged index object
IO-Schema definition for a given object type.  The first parameter
is the ROADS object type we're interested in, and the second is
any prefix which should be applied at the start of the IO-Scheme
block in the resulting tagged index object.

=item SendCIPv3Request ( FD );

Sends a CIP poll request for the tagged index object type to the
CPI aware server connected via the file descriptor FD.

=item ReadCIPv3Response ( FD );

Reads a CIP tagged index object response from the CIP aware server
connected via the file descriptor FD.

=item ProcessTaggedIndexObject ( ThisTemplate );

Used by I<ReadCIPv3Response> to munges tagged index object into the
format used internally by the B<bin/wig.pl>.  This is passed separately
via a temporary file.  The parameter is the ROADS object type to use
when adding the terms from the tagged index object to server's centroid.

=back

=head1 SEE ALSO

L<Net::Centroid>, L<bin/wppd.pl>, RFC 1913, L<bin/wig.pl>

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

