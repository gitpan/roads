#!/usr/bin/perl
use lib "/home/roads2/lib";

# harvest_centroid.pl - extract centroid from collection of SOIF records,
#                       Harvest Gatherer or Broker
# Uses Berkeley DB package B-trees as a backend database [valkenburg@terena.nl]

# Author: Martin Hamilton <martinh@gnu.org>
#         Peter Valkenburg <valkenburg@terena.nl>
# $Id: harvest_centroid.pl,v 3.1 1998/11/27 19:40:49 martin Exp $

use Getopt::Std;
use POSIX;
use Socket;

# This needs Perl 5 with Berkeley DB support (DB_File package).
use DB_File;
$BTREE = new DB_File::BTREEINFO;
# NOTE: a memory cache is used; actual memory may be > 4x this size
$BTREE->{'cachesize'} =  8 * 1024 * 1024;	# advise 8 Mb memory cache

getopts("dh:p:s:t:");

$debug = $opt_d;
$tmpdb = "$opt_t" ? "$opt_t$$.db" : undef;

# phase 0 - if necessary, fetch the centroid from a Gatherer/Broker

if ($opt_h) {
  warn "0: Connecting to broker/gatherer to fetch centroid...\n" if $debug;

  $port = $opt_p || 8501; # assume we're talking to Broker on def. port
  $server = $opt_h || "localhost";
  # if they don't give us a serverhandle, try and synthesize one
  if ($opt_s) {
    $serverhandle = $opt_s;
  } elsif ($server) {
    $serverhandle = $server;
    $serverhandle =~ tr/[A-Za-z0-9-]//dc;
  } else {
    $serverhandle = "dummy";
  }

  socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
  $sin = sockaddr_in($port, inet_aton("$server"));
  unless (connect(SOCK, $sin)) {
    die "$0: Couldn't connect to $server, port $port: $!";
  } 
  $X = select(SOCK); $| = 1; select($X);

  chop($banner = <SOCK>);
  warn "0: $server:$port said '$banner'\n" if $debug;
  if ($banner =~ /^200 - .*Broker/i) {
    $server_type = "broker"; 
    warn "0: we think it's a Broker\n" if $debug;
    print SOCK "#BULK #SINCE 0 #END #ALLB\r\n";
  } elsif ($banner =~ /^000 - HELLO/i) {
    $server_type = "gatherer";
    warn "0: we think it's a Gatherer\n" if $debug;
    print SOCK "SEND-UPDATE 0\r\n";
  }

  $FIN = *SOCK;
} else {
  $server_type = "file";
  $FIN = *STDIN;
}


# phase 1 - create hash array based on attribute value pairs in the
#           harvest SOIF database

# Use Berkeley DB BTREE implementation for an in-memory or on-disk database.
# This will keep the keys sorted, which saves ordering them afterwards
tie (%HASH, "DB_File", $tmpdb, O_RDWR|O_CREAT, 0600, $BTREE)
  || die ("Cannot open temporary db '$tmpdb' for centroid: $!");

warn "1: Reading centroid...\n" if $debug;

# variables for mapping attribute names to sequence numbers and vice versa
$attr_cnt = 0;
@attr_vec;
%attr_seq;

while (<$FIN>) {
  chop;
  next if /^}$/;
  next if /^$/;
  next if /^[04]00/;
  next if /^\@(FILE|DELETE|REFRESH|UPDATE)\s*{/;
  last if /^(099|499)/;


  if (/^([^{]+){(\d+)}:\t(.*)/) {
    $attribute = $1; $value_length = $2; $early_value = $3;
    $attribute =~ tr [a-z] [A-z];
  
    $the_rest_length = $value_length - length($early_value);
    if ($the_rest_length < 0) {				# skip bad records
      warn "1: skipping bad record (negative length)\n" if $debug;
      next;
    }
    read $FIN, $the_rest, $the_rest_length;

    next if
      $attribute =~ /^(md5|url-references|update-time|last-modification-time)/i;

    $the_rest =~ s/[\r\n]/ /gm;
    foreach $term (split(/\W+/, "$early_value $the_rest")) {
      next unless $term;

      # we use an attribute sequence number for storage, rather than a full name
      unless (exists $attr_seq{"$attribute"}) {
	$attr_seq{"$attribute"} = $attr_cnt;
	$attr_vec[$attr_cnt] = "$attribute";
	$attr_cnt++;
      }

      unless (exists $HASH{"$attr_seq{$attribute}:$term"}) {
        $HASH{"$attr_seq{$attribute}:$term"} = "";
        warn "1: added $attribute: $term\n" if $debug;
      }
    }
  }
}

if ($server_type eq "gatherer") {
  print $FIN "QUIT\r\n"; # we need to say "bye bye" to Gatherers
}
close($FIN);

# phase 2 - dump out our centroid based on this info

warn "2: Dumping out completed centroid...\n" if $debug;

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
$mon++;
$year += 1900;
$NowTime = sprintf("%04d%02d%02d%02d%02d",$year,$mon,$mday,$hour,$min);

print <<EOF;
# CENTROID-CHANGES\r
 Version-number: 1.0\r
 Start-time: 000000000000\r
 End-time: $NowTime\r
 Case-Sensitive: TRUE\r
 Server-handle: $serverhandle\r
# BEGIN TEMPLATE\r
 Template: SOIF\r
 Any-Field: TRUE\r
EOF

while (($key, $value) = each %HASH) {
  ($key_seq, $key_term) = split (':', $key);
  $key_attribute = $attr_vec[$key_seq];
  if ($old_attribute ne $key_attribute) {
    print "# END FIELD\r\n" if $old_attribute;
    $old_attribute = $key_attribute;
    print "# BEGIN FIELD\r\n Field: $key_attribute\r\n Data: ";
  }
  else {
    next unless $key_term;
    print "-";
  }
  print "$key_term\r\n"; 
}
print "# END FIELD\r\n" if $key_attribute;

print "# END TEMPLATE\r\n";
print "# END CENTROID-CHANGES\r\n";

# untie %HASH;
unlink "$tmpdb" if $tmpdb;		# unlink database file

warn "3: Done!\n" if $debug;
exit;
__END__


=head1 NAME

B<bin/harvest_centroid.pl> - extract centroid from SOIF or Harvest Broker/Gatherer

=head1 SYNOPSIS

  bin/harvest_centroid.pl [-d] [-t tmpdb] [-h host] [-p port] [-s serverhandle]

=head1 DESCRIPTION

This program tries to extract a WHOIS++ compatible centroid from one
of the following :-

=over 4

=item A Harvest Broker

=item A Harvest Gatherer

=item A collection of SOIF templates

=back

If invoked with a host name or IP address to contact, this program
will try to establish whether it is talking to a Harvest Gatherer
or Broker, and send the appropriate command to fetch a dump of the
entire contents of the Gatherer or Broker's database.

With no B<-h> argument, this program will expect to receive a
collection of SOIF templates on STDIN, such as you could get by

  gzip -dc /usr/local/harvest/gatherers/*/All-Templates.gz

or

  gdbmutil dump /usr/local/harvest/gatherers/*/PRODUCTION.gdbm

Note that when generating a centroid from a flat file collection of
SOIF templates, the B<-s> argument should be used to specify a
serverhandle for the resulting centroid.

A Berkeley DB database is used as temporary working storage - your
Perl installation must support DB via the B<DB_File> module.

=head1 OPTIONS

=over 4

=item B<-d>

Turn on debugging output - very verbose!

=item B<-t> I<tmpdb>

The path prefix of the temporary database for building the
centroid.  The size of this database is typically three
times that of the final centroid.

=item B<-h> I<host>

The host name or IP address of the server to contact, if talking
to a Gatherer or a Broker

=item B<-p> I<port>

The port number to use when connecting to a Gatherer or a Broker.
This defaults to 8501 if not set, which is Harvest's default for
a Broker when it's created.

=item B<-s> I<serverhandle>

=back

=head1 BUGS

We should let people specify the starting time for the poll, and
pass this on to the Broker/Gatherer, so that it's possible to do
a relative "poll" of the Harvest server.

We don't do anything special about character sets/encodings.

Not up to date with current CIP specifications - this is really
intended for use with a WHOIS++ server which speaks the old RFC
1913 indexing protocol.

Should be integrated with B<wpp_shim.pl>, so that WHOIS++ servers
which cannot load a centroid from a flat file can think they're
polling a WHOIS++ server - when in fact the shim would simply be
returning a centroid which had been calculated already.

=head1 SEE ALSO

L<bin/harvest_shim.pl>, RFC 1913

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
Peter Valkenburg E<lt>valkenburg@terena.nlE<gt>
