#!/usr/bin/perl
use lib "/home/roads2/lib";

#
# wig.pl - The WHOIS++ Index Gatherer
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: wig.pl,v 3.9 1998/11/27 19:37:50 martin Exp $
#

require ROADS;
use ROADS::ErrorLogging;
use ROADS::CIPv3;

use Socket;
use POSIX;
use Getopt::Std;
# Handle command line parameters
getopts('d');
$debug = $opt_d; # Debugging switch

# Serverhandle - the (hopefully globally unique) short name of our server
$serverhandle = "$ROADS::Serverhandle" || "me";

# Use our server's port number as the default for the remote server
$PollTargetHostPort = $ROADS::WHOISPortNumber;

# Default to CENTROID type of poll
$PollTypeOfPoll = "CENTROID";

# Default to ALL templates
$PollTemplate = "ALL";

# Default to ALL fields
$PollField = "ALL";

# Handle of target pollee server
$PollSpecFilename = shift;

# Whether or not to use CIPv3 protocol processing (default of no).
$UseCIPv3 = 0;

# Read in the appropriate polling spec file
&ReadPollSpecFile();

# Open communications link to remote server
if ($InsertFile) {
  open(FD, "$InsertFile") || die "$0: couldn't open centroid: $!";
} else {
  &StartTalking($PollTargetHostName, $PollTargetHostPort);

  if($UseCIPv3) {
    warn "About to send a CIPv3 request.\n" if $debug;
    &SendCIPv3Request($InsertFile ? FD : SOCK);
  } else {
    # Send out the request
    print SOCK <<"EndOfDump";
# POLL 
 Version-number: 1.0
 Type-of-poll: $PollTypeOfPoll
 Poll-Scope: $PollPollScope
 Template: $PollTemplate
 Field: $PollField
 Server-handle: $ROADS::Serverhandle
 Host-Name: $ROADS::MyHostname
 Host-Port: $ROADS::WHOISPortNumber
EndOfDump

    print SOCK " Start-time: $PollStartTime\n" if ($PollStartTime ne "");
    print SOCK " End-Time: $PollEndTime\n" if ($PollEndTime ne "");
    print SOCK " Hierarchy: $PollHierarchy\n" if ($PollHierarchy ne "");
    print SOCK " Description: $PollDescription\n" if ($PollDescription ne "");
    if ($PollAuthenticationType ne "") {
      print SOCK " Authentication-type: $PollAuthenticationType\n";
      print SOCK " Authentication-data: $PollAuthenticationData\n";
    }
    print SOCK "# END\n";
  }
}

# Get back the result from pollee
if($UseCIPv3) {
  warn "Wait to receive a CIPv3 response.\n" if $debug;
  &ReadCIPv3Response($InsertFile ? FD : SOCK);
  warn "Got a CIPv3 response.\n" if $debug;
} else {
  &ReadPolleeResponse($InsertFile ? FD : SOCK);
}
exit;

#
# Subroutine to set up a socket so that we can talk to the remote server
#
sub StartTalking {
  local($host,$port) =  @_;
  local($junk,$ouraddr,$theiraddr);

  warn("Attemping to talk to host '$host' on port '$port'...\n") if $debug;
  socket(SOCK,PF_INET,SOCK_STREAM,getprotobyname('tcp'))
    || &WriteToErrorLogAndDie("wig.pl", "couldn't get socket: $!");
  $sin = sockaddr_in($port,inet_aton("$host"));
  &WriteToErrorLogAndDie("wig.pl", "connect failed: $!") 
    unless connect(SOCK,$sin);
  $X = select(SOCK); $| = 1; select($X);
  warn("Socket set OK.\n") if $debug;
}

#
# Subroutine to read in the Polling Specification file for the desired
# target pollee server.
#
sub ReadPollSpecFile {
  &WriteToErrorLogAndDie("wig.pl",
    "No polling spec file called '$PollSpecFilename'\n")
    unless (open(POLLSPEC,"$ROADS::Config/wig/$PollSpecFilename"));
  while(<POLLSPEC>){
    next if (/^#/);
    chomp;
    if (/^CIPv3:\s*/i) {
      $UseCIPv3 = 1;
    } elsif (/^DSI:\s*(.*)/i) {
      $DSI = $1;
    } elsif (/^Index-Type:\s*(.*)/i) {
      $CIPv3IndexType = $1;
    } elsif (/^Host-Name:\s*(.*)/i) {
      $PollTargetHostName = $1;
    } elsif (/^Host-Port:\s*(.*)/i) {
      $PollTargetHostPort = $1;
    } elsif (/^Type-of-poll:\s*(.*)/i) {
      $PollTypeOfPoll = $1;
      $PollTypeOfPoll =~ tr/a-z/A-Z/;
      &WriteToErrorLogAndDie("wig.pl",
        "Type of poll '$PollTypeOfPoll' not understood\n" . 
        "Must be CENTROID or QUERY\n")
        if ($PollTypeOfPoll ne "CENTROID" && $PollTypeOfPoll ne "QUERY");
    } elsif (/^Poll-scope:\s*(.*)/i) {
      $PollPollScope = $1;
    } elsif (/^Start-Time:\s*(.*)/i) {
      $PollStartTime = $1;
    } elsif (/^End-Time:\s*(.*)/i) {
      $PollEndTime = $1;
    } elsif (/^Template:\s*(.*)/i) {
      $PollTemplate = $1;
    } elsif (/^Field:\s*(.*)/i) {
      $PollField = $1;
    } elsif (/^Hierarchy:\s*(.*)/i) {
      $PollHierarchy = $1;
      &WriteToErrorLogAndDie("wig.pl",
        "Hierarchy '$PollHierarchy' not understood - must be " .
        "Topology, Geographical or Administrative\n")
        if ($PollHierarchy ne "Topology" && $PollHierarchy ne "Geographical"
        && $PollHierarchy ne "Administrative");
    } elsif (/^Description:\s*(.*)/i) {
      $PollDescription = $1;
    } elsif (/^Authentication-Type:\s*(.*)/i) {
      $PollAuthenticationType = $1;
    } elsif (/^Authentication-Data:\s*(.*)/i) {
      $PollAuthenticationData = $1;
    } elsif (/^Insert-file:\s(.*)/i) {
      $InsertFile = $1;
    }
  }

  # Die if the spec file didn't specify a host name of the pollee
  &WriteToErrorLogAndDie("wig.pl",
    "No target hostname in poll spec file for server '$TargetServerHandle'\n")
    if ($PollTargetHostName eq "");

  # Default to FULL poll scope if not specifed and using CENTROID poll type
  $PollPollScope = "FULL" 
    if ($PollPollScope eq "" && $PollTypeOfPoll eq "CENTROID");

  $PollPollScope =~ tr/a-z/A-Z/ if ($PollTypeOfPoll eq "CENTROID");

  # Die if the poll scope doesn't match up with the poll type
  &WriteToErrorLogAndDie("wig.pl",
    "Poll scope '$PollPollScope' not valid with Poll Type '$PollTypeOfPoll'\n")
    if ($PollTypeOfPoll eq "CENTROID" && 
      ($PollPollScope ne "FULL" && $PollPollScope ne "RELATIVE"));

  # If we're doing CIPv3 make sure the index type, etc is filled in
  if($UseCIPv3) {
    if($CIPv3IndexType eq "") {
      $CIPv3IndexType = "application/index.obj.tagged";
    }
  }
}

sub ReadPolleeResponse {
  my($FD) = @_;

  # Some handy defaults
  $PolleeOperation = "FULL";

  # Wait for the start of the centroid change data 
  while(<$FD>) {
    s/[\r\n]$//g;
    print STDERR "$_\n" if $debug;
    last if (/^#\s*CENTROID-CHANGES/);
    exit if (/^%\s+503/);
  }

  &WriteToErrorLogAndDie("wig.pl",
  "Can't get centroids from '$PollTargetHostName', port '$PollTargetHostPort'\n") 
    if(eof($FD));

  # Read in the centroid change header.
  while(<$FD>) {
    s/[\r\n]$//g;
    print STDERR "$_\n" if $debug;
    /^# BEGIN TEMPLATE/i && last;
    /Version-number:\s*(.*)/i && ($PolleeVersionNumber = $1);
    /Start-time:\s*(.*)/i && ($PolleeStartTime = $1);
    /End-time:\s*(.*)/i && ($PolleeEndTime = $1);
    /Server-handle:\s*(.*)/i && ($PolleeServerHandle = $1);
    /Case-sensitive:\s*(.*)/i && ($PolleeCaseSensitive = $1);
    /Authentication-type:\s*(.*)/i && ($PolleeAuthenticationType = $1);
    /Authentication-data:\s*(.*)/i && ($PolleeAuthenticationData = $1);
    /Compression-type:\s*(.*)/i && ($PolleeCompressionType = $1);
    /Size-of-compressed-data:\s*(.*)/i && ($PolleeSizeOfCompressedData = $1);
    /Operation:\s*(.*)/i && ($PolleeOperation = $1) =~ tr/a-z/A-Z/;
  }

  # Checks to make sure that the centroid header was valid
  if ($PolleeVersionNumber != "1.0") {
    &WriteToErrorLog("wig.pl",
      "Got an unrecognised Version number of '$PolleeVersionNumber'\n");
    $PolleeVersionNumber = "1.0";
  } elsif ($PolleeStartTime eq "") {
    &WriteToErrorLog("wig.pl",
      "Missing a start time in the response\n");
    $PolleeStartTime = "000000000000";
  } elsif ($PolleeEndTime eq "") {
    &WriteToErrorLog("wig.pl",
      "Missing an end time in the response\n");
    $PolleeStartTime = "000000000000";
  } elsif ($PolleeServerHandle eq "") {
    &WriteToErrorLog("wig.pl",
      "Misssing a server handle in the response\n");
    $PolleeServerHandle = "me";
  } elsif (($PolleeOperation ne "ADD") && ($PolleeOperation ne "DELETE")
	  && ($PolleeOperation ne "FULL")) {
    &WriteToErrorLog("wig.pl",
      "Operation received was '$PolleeOperation'; must be ADD, DELETE or FULL\n");
    $PolleeOperation = "FULL";
  }

  # Initialise any operations we need for the index
  &InitialiseCentroid($PolleeServerHandle,$PolleeOperation,$PolleeStartTime,
    $PolleeEndTime,$PolleeCaseSensitive,$PolleeAuthenticationType,
    $PolleeAuthenticationData,$PolleeCompressionType,
    $PolleeSizeOfCompressedData);

  # OK, now read in the centroids themselves
  while(<$FD>) {
    last if (/^#\s*END CENTROID-CHANGES/i);
    next if (/^#\s*BEGIN TEMPLATE/i);
    s/[\r\n]$//g;
    print STDERR "$_\n" if $debug;
    if (/^\s*Template:\s*(.*)/) {
	($ThisTemplate = $1) =~ tr/A-Z/a-z/;
    } else {
        &WriteToErrorLogAndDie("wig.pl",
	  "Expecting 'Template: BLAH', got $_\n");
    }
    $_=<$FD>;
    s/[\r\n]$//g;
    print STDERR "$_\n" if $debug;
    if (/^\s*Any-field:\s*(.*)/i) {
	($AnyField = $1) =~ tr/A-Z/a-z/;
    } else {
        &WriteToErrorLogAndDie("wig.pl",
	  "Expecting 'Any-field: BLAH', got $_\n");
    }

    while(<$FD>) {
      last if (/^#\s*END TEMPLATE/i);
      s/[\r\n]$//g;
      print STDERR "$_\n" if $debug;
      if (/^#\s*BEGIN FIELD/i) {
        $FieldName = "";
      } elsif (/^#\s*END FIELD/i) {
        if ($FieldName eq "") {
          &WriteToErrorLogAndDie("wig.pl",
            "No field name in centroid data at line $. ... $_\n");
        }
        if ($PolleeOperation eq "DELETE") {
          &RemoveCentroidTerms($PolleeServerHandle,$ThisTemplate,$FieldName,
            @FieldData);
        } else {
          &InsertCentroidTerms($PolleeServerHandle,$ThisTemplate,$FieldName,
            @FieldData);
        }
      } else {
        /^\s+Field:\s*(.*)/i && (($FieldName = $1) =~ tr/A-Z/a-z/);
        /^\s+Data:\s*(.*)/i && (@FieldData = ($1));
        # /^\-(.*)/ && (@FieldData = (@FieldData, $1));
        /^\-(.*)/ && (push @FieldData, $1);     # use push() for efficiency
      }
    }
  }

  # Do any operations we need to finish off the new centroid index
  &FinishCentroid($PolleeServerHandle,$PolleeOperation,$PolleeStartTime,
    $PolleeEndTime,$PolleeCaseSensitive,$PolleeAuthenticationType,
    $PolleeAuthenticationData,$PolleeCompressionType,
    $PolleeSizeOfCompressedData);
}

#
# Subroutine to remove terms from a centroid index
#
sub RemoveCentroidTerms {
  local($handle,$template,$field,@data) = @_;
  open(OLDINDEXFILE,"$ROADS::TmpDir/$handle.idx.$$");
  open(NEWINDEXFILE,">$ROADS::TmpDir/$handle.idx.new.$$");
  while(<OLDINDEXFILE>) {
    chomp;
    ($oldtemplate,$oldfield,$term) = split(":",$_);
    next if (grep($term,@data) && $oldtemplate eq $template && 
      $oldfield eq $field);
    print NEWINDEXFILE "$oldtemplate:$oldfield:$term\n";
  }
  close(NEWINDEXFILE);
  close(OLDINDEXFILE);
  rename("$ROADS::TmpDir/$handle.idx.new.$$","$ROADS::TmpDir/$handle.idx.$$")
}

#
# Subroutine to insert terms into a centroid index
#
sub InsertCentroidTerms {
  local($handle,$template,$field,@data) = @_;
  local($term);

  print ">>>> In InsertCentroidTerms...\n" if $debug;
  open(INDEXFILE,">>$ROADS::TmpDir/$handle.idx.$$");
  foreach $term (@data) {
    print INDEXFILE "$template:$field:$term\n";
  }
  close(INDEXFILE);
}

#
# Subroutine to initialise the centroid index ready for inserting/deleting
# centroid terms.
#
sub InitialiseCentroid {

  local($ServerHandle,$Operation,$StartTime,$EndTime,$CaseSensitive,
    $AuthenticationType, $AuthenticationData,$CompressionType,
    $SizeOfCompressedData) = @_;
  warn "In IntialiseCentroid\n" if($debug);

  # Make sure that there's a directory for this server's details:
  mkdir("$ROADS::Guts/wig/",0755) unless (-d "$ROADS::Guts/wig/");
  mkdir("$ROADS::Guts/wig/$ServerHandle",0755) 
    unless (-d "$ROADS::Guts/wig/$ServerHandle") ;

  # If we're inserting into or deleting from an existing index, make a copy
  # of it to work on in the temporary directory.
  if ($Operation ne "FULL") {
    system($ROADS::CpPath,"$ROADS::Guts/wig/$ServerHandle/centroids.idx",
      "$ROADS::TmpDir/$ServerHandle.idx.$$");
  }
}

#
# Subroutine to finish off the centroid index 
#
sub FinishCentroid {

  local($ServerHandle,$Operation,$StartTime,$EndTime,$CaseSensitive,
    $AuthenticationType, $AuthenticationData,$CompressionType,
    $SizeOfCompressedData) = @_;

  warn "In FinishCentroid\n" if($debug);
  # Generate a DBM offset index into the text file
  dbmopen(%DBMINDEX,"$ROADS::Guts/wig/$ServerHandle/index.dbm",0644);
  undef %DBMINDEX;
  system("$ROADS::SortPath -t: -u $ROADS::TmpDir/$ServerHandle.idx.$$ > $ROADS::TmpDir/new.$$");
  rename("$ROADS::TmpDir/new.$$","$ROADS::TmpDir/$ServerHandle.idx.$$");
  $indexpos = 0;
  open(INDEXFILE,"$ROADS::TmpDir/$ServerHandle.idx.$$");
  while(<INDEXFILE>) {
    chomp;
    ($oldtemplate,$oldfield,$term) = split(":",$_);
    $term =~ tr/A-Z/a-z/;
    unless(defined $DBMINDEX{"$term"}) {
      $DBMINDEX{"$term"} = $indexpos;
    } else {
      $donotadd = 0;
      foreach $oldpos (split(",",$DBMINDEX{"$term"})) {
        if ($oldpos == $indexpos) {
          $donotadd = 1;
          last;
        }
      }
      $DBMINDEX{"$term"} .= ",$indexpos" unless ($donotadd);
    }
    $indexpos = $indexpos+length("$oldtemplate:$oldfield:$term\n");
  }
  close(INDEXFILE);
  dbmclose(DBMINDEX);

  # Copy, errr, MOVE the new index into the normal place  
  system($ROADS::MvPath, "$ROADS::TmpDir/$ServerHandle.idx.$$",
    "$ROADS::Guts/wig/$ServerHandle/centroids.idx");

}
__END__


=head1 NAME

B<bin/wig.pl> - gather indexes (centroids)

=head1 SYNOPSIS

  bin/wig.pl [-d] spec_file

=head1 DESCRIPTION

The B<wig.pl> program is used to gather WHOIS++ index and Common
Indexing Protocol (CIP) centroids from remote servers.  Its is intended
to be run either from the command line or, more likely, from B<cron>
periodically.  It implements the protocol described in RFC 1913, and
the client side of the Common Indexing Protocol.  Please note that at
the time of writing, CIP was still under development by the IETF's FIND
working group.  Please let us know if you find any interoperability
problems.

The upshot is that B<wig.pl> lets you configure your ROADS WHOIS++
server to grab the database indexes from other people's WHOIS++ and CIP
aware servers, e.g.  CNIDR's Iknow and Bunyip's Digger.  When a search
performed on your server matches information in one or more of these
indexes, the client will be returned a "referral" to the relevant server
or servers.  The ROADS WWW based WHOIS++ client, B<search.pl>, will
automatically follow these referrals and search the indexed WHOIS++
servers in addition to your own.

=head1 OPTIONS

=over 4

=item B<-d>

Enter debug mode (only of interest to developers and during debugging)

=back

=head1 FILES

I<config/wig/*> - index gatherer specification files

I<guts/wig/*> - per-server centroids

Note that the config file name in I<config/wig> should both be the same
as the indexed server's WHOIS++ server handle.  This is the "Serverhandle"
parameter in I<lib/ROADS.pm>.  Each server you index must have a unique
server handle.

=head1 FILE FORMATS

=over 4

=item SPECIFICATION FILES

B<wig.pl> is configured at run time by specifying the name of an
indexing specification file.  This filename is mandatory and it is
assumed to be a file within the I<config/wig> directory.  Each line in
the specification file contains either a comment (indicated by a hash
character at the start of the line) or a configuration directive,
followed by a colon and whitespace and then the value for that
directive.  valid directives are:

=over 4

=item I<Host-Name>

The hostname of the machine that is to be polled for a centroid.  A
specification file must contain the hostname of the remote server

=item I<Host-Port>

The port number of the remote server that is to be polled.  By default
this is assumed to be the same as the port number of the local ROADS
WHOIS++ server.

=item I<Type-of-poll>

The type of poll to perform.  This can either be CENTROID or QUERY.  By
default it is CENTROID.

=item I<Poll-scope>

For a QUERY type-of-poll the directive specifies the WHOIS++ style
search string to send to the remote server.  For CENTROID
type-of-poll, it can take on two values: FULL or RELATIVE.  A FULL
poll-scope means that the FULL centroid should be return (taking into
accound the Start-Time and End-Time still) whereas RELATIVE means that
the centroid returned should contain any changes since the last poll
by this index server.  The default for a CENTROID type-of-poll is
FULL.

=item I<Start-Time>

The time before which we're not interested in changed centroid
details.  The default is empty (ie no constraint on the start time).

=item I<End-Time>

The time after which we're not interested in changed centroid details.
This directive and Start-Time allow a selective subset of the remote
servers centroid to be returned based on when the underlying data
changed.  The default is empty (ie no constraint on the end time).

=item I<Template>

The name of the template from which the centroids should be generated,
or the special value ALL.  ALL means consider all templates on the
remote server.  The default is ALL.

=item I<Field>

The list of names of fields that are of interest in the centroid, or
the special value ALL.  ALL means consider all fields within the
specified template(s) when generating the centroid.  The default value
is ALL.

=item I<Hierarchy>

Specifies this machine's relation to the remote server.  This
directive can take one of three values: Topology, Geographical or
Administrative (note that these are case sensitive).  Topology means
that this index server is indexing the remote server because of its
place in the network topology, Geographical means that it is indexing
the remote server because of their respective geographical locations
and Administrative means that the indexing is taking place because of
an administrative decision.  The default value is Administrative.

=item I<Description>

A free text description of this index gatherer (or its related WHOIS++
server that makes use of the centroids it gathers) which the remote
server can use when asked to describe the servers that index it.
There is no default value for this directive.

=item I<Authentication-Type>

This directive specifies the type of authentication to supply to the
remote server.  Common values are NONE (for no authentication) and
Password (for a simple plaintext password exchange).  RFC 1913 does
not specify any others but any value that is understood by the remote
server can be entered in this directive.  There is no default value
for this directive.

=item I<Authentication-Data>

This directive's value is used inconjunction with the
Authentication-Type directive to pass the actual password, key or
other data required for this index server to be authenticated to the
remote server.  There is no default value for this directive.

=item I<CIP-v3>

The presence of this directive (its value doesn't actually matter)
indicates that the remote server should be polled using the Common
Indexing Protocol, rather than the standard WHOIS++ centroids
mechanism.

=item I<Index-Type>

Sets the CIP index type - by default we use the tagged index object,
"application/index.obj.tagged".

=item I<DSI>

For CIP polls, this corresponds to the Data Set Identifier of the
server being polled.  For ROADS we construct these by appending the
(remote!) server's IP address and port number to the Loughborough
University Department of Computer Studies enterprise identifier.  In
the SOSIG example below, e.g.

  1.3.6.1.4.1.1828.10.198.168.254.252.8237

=back

=item CENTROIDS

The output of the B<wig.pl> program is held in the I<guts/wig>
directory.  In this directory a subdirectory named after the remote
server's handle will be generated.  In the subdirectory, an index file
generated from the returned centroid(s) will be created, along with a
DBM database file used to rapidly locate items within the file.  The
format of each line of the index file is:

  template:oldfield:term

The DBM file is keyed on the terms and the associated values are a
list of offsets into the main index file that match that term.  The
DBM file must be regenerated every time the main index file is
changed.

=back

=head1 EXAMPLE

To cross search the WHOIS++ server running on sosig.ac.uk, the Social
Science Information Gateway at the University of Bristol, you would
create the file I<config/wig/sosigacuk01>.  As a bare minimum, this
file would need to contain the host name of the server to contact,
but in practice you will probably want to include the following:

  Host-Name: sosig.ac.uk
  Host-Port: 8237
  Description: Muppet Gateway; lets put on makeup and light up lights.

It's typically necessary for you to contact the remote server's
administrator at this stage, because most WHOIS++ implementations
will only let you index a server if you've been given permission to
by its administrator.  The ROADS WHOIS++ server uses an access
control list based on the file I<config/hostsallow>, and comes with
some default settings which let the ROADS developers index your
server by default.  To add a new machine, we recommend that you
put both its domain name and IP address into I<config/hostsallow>,
e.g.

  bork.swedish-chef.org: poll
  198.168.254.252: poll

Once this has been done, the ROADS WHOIS++ server will automatically
allow the machine doing the indexing to "poll" it for centroids.
Now all you need to do at the local end is run B<wig.pl>, e.g.

  bin/wig.pl sosigacuk01

If the index is successful, subsequent searches of your server will
result in the centroid from SOSIG also being searched, and referrals
being returned for any matches in this.

=head1 SEE ALSO

L<wppd.pl>

=head1 BUGS

If you want to set up an index server which has no local data of its
own, you'll still need to build the main ROADS index, e.g. with
B<bin/mkinv.pl>.  It's debatable whether this is a bug or a feature!

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

