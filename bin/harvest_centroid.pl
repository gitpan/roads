#!/usr/bin/perl
use lib "/home/roads2/lib";

# harvest_centroid.pl - extract centroid from collection of SOIF records,
#                       Harvest Gatherer or Broker

# Author: Martin Hamilton <martinh@gnu.org>
# $Id: harvest_centroid.pl,v 3.0 1998/08/18 20:29:07 martin Exp $

use Getopt::Std;
use POSIX;
use Socket;

getopts("dh:p:s:");

$debug = $opt_d;

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

warn "1: Reading centroid...\n" if $debug;

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
    read $FIN, $the_rest, $the_rest_length;

    next if
      $attribute =~ /^(md5|url-references|update-time|last-modification-time)/i;

    $the_rest =~ s/[\r\n]/ /gm;
    foreach $term (split(/\W+/, "$early_value $the_rest")) {
      unless ($HASH{"$attribute"}{"$term"}) {
        $HASH{"$attribute"}{"$term"} = 1;
        warn "1: added HASH{$attribute}{$term}\n" if $debug;
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
 Case-Sensitive: FALSE\r
 Server-handle: $serverhandle\r
# BEGIN TEMPLATE\r
 Template: SOIF\r
 Field: Any-Field\r
EOF

foreach $key_attribute (sort keys %HASH) {
  $line = 0;
  print "# BEGIN FIELD\nField-Name: $key_attribute\nValue: ";
  foreach $key_term (sort keys %{ $HASH{"$key_attribute"} }) {
    next if $key_term =~ /^$/;
    print "-" unless $line eq 0;
    $line++;
    print "$key_term\r\n"; 
  }
  print "# END FIELD\r\n";
}
print "# END TEMPLATE\r\n";
print "# END CENTROID-CHANGES\r\n";

warn "3: Done!\n" if $debug;
exit;
__END__


=head1 NAME

B<bin/harvest_centroid.pl> - extract centroid from SOIF or Harvest Broker/Gatherer

=head1 SYNOPSIS

  bin/harvest_centroid.pl [-d] [-h host] [-p port] [-s serverhandle]

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

=head1 OPTIONS

=over 4

=item B<-d>

Turn on debugging output - very verbose!

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

