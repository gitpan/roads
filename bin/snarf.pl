#!/usr/bin/perl
use lib "/home/roads2/lib";

# snarf.pl - search WHOIS++ server and return list of handles
#
# Author: Martin Hamilton <martinh@gnu.org>
#         Jon Knight <jon@net.lut.ac.uk>
# $Id: snarf.pl,v 3.2 1998/08/18 19:31:28 martin Exp $

use Getopt::Std;
use Socket;

# Handle command line parameters
getopts('dflp:');

require ROADS;

#
# Main code
#
$debug = $opt_d;
$port = $opt_p || $ROADS::WHOISPortNumber || 63;

if ($ARGV[0] eq "" || $ARGV[1] eq "") {
  die "$0: usage: [-d] [-f] [-l] [-p port] server query";
}

$server = $ARGV[0];
$query = $ARGV[1];

if ($opt_f) {
  if ($query =~ /:/) {
    $query .= ";format=full";
  } else {
    $query .= ":format=full";
  }
} else {
  if ($query =~ /:/) {
    $query .= ";format=handle";
  } else {
    $query .= ":format=handle";
  }
}

if ($debug) {
  $query .= ";debug";
  warn "Searching host $server, port $port with query $query\n";
}

socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
$sin = sockaddr_in($port, inet_aton("$server"));
unless (connect(SOCK, $sin)) {
  warn "Couldn't connect to $server port $port: $!" if $debug;
  exit(-1);
} 
$X = select(SOCK); $| = 1; select($X);
print SOCK "$query\r\n";

$line="";
$contents = "";
while($buffer = <SOCK>) {
  warn $buffer if($debug);
  next if($buffer =~ /^%/);
  $contents .= $buffer;  
  $buffer =~ s/[\r\n]+//g;
#  next unless $buffer =~ /^# HANDLE/i;
  if($buffer eq "" && $opt_f) {
    if($contents ne "") {
      print $contents
    }
    $contents = "";
  }
  if($buffer =~ /^# HANDLE/i) {
    $buffer =~ s/.* ([^ ]+)$/$1/;
    if ($opt_l) {
      $line .= "$buffer ";
    } else {
      print "$buffer\n";
    }
    next;
  }
}
if ($opt_l) {
  $line =~ s/ $//;
  print "$line\n";
}
close(SOCK);

exit;
__END__


=head1 NAME

B<bin/snarf.pl> - do a WHOIS++ search and snarf the resulting handles

=head1 SYNOPSIS

  bin/snarf.pl [-dfl] [-p port] server query

=head1 DESCRIPTION

The B<snarf.pl> program performs a WHOIS++ search on the specified
server and returns a list of the matching handles on a line by line
basis.  Note that the search must be structured as per the WHOIS++
query syntax defined in RFC 1835, the WHOIS++ protocol specification.

If the search was performed successfully, B<snarf.pl> returns 0,
otherwise it returns -1.

=head1 OPTIONS

=over 4

=item B<-d>

Turn on debugging output

=item B<-f>

Dump out the full records

=item B<-l>

Dump results out on one line, suitable for use as parameters to
another program

=item B<-p> I<port>

Specify port number, default is your ROADS WHOIS++ server's port
number, or 63

=back

=head1 SEE ALSO

L<cgi-bin/search.pl>, L<bin/wppd.pl>

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

