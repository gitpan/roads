#!/usr/bin/perl
use lib "/home/roads2/lib";

use Getopt::Std;
use Socket;
getopts("h:p:");

# harvest_shim.pl - gateway WHOIS++ queries to Harvest Broker
#
# Author: Peter Valkenburg <valkenburg@terena.nl>
#         Jon Knight <jon@net.lut.ac.uk>
#         Martin Hamilton <martinh@gnu.org>
# $Id: harvest_shim.pl,v 3.4 1998/09/05 14:00:05 martin Exp $

# Added support for CHIC search profile (valkenburg@terena.nl):
# 1. Boolean operators, with grouping delimited by ()'s:
#   AND, OR, NOT and grouping are supported by virtue of the fact that
#   Harvest is assumed to understand the same syntax as whois++ (phew,
#   that was easy)
# 2. Fielded searches:
#   Search terms of the form `attribute-name=value' are rewritten into
#   the Harvest `"attribute-name=value"' format (note the quotes);
#   note: in order to be able to arbitrate between a whois++ command
#   and a search string that happens to start with a word that is also
#   a command, the 'VALUE=' search term specifier recognised, along
#   with the other required specifiers (TEMPLATE, HANDLE, SEACH-ALL);
#   it is left to the client to avoid naive sending of user queries
#   that start with a system command, i.e., COMMANDS, CONSTRAINTS,
#   DESCRIBE, ? / HELP, LIST, POLLED-BY, POLLED-FOR, SHOW, VERSION
# 3. Literal searches:
#   literals are supported by quoting values that contain quoted blanks:
#      hello\ there
#   is rewritten for Harvest into
#      "hello\ there"
#   NOTE: strings surrounded by quotes are not supported by whois++ and
#   should be handled by the client by passing them to this shim without
#   quotes; the following characters should be `\' quoted (as per RFC1835):
#   space, tab, `=', `,', `:', `;', `\', `*', `.', `)', '(', `[', `]', `^'
# 4. Constraints:
#   a. case sensitive searches:
#      this is implemented as the whois++ global constraint CASE=consider
#      (already built into version 3.0 of this shim)
#   b. search matching of a complete word or a prefix (lstring):
#      implemented as whois++ local constraints `SEARCH=exact' and
#      `SEARCH=lstring' of which the first is (imperfectly) implemented by
#      using Harvest's `#index matchword' option, assuming Glimpse as the
#      search engine; an lstring search actually results in a substring
#      search in Glimpse
#   c. maximum number of hits returned:
#      supported by passing on the global constraint `MAXHITS=n' to
#      the Harvest Broker as the '#index maxfiles n' option
#   d. multiple queries on the same connection:
#      the whois++ hold constraint is supported to allow clients to keep
#      an open TCP connection to this shim.
# 5. Returned attributes:
#   A basic set of SOIF attributes is extracted from the Harvest Broker
#   FILE records and returned as whois++ attribute/value pairs:
#       uri
#       title
#       author
#       description            - typically identical to title :-(
#       last-modification-time - time of last change on local filesystem
#       file-size              - in bytes (we hope)
#       type                   - e.g., "HTML", "postscript", etc.
#       md5                    - checksum; useful for removing dups
#   This set of attributes should do for the presentation of matched
#   records; it should probably be rewritten to a Dublin Core template
#   a la I-D draft-ietf-asid-whois-schema-03.txt.
#
# In all, this is *nearly* a minimal RFC1835 compliant server.  Problems:
#  - incorrect interpretation of local constraints as global constraints
#  - unreliable support of search=lstring (lstring is interpreted as a
#    substring search when Glimpse is used as the Broker search engine)
#  - most search engines (e.g., Glimpse) do not assume words to be
#    separated by white space only, but RFC1835 does seem to require that
#  - there is no support for searching for template names
#  - MD5 checksums are used as (almost unique) handles

$server = $opt_h || "localhost";
$port = $opt_p || "8501";

$serverhandle = "$server/$port";      # Using `:' is probably not RFC1835-ish
$serverhandle =~ tr/a-z/A-Z/;         # caps to make it look impressive :)

$X = select(STDOUT); $| = 1; select($X);
print "% 220 LUT WHOIS++/Harvest shim for broker at $server/$port ready\r\n";

# SOIF attributes to retrieve from Harvest Broker
$attributes .= " #attribute title";
$attributes .= " #attribute author";
$attributes .= " #attribute description";  # typically identical to title :-(
$attributes .= " #attribute last-modification-time";
$attributes .= " #attribute file-size";    # in bytes (we hope)
$attributes .= " #attribute type";         # e.g., "HTML", "postscript", etc.
$attributes .= " #attribute md5";          # checksum; useful for removing dups
# $attributes .= " #attribute partial-text"; # abstract of postscript, text etc.

HOLD:   # a goto? YES!!!

unless ($query = $ENV{'QUERY_STRING'}) {
  # if we're not a ROADS WGI WHOIS++ backend, say hi and be queried:
  chop($query = <STDIN>);
}

# Global constraints MAXHITS, CASE, SEARCH are dealt with here..
$maxhits = $default_maxhits = 20;    # default MAXHITS=20
if ($query =~ /[^\\]:.*maxhits=([0-9]+)/i) {
  $maxhits = $1;
}
# We ask the Broker for an extra hit to detect exceeding MAXHITS
$maxfiles = "#index maxfiles ".($maxhits + 1);

$case = "";                          # default CASE=ignore
if ($query =~ /[^\\]:.*case=consider/i) {
  $case = "#index case sensitive";
}

$matchword = "#index matchword";     # default SEARCH=exact
if ($query =~ /[^\\]:.*search=lstring/i) {
  $matchword = "";
}

$hold = 0;                           # default is not to hold connection open
if ($query =~ /[^\\]:.*hold/i) {
  $hold = 1;
}

$query =~ s/([^\\]):.*/$1/; # trim off global constraints

# Do system commands
if ($query =~ /^(CONSTRAINTS|DESCRIBE|COMMANDS|POLLED-BY|POLLED-FOR|VERSION|LIST|SHOW|HELP|\?|POLL)($|\s+)(.*)/i) {
  print "% 200 Command OK\r\n";
  &system_command($1,$3);
  print "% 226 Transaction complete\r\n";
  goto HOLD if ($hold);
  print "% 203 Time for Tubbybyebye!\r\n";
  exit;
}

$to_send = "";

$query =~ s/([^\\]) *(;) */$1$2/g;    # delete extra spaces around `;'
$query =~ s/(^|[^\\])([)(])/$1 $2 /g; # insert spaces around grouping brackets
$query =~ s/(^|[^\\])\s+/$1\n/g;      # rewrite to prepare splitting into terms
foreach $term (split(/[\n\r]+/, $query)) {
  next unless $term;

  if ($term =~ /[^\\];.*search=lstring/i) {  # handle local SEARCH constraint
    print "% 111 Warning: lstring constraint is applied to all terms\r\n";
    print "% 111 Warning: lstring constraint may result in substring search \r\n";
    $matchword = "";
  }
  if ($term =~ /[^\\];.*case=consider/i) {   # handle local CASE constraint
    print "% 111 Warning: case consider constraint is applied to all terms\r\n";
    $case = "#index case sensitive";
  }
  $term =~ s/([^\\]);.*/$1/;                 # strip local constraints from term

  if ($term =~ /^(!|HANDLE=)(.*)/i) { # search for handles by MD5 attribute
    $term = "md5=$2";
    $term =~ tr/A-Z/a-z/;
  }
  if ($term =~ /^TEMPLATE=(.*)/i) {   # catch searching for template names
    print "% 111 Warning: cannot constrain search to template names\r\n";
    $term = $1;
  }
  if ($term =~ /^SEARCH-ALL=(.*)/i) { # `deal' with searching for anything
    $term = $1;
  }
  if ($term =~ /^VALUE=(.*)/i) {      # dump VALUE specifier, if any
    $term = $1;
  }

  if ($term !~ /^(\(|\)|and|or|not)$/i) {
    $term =~ s/(.*)/"$1"/;                   # quote search term
  }

  $to_send .= " $term";
}
$to_send = "#USER $attributes $maxfiles $matchword $case #END$to_send";
# $to_send = "#USER #opaque #desc $case #END$to_send";

print "% 200 OK, going for it...\r\n";
socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
$sin = sockaddr_in($port, inet_aton("$server"));
unless (connect(SOCK, $sin)) {
  print "% 500 Couldn't connect to Broker on $server, port $port: $!\r\n";
  print "% 203 Time for Tubbybyebye!\r\n";
  exit(-1);
} 
$X = select(SOCK); $| = 1; select($X);
print SOCK "$to_send\r\n";

print "% 220 Done search for $to_send\r\n";
$record = "";
$handle = "?";
$trailchars = 0; $attrname = "";
while($buffer = <SOCK>) {
  if ($trailchars > 0) {       # deal with left-over lines from attributes
    if (length($buffer) < $trailchars) {
	$record .= $buffer;
	$trailchars -= length($buffer);
	substr($record, -1, 1) = "\r\n-";
	next;
    }
    $record .= substr($buffer, 0, $trailchars);
    $record .= "\r\n";
    if ($attrname eq "md5") {
      $handle = substr($buffer, 0, $trailchars);   # set handle to MD5 value
    }
    $buffer = substr($buffer, $trailchars);
    $trailchars = 0; $attrname = "";
  }

  next if $buffer =~ /^(200|12[56]) - /;
  next if $buffer =~ /^124 - \d+$/;
  $buffer =~ s/[\r\n]+//g;

  if ($buffer =~ /^(111|103) - (.*ERROR.*)/) {
    print "% 500 Broker error: $2\r\n";
    next;
  }

  if ($buffer =~ /^130 - object end/) {
    $handle =~ tr/a-z/A-Z/;
    print "# FULL FILE $serverhandle $handle\r\n";
    foreach (split(/\r\n/,$record)) {
	s/(.{79})/$1\r\n+/g;
	print "$_\r\n";
    }
    print "# END\r\n\r\n";
    next;
  }

  if ($buffer =~ /^120 - (.*)/) {
    if ($maxhits-- <= 0) {
      print "% 110 Too many hits\r\n";
      last;
    }
    $uri = $1;
    $handle = $uri;
    $record = " uri: $uri\r\n";  # NOTE: "url" is a searcheable field in Harvest
    next;
  }

  if ($buffer =~ /^127 - (.*) ([0-9]+)$/) {  # deal with selected attributes
    $attrname = $1;
    $trailchars = $2;
    $record .= " $attrname: ";
    next;
  }
}
close(SOCK);

print "% 226 Transaction complete\r\n";

goto HOLD if ($hold);

print "% 203 Time for Tubbybyebye!\r\n";

sub system_command {     # this routine was mostly taken from ROADS' wppd.pl
  my($command,$directive)=@_;
  my($template,$count);

  $command =~ tr/[A-Z]/[a-z]/;
  $directive =~ tr/[A-Z]/[a-z]/;

  # don't implement these - yet!
  return if $command eq "polled-by";
  return if $command eq "polled-for";
  return if $command eq "poll";

  if ($command eq "commands") {
    print STDOUT <<EOF;
# FULL COMMANDS $serverhandle COMMANDS\r
 Commands: commands\r
-constraints\r
-describe\r
-help\r
-list\r
-show\r
-version\r
# END\r
EOF
  }

  if ($command eq "constraints") {
    print STDOUT <<EOF;
# FULL CONSTRAINT $serverhandle CONSTRAINT1\r
 Constraint: format\r
 Default: full\r
 Range: full\r
# END\r
# FULL CONSTRAINT $serverhandle CONSTRAINT2\r
 Constraint: maxhits\r
 Default: $default_maxhits\r
 Range: 0-
# END\r
# FULL CONSTRAINT $serverhandle CONSTRAINT3\r
 Constraint: search\r
 Default: exact\r
 Range: exact,lstring\r
# END\r
# FULL CONSTRAINT $serverhandle CONSTRAINT4\r
 Constraint: case\r
 Range: consider,ignore\r
 Default: ignore\r
# END\r
# FULL CONSTRAINT $serverhandle CONSTRAINT5\r
 Constraint: hold\r
# END\r
EOF
    return;
  }

  if ($command eq "describe") {
     print STDOUT <<EOF;
# FULL SERVICES $serverhandle SERVICES\r
 Text: This is a WHOIS++/Harvest Broker gateway\r
-built for the TERENA CHIC-pilot project, see:
-  http://www.terena.nl/projects/chic-pilot/\r
-You can get more info by issuing the command HELP\r
# END\r
EOF
    return;
  }

  if ($command eq "?" || $command eq "help") {
    print STDOUT <<EOF;
# FULL HELP $serverhandle HELP\r
 Command: HELP\r
 Usage: HELP [command]\r
 Text: The command HELP should take one argument.\r
-But the HELP templates aren't built-in to the server :-(\r
-Try the command COMMANDS to find out what this server supports.
# END\r
EOF
    return;
  }

  if ($command eq "list") {
    print STDOUT <<EOF;
# FULL LIST $serverhandle LIST\r
 Templates: \r
-FILE\r
# END\r
EOF
    return;
  }

  if ($command eq "show") {
    return if ($directive ne "file");
    print STDOUT<<EOF;
# FULL FILE $serverhandle FILE\r
 uri:
 title:
 author:
 description:
 last-modification-time:
 file-size:
 type:
 md5:
# END\r
EOF
    return;
  }

  if ($command eq "version") {
    print STDOUT <<EOF;
# FULL VERSION $serverhandle VERSION\r
 Version: 3.0++\r
# END\r
EOF
    return;
  }
}

exit;
__END__


=head1 NAME

B<bin/harvest_shim.pl> - search gateway between WHOIS++ and Harvest Broker

=head1 SYNOPSIS

  bin/harvest_shim.pl [-h host] [-p port]

=head1 DESCRIPTION

This program relays WHOIS++ search requests to a Harvest Broker, and
returns the results in WHOIS++ result format.

Before passing the WHOIS++ query on to the Harvest Broker, it is
munged to remove WHOIS++ search syntax which would confuse the
Broker.  The search results, if any, are massaged into WHOIS++
templates using the template type B<FILE>

=head1 OPTIONS

=over 4

=item B<-h> I<host>

The host to contact, or "localhost" by default.

=item B<-p> I<port>

The TCP port number to use, or 8501 by default.

=back                                               

=head1 BUGS

Should be rewritten to allow for stand-alone operation.

=head1 SEE ALSO

L<bin/harvest_centroid.pl>, RFC 1913

=head1 COPYRIGHT

Copyright (c) 1988, Peter Valkenburg E<lt>valkenburg@terena.nlE<gt>,
Martin Hamilton E<lt>martinh@gnu.orgE<gt> and Jon Knight
E<lt>jon@net.lut.ac.ukE<gt>.  All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
  
It was developed by the Department of Computer Studies at Loughborough
University of Technology, as part of the ROADS project.  ROADS is funded
under the UK Electronic Libraries Programme (eLib), the European
Commission Telematics for Research Programme, and the TERENA
development programme.

=head1 AUTHOR

Peter Valkenburg E<lt>valkenburg@terena.nlE<gt>,
Martin Hamilton E<lt>martinh@gnu.orgE<gt>,
Jon Knight E<lt>jon@net.lut.ac.ukE<gt>.

