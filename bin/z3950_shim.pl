#!/usr/bin/perl
use lib "/home/roads2/lib";

use Getopt::Std;
getopts("d:h:p:z:");

# z3950_shim.pl - gateway WHOIS++ queries to Z39.50/GILS profile servers

# Authors: Peter Valkenburg/TERENA <valkenburg@terena.nl>
#          Martin Hamilton <martinh@gnu.org>
#          Jon Knight <jon@net.lut.ac.uk>

# ...as used in the Nordic Web Index (NWI).  Servers are accessed with Isite's
# zbatch program: http://www.cnidr.org.  YOU NEED PATCHES FOR ZBATCH if you
# run an Isite version 2.01c or earlier, see ./zbatch/README.
# Version 1.0 (valkenburg@terena.nl, 28/5/98)

# This script implements a mostly complete and RFC1835 compliant server.
# In addition, it implements a CONSTRAINTS command extension to notify
# clients of supported local constraints, see under 4b below.
# Tested Z39.50 backend servers: IndexData's Zebra; CNIDR's Isite.
# Tested whois++ front-end clients: Bunyip's Koala.
#
# Usage: wpp_zshim.pl [host [port [database]]]
# Some Nordic Web Index databases to try this on:
#   Denmark:                 nwi.dtv.dk    2100 Default
#   Greenland/Faroe Islands: nwi.dtv.dk    2121 fogl
#   Iceland:                 nwi.bok.hi.is 2100 Default
#   Norway:                  nwi.bibsys.no 2100 nwi
#   Sweden:                  nwi.lub.lu.se 2121 sweden

# Support for the CHIC-pilot search profile:
# 1. Boolean operators, with grouping delimited by ()'s:
#   AND, OR, NOT and grouping are supported, using the boolean infix
#   support of zbatch.  Since Z39.50 supports ANDNOT rather than NOT,
#   sequences of ".. AND NOT .." are rewritten to ".. ANDNOT ..".
# 2. Fielded searches:
#   Search terms of the form `attribute-name=value' are rewritten into
#   the zbatch `"value"[1,<attr-val>]' Use Attribute format (note the
#   quotes).  Mapping to attr-val numbers takes place in this script.
# 3. Literal searches:
#   literals are supported by quoting values that contain quoted blanks:
#      hello\ there
#   is rewritten for zbatch into
#      "hello\ there"
#   NOTE: strings surrounded by quotes are not supported by whois++ and
#   should be handled by the client by passing them to this shim without
#   quotes; the following characters should be `\' quoted (as per RFC1835):
#   space, tab, `=', `,', `:', `;', `\', `*', `.', `)', '(', `[', `]', `^'
# 4. Constraints:
#   a. case sensitive searches:
#      are not supported (can this be done in Z39.50 anyway?)
#   b. search matching of a complete word or a prefix (lstring):
#      implemented as whois++ local constraints `SEARCH=exact' and
#      `SEARCH=lstring' of which the first is implemented by a Z39.50
#      Truncation Attribute which zbatch sets when a word is ended with *.
#      SEARCH is also supported as a local constraint; the CONSTRAINTS
#      command was extended to notify the client with a "Scope" attribute
#      taking a value of "local" and/or "global" to notify the client
#      in which context a constraint may be used (this defaults to global).
#   c. maximum number of hits returned:
#      supported by passing on the global constraint `MAXHITS=n' to
#      zbatch as the `-n MaxHits' option.
#   d. multiple queries on the same connection:
#      the whois++ hold constraint is supported to allow clients to keep
#      an open TCP connection to this shim.
# 5. Returned attributes:
#   A basic set of attributes is extracted from the Z39.50 SUTRS response.
#   This will need adjusting if you want to talk to other servers than
#   those of the Nordic Web Index.  Supported NWI (Bib-1) attributes are:
#       [SUTRS/WHOIS++ label]    [Bib-1 / GILS profile attributes]
#       linkage                  gils/2021 ("Available-Linkage")
#       title                    bib1/4 ("Title")
#       author                   bib1/1003 ("Author-name")
#       abstract                 bib1/62 ("Abstract")
#       dateoflastmodification   bib1/1012 ("Date/time-last-modified")
#       bytes                    part of gils/2050 ("Supplemental-Information")
#       linkagetype              gils/2022 ("Linkage-Type")
#       controlidentifier        bib1/1007 ("Identifier-standard")
#       sampletext               bib1/1010 ("Body-of-Text")
#   This set of attributes should do for the presentation of matched
#   records; it should probably be rewritten to a Dublin Core template
#   a la I-D draft-ietf-asid-whois-schema-03.txt.
#
# In all, this is a complete RFC1835 server.  Problems:
#  - most search engines do not assume words to be separated by white space
#    only, but RFC1835 does seem to require that
#  - there is no support for searching for template names
#  - the NOT operator is only supported in the context of "AND NOT"

# Handle command line parameters
$server = $opt_h || "localhost";
$port = $opt_p || "210";
$db = $opt_d || "Default";
$zbatch = $opt_z || "/usr/local/bin/zbatch";

$tmpfile = "/tmp/wpp_zshim.$$";

$serverhandle = "$server/$port/$db";  # Use / since using `:' is not RFC1835-ish
$serverhandle =~ tr/a-z/A-Z/;         # caps to make it look impressive :)

#### This is the bit you need to change when you have a different profile ####
$template = "GILS-NWI";               # Assume the GILS profile as used by NWI
# Attribute names and their Z39.50 Use Attributes for GILS-NWI templates
# Attributes with "NOSEARCH" are not searcheable.  Entries with multiple Use
# (or other) attributes are allowed, as in: 'title-author','[1,4,1,1003]'.
%defattrs = (
  'linkage','[1,2021]', 'title','[1,4]', 'author','[1,1003]',
  'abstract','[1,62]', 'linkagetype','[1,2022]',
  'dateoflastmodification','[1,1012]', 'bytes','[1,2050]',
  'controlidentifier','[1,1007]', 'sampletext','[1,1010]');
$uri_attrname = "linkage";                  # name of URI attribute
$handle_attrname = "controlidentifier";     # name of handle attribute
###### End of bit you need to change when you want a different profile #######

$X = select(STDOUT); $| = 1; select($X);
print "% 220 CHIC WHOIS++/Z39.50-NWI shim for $server/$port/$db ready\r\n";

HOLD:   # a goto? YES!!!

chop($query = <STDIN>);
$query =~ s/\r$//;

# Global constraints MAXHITS, SEARCH, FORMAT, HOLD, INCLUDE are dealt with 1st..
$maxhits = $default_maxhits = 20;    # default MAXHITS=20
$matchword = "";                     # default SEARCH=exact
$format="FULL";                      # default FORMAT=FULL
$outcharset = "ISO-8859-1";          # default output char set is Latin-1
%includes = ();                      # default is to use %defattrs above
$hold = 0;                           # default is not to hold connection open

$query =~ s/^(([^\\:]|\\.)*):? *($|.*)/$1/;   # trim off global constraints
foreach $gcnstrnt (split(/;/,$3)) {
  next unless ($gcnstrnt);
  if ($gcnstrnt =~ /^MAXHITS=([0-9]+)/i) {
    $maxhits = $1;
  } elsif ($gcnstrnt =~ /^SEARCH=LSTRING$/i) {
    $matchword = "*";
  } elsif ($gcnstrnt =~ /^SEARCH=EXACT$/i) {
    $matchword = "";
  } elsif ($gcnstrnt =~ /^FORMAT=(FULL|ABRIDGED|HANDLE|SUMMARY)$/i) {
    $format = $1;
    $format =~ tr/a-z/A-Z/;
  } elsif ($gcnstrnt =~ /^OUTCHARSET=ISO-8859-1$/i) {  # this dumps some chars!
    $outcharset = "ISO-8859-1";
  } elsif ($gcnstrnt =~ /^OUTCHARSET=HTML$/i) {        # encodes all funnies
    $outcharset = "HTML";
  } elsif ($gcnstrnt =~ /^INCLUDE=(..*)$/i) {
    foreach (split(/,/, $1)) {
      $includes{$_} = $_;
    }
  } elsif ($gcnstrnt =~ /^HOLD$/i) {
    $hold = 1;
  } else {
    print "% 111 Warning: unsupported globalconstraint `$gcnstrnt' ignored\r\n";
  }
}

if ($format eq "FULL") {
  %includes = %defattrs unless (%includes);
} else {
  %includes = ();                      # only need attributes for FORMAT=FULL
}

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

$query =~ s/(^|[^\\])([)(])/$1 $2 /g; # insert spaces around grouping brackets
$query =~ s/([^\\])\sAND\s+NOT\s/$1 ANDNOT /gi;  # rewrite AND NOT's for Z39.50
$query =~ s/(^|[^\\])\s+/$1\n/g;      # rewrite to prepare splitting into terms
foreach $term (split(/[\n\r]+/, $query)) {
  next unless $term;

  $localmatchword = $matchword;          # carry over global SEARCH constraint
  $term =~ s/([^\\])($|;.*)/$1/;         # strip off local constraints
  foreach $lcnstrnt (split(/;/,$2)) {
    next unless ($lcnstrnt);
    if ($lcnstrnt =~ /^SEARCH=LSTRING$/i) {
      $localmatchword = "*";
    } elsif ($lcnstrnt =~ /^SEARCH=EXACT$/i) {
      $localmatchword = "";
    } else {
      print "% 111 Warning: unsupported local constraint `$lcnstrnt' ignored\r\n";
    }
  }

  if ($term =~ /^(!|HANDLE=)(.*)/i) { # search for handles
    $term = "\"$2\"$localmatchword$defattrs{$handle_attrname}";
  } elsif ($term =~ /^TEMPLATE=(.*)/i) {   # catch searching for template names
    print "% 111 Warning: cannot limit search to template names\r\n";
    $term = "\"\"";
  } elsif ($term =~ /^SEARCH-ALL=(.*)/i) { # `deal' with searching for anything
    $term = "\"$1\"$localmatchword";
  } elsif ($term =~ /^VALUE=(.*)/i) {      # dump VALUE specifier, if any
    $term = "\"$1\"$localmatchword";
  } elsif ($term !~ /^(\(|\)|and|or|not|andnot)$/i) {
    if ($term =~ /^([^=]*)=(.*)/) {
      $attrname = $1;
      $term = "\"$2\"$localmatchword";
      $attrname =~ y/A-Z/a-z/;
      $term .= $defattrs{$attrname} ? $defattrs{$attrname} : # add Use Attribute
				      "NOSEARCH";            # ..or ruin search
    } else {
      $term = "\"$term\"$localmatchword";
    }
  } else {
    $term =~ y/a-z/A-Z/;
    if ($term eq "NOT") {
      print "% 502 Search expression too complicated (NOT must be in AND NOT context)\r\n";
      goto HOLD if ($hold);
      print "% 203 Time for Tubbybyebye!\r\n";
      exit;
    }
  }

  $to_send .= "$term ";
}

print "% 200 OK, going for it...\r\n";

# Create the 5 line command file for Isite's zbatch; use minimal tagset
$tagset = ($format eq "FULL" || $format eq "ABRIDGED") ? "F" : "B";
unless (open(CMDFILE, ">$tmpfile") &&
	print CMDFILE "$db\nGILS\nSUTRS\n$tagset\n$to_send\n") {   # zbatch cmd
  print "% 500 Couldn't write to temp file: $! \r\n";
  print "% 203 Time for Tubbybyebye!\r\n";
  exit(-1);
}
close(CMDFILE);

# Start zbatch; note we ask for one extra hit to detect exceeding maxhits.
unless (open(ZBATCH,
	     "$zbatch -n ".($maxhits + 1)." $server $port $tmpfile 2>&1 |")) {
  print "% 500 Couldn't execute $zbatch: $! \r\n";
  print "% 203 Time for Tubbybyebye!\r\n";
  unlink($tmpfile);
  exit(-1);
}
$X = select(ZBATCH); $| = 1; select($X);

print "% 220 Done search for: $to_send\r\n";
$record = ""; %doneattrs = (); $handle = "";
$attrname = ""; $trailchars = 0;
$nhits = 0;

# The loop below parses `typical' SUTRS output; no guarantees here.  Example:
#   1) local-control-number: 1814
#   availability:
#     availableLinkage:
#       linkage: http://blah.blah.blah/blahblahblahblahblahblahblahblah=
#         yetmoreblah/
#       linkageType: text/html
#   title: this is a title field containing new lines
#     this is the 2nd line of the title
#   ..
# Note: repeated attributes are ignored unless they are adjacent.

while ($buffer = <ZBATCH>) {
  $buffer =~ s/[\r\n]+//g;

  if ($buffer =~ /^(ERROR: |Initialize:)(.*)/i) {
    print "% 500 Error: $2\r\n";
    break;
  }

  if ($format eq "SUMMARY" && $buffer =~ /^([0-9]+) total record/) {
    $nhits = $1;  # Screeech.  This line provides a shortcut for summary format.
    break;
  }

  if ($trailchars ne 0) {           # deal with left-over stuff from attributes
    $buffer =~ s/^ *//;
    if ($buffer =~ s/=$//) {                      # another continuation marker
	$trailchars = 1;
    } else {
	$trailchars = 0;
    }
    if ($includes{$attrname} ||
	($format eq "ABRIDGED" && $attrname eq $uri_attrname)) {
      $record .= "+".$buffer."\r\n"
    }
    next;
  }

  if ($handle && $buffer =~ /^$/) {                # end of record (we think..)
    if ($format eq "SUMMARY") {
      $record = ""; $attrname = ""; $handle = ""; %doneattrs = ();
      next;
    }

    print "# $format $template $serverhandle $handle\r\n";

    if ($format eq "FULL" || $format eq "ABRIDGED") {
      foreach (split(/\r\n/, $record)) {
	if ($outcharset eq "HTML") {        # `escape' chars using HTML &#N;
	  s/[\x00-\x1f&<>\x7f-\xff]/"&#".ord($&).";"/ge;
	}
	s/[\x00-\x1f]/?/g;                  # Yuch.  But that's RFC1835.
	s/(.{79})/$1\r\n+/g;                # cut up long lines
	print "$_\r\n";
      }
      print "# END\r\n\r\n";
    }

    $attrname = ""; $record = ""; $handle = ""; %doneattrs = ();
    next;
  }

  if ($buffer =~ /^[0-9]+\) (.*)/) {       # start of a new record
    $buffer = $1;
    $attrname = ""; $record = ""; $handle = ""; %doneattrs = ();
    if ($nhits >= $maxhits) {
      print "% 110 Too many hits\r\n";
      last;
    }
    $nhits++;
    $handle = $buffer;           # a $handle_attrname field will override this
    $handle =~ y/a-zA-Z0-9//cd;   # remove non-alphanumerics
    $handle =~ y/a-z/A-Z/;
  }

  if ($buffer =~ /^ *([a-zA-Z0-9-_]+):$/) {    # empty value -- ignore
    $attrname = "";
    next;
  }

  # Try to deal with adjacent repeated attributes; this is really guess work..
  if ($attrname && $buffer =~ /^( *)([a-zA-Z0-9-_]+): (.*)/) {
    $nextattrname = $2; $nextattrname =~ y/A-Z/a-z/;
    if ($nextattrname eq $attrname) {  # continue current attr/val
      $buffer = "$1  $3";
    }
  }

  if ($buffer =~ /^ *([a-zA-Z0-9-_]+): (.*)/) { # deal with included attributes
    $attrname = $1;
    $attrname =~ y/A-Z/a-z/;

    if ($doneattrs{$attrname}) {
      $attrname = "";
      next;
    } else {
      $doneattrs{$attrname} = $attrname;
    }
      
    $attrval = $2;

    if ($attrname eq $handle_attrname) {
      $handle = $attrval;             # set handle to value of $handle_attrname
      $handle =~ y/a-zA-Z0-9//cd;     # remove non-alphanumerics
      $handle =~ y/a-z/A-Z/;
    }

    $trailchars = 1 if ($attrval =~ s/=$//);          # line continuation

    $record .= " $attrname:" if ($includes{$attrname});
    if ($includes{$attrname} ||
	($format eq "ABRIDGED" && $attrname eq $uri_attrname)) {
      $record .= " $attrval\r\n";
    }

    next;
  }

  if ($attrname && $buffer =~ /^ +(.*)/) {            # deal with value lines
    $attrval = $1;
    $trailchars = 1 if ($attrval =~ s/=$//);          # line continuation

    $record .= "-$attrval\r\n" if ($includes{$attrname});

    next;
  }
}

if ($format eq "SUMMARY") {
  print "# SUMMARY $serverhandle\r\n";
  print " Matches: $nhits\r\n";
  print " Templates: $template\r\n";
  print "# END\r\n";
}

while(<ZBATCH>) {}              # let zbatch finish the Z39.50 session properly
close(ZBATCH);

print "% 226 Transaction complete\r\n";

unlink($tmpfile);

goto HOLD if ($hold);

print "% 203 Time for Tubbybyebye!\r\n";

sub system_command {     # this routine was mostly taken from ROADS' wppd.pl
  my($command,$directive)=@_;

  $command =~ tr/[a-z]/[A-Z]/;
  $directive =~ tr/[a-z]/[A-Z]/;

  # don't implement these - yet!
  return if $command eq "POLLED-BY";
  return if $command eq "POLLED-FOR";
  return if $command eq "POLL";

  if ($command eq "COMMANDS") {
    print STDOUT <<EOF;
# FULL COMMANDS $serverhandle \r
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

  if ($command eq "CONSTRAINTS") {
    print STDOUT <<EOF;
# FULL CONSTRAINTS $serverhandle \r
 Constraint: format\r
 Default: full\r
 Range: full, abridged, handle, summary\r
# END\r
# FULL CONSTRAINTS $serverhandle \r
 Constraint: maxhits\r
 Default: $default_maxhits\r
 Range: 0-\r
# END\r
# FULL CONSTRAINTS $serverhandle \r
 Constraint: search\r
 Default: exact\r
 Range: exact, lstring\r
 Scope: global, local\r
# END\r
# FULL CONSTRAINTS $serverhandle \r
 Constraint: outcharset\r
 Default: ISO-8859-1\r
 Range: ISO-8859-1, HTML\r
# END\r
# FULL CONSTRAINTS $serverhandle \r
 Constraint: include\r
# END\r
# FULL CONSTRAINTS $serverhandle \r
 Constraint: hold\r
# END\r
EOF
    return;
  }

  if ($command eq "DESCRIBE") {
     print STDOUT <<EOF;
# FULL SERVICES $serverhandle \r
 Text: This is a WHOIS++/Z39.50 gateway\r
-built for the TERENA CHIC-pilot project, see:\r
-  http://www.terena.nl/projects/chic-pilot/\r
-You can get more info by issuing the command HELP\r
# END\r
EOF
    return;
  }

  if ($command eq "?" || $command eq "HELP") {
    print STDOUT <<EOF;
# FULL HELP $serverhandle \r
 Text: Here is general help on commands in RFC1835 whois++ servers:\r
-  COMMANDS          - list whois++ commands supported by this server\r
-  CONSTRAINTS       - list valid constraints supported by this server\r
-  DESCRIBE          - describe this server\r
-  LIST              - list templates supported by this server\r
-  SHOW [TEMPLATE]   - show attributes of given template\r
-  VERSION           - show the protocol version supported by this server\r
-  HELP [COMMAND]    - show help on commands\r
-  ?                 - synonymous to HELP\r
-  POLLED-BY         - list indexing servers known to poll this server\r
-  POLLED-FOR        - list information about servers this server polls\r
-For a list of available commands in this server give the command COMMANDS.\r
# END\r
EOF
    return;
  }

  if ($command eq "LIST") {
    print STDOUT <<EOF;
# FULL LIST $serverhandle \r
 Templates: $template\r
# END\r
EOF
    return;
  }

  if ($command eq "SHOW") {
    return if ($directive ne $template);
    print STDOUT<<EOF;
# FULL $template $serverhandle \r
 linkage: \r
 title: \r
 author: \r
 abstract: \r
 dateoflastmodification: \r
 bytes: \r
 linkagetype: \r
 controlidentifier: \r
 sampletext: \r
# END\r
EOF
    return;
  }

  if ($command eq "VERSION") {
    print STDOUT <<EOF;
# FULL VERSION $serverhandle \r
 Version: 1.0\r
# END\r
EOF
    return;
  }
}

__END__


=head1 NAME

B<bin/z3950_shim.pl> - search gateway between WHOIS++ and Z39.50 server

=head1 SYNOPSIS

  bin/z3950_shim.pl [-d database] [-h host] [-p port]
    [-z path_to_zbatch]

=head1 DESCRIPTION

This program relays WHOIS++ search requests to a Z39.50 server and
tries to munge the results back into WHOIS++ result format.  It runs
from the command line listening to STDIN and writing its results to
STDOUT, and hence is suitable for launching via I<inetd>.

Before passing the WHOIS++ query on to the Z39.50 server, it is
munged to remove WHOIS++ search syntax which would confuse it.
The search results, if any, are massaged into WHOIS++ templates
using the template type B<GILS-NWI>.

=head1 OPTIONS

=over 4

=item B<-d> I<database>

The database to use, or "Default" by default.

=item B<-h> I<host>

The host to contact, or "localhost" by default.

=item B<-p> I<port>

The TCP port number to use, or 210 by default.

=item B<-z> I<path_to_zbatch>

The path to the I<zbatch> program, or I</usr/local/bin/zbatch> by
default.

=back

=head1 BUGS

This program depends on the B<zbatch> program from the CNIDR
Isite distribution - see http://www.cnidr.org.  It should be
rewritten to include native Z39.50 support!

Z39.50 is a very complex protocol, and it's highly likely that you
won't be able to use this tool to talk to an arbitrary Z39.50
server.  Be prepared to get your hacking gloves out!

Should be rewritten to allow for operation as a stand-alone server.

=head1 SEE ALSO

L<bin/z3950_centroid.pl>, RFC 1913

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

