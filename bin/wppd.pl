#!/usr/bin/perl
use lib "/home/roads2/lib";

# wppd - WHOIS++ server
# 
# Authors: Martin Hamilton <martinh@gnu.org>
#          Jon Knight <jon@net.lut.ac.uk>
#          with apologies to Tom Christiansen, and Larry Wall :-)
#
# $Id: wppd.pl,v 3.34 1999/07/29 14:39:37 martin Exp $

require ROADS;
use ROADS::Index;
use ROADS::DatabaseNames;
use ROADS::ErrorLogging;
use ROADS::ReadTemplate;
use ROADS::Centroid;
use ROADS::CIPv3;

use Socket;
use POSIX;
use Getopt::Std;
# Handle command line parameters
getopts('a:cCdDe:f:g:h:iLl:m:p:r:Rs:S:t:T:');

# Default location of source IAFA templates
$iafa_source = $opt_s || "$ROADS::IafaSource";
# Default location for the inverted index files
$target_index = $opt_t || "$ROADS::IndexDir/index";
# Source for restrictions
$restrictfile = $opt_r || "$ROADS::Config/search-restrict";
# File containing list of terms and expansions
$expansionfile = $opt_e || "$ROADS::Config/expansions";
# File containing stoplist
$stoplistfile = $opt_S || "$ROADS::Config/stoplist";
# Logfile to record hits from queries in.
$hitlog = $opt_l || "$ROADS::Logs/wppd-hits";
# Serverhandle - short name for your server
$serverhandle = $opt_h || "$ROADS::Serverhandle" || "me";
# Caseless matching is default
$considercase = $opt_c || "$ROADS::ServerCaseful" || 0;
# Stemming (aka lstring) is off by default
$stemming = $opt_S || "$ROADS::ServerStemming" || 0;
# Default number of hits before switching to SUMMARY format
$default_maxfull = $opt_f || "$ROADS::DefaultMaxfull" || 60;
# Default maximum number of hits to return
$default_maxhits = $opt_m || "$ROADS::DefaultMaxhits" || 100;
# Administratively defined upper limit on the number of hits to return
$admin_maxhits = $opt_a || "$ROADS::AdminMaxhits" || 150;
# Whether or not to return a hit count with the results
$return_hit_count = $opt_C || "$ROADS::HitCount" || 0;
# Port number, default is 8237
$port_number = $opt_p || $ROADS::WHOISPortNumber || 8237;
# Log client's hostname (default is IP address only)
$log_hostname = $opt_D ? "yes" : "no";
# Whether to log anything at all!
$to_log = $opt_L || "$ROADS::ServerLog" || "yes";
# WHOIS++ Gateway Interface conformant backend
$wgiapp = $opt_g || "$ROADS::WGIPath" || "undefined";
# WHOIS++ Gateway Interface conformant thesaurus program (default of none)
$wgithesaurus = $opt_T || "$ROADS::WGIThesaurus" || "undefined";
# Access control is off by default
$acls = $opt_R || 0;
# Don't cache index data in memory
$cache_index = $opt_i ? 0 : 1;

# Debugging is off by default
$debug = $opt_d ? 1 : 0;

sub signalhandler {
    $SIG{CHLD} = \&signalhandler;
    $waitedpid = wait;
}

@MON = ('Dummy', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
        'Aug', 'Sep', 'Oct', 'Nov', 'Dec');

# Set up a signal handler for SIGCHLD
$SIG{'CHLD'} = 'signalhandler';

if ($wgiapp eq "undefined") {
    unless (-s "$target_index" && -s "$target_index.idr") {
        &WriteToErrorLogAndDie("wppd.pl",
          "Won't start WHOIS++ server because there's no database index!");
    }
}

$pid = fork;
unless (defined($pid)) {
    &WriteToErrorLogAndDie("wppd.pl", "forking problems: $!");
}
if ($pid != 0) {
    # we're the parent, so let's wait
    wait;
    exit;
}
$pid = fork;
unless (defined($pid)) {
    &WriteToErrorLogAndDie("wppd.pl", "forking problems: $!");
}
if ($pid != 0) {
    # write Our Kid's process ID out for the admin tools
    if (open(PIDFILE, ">$ROADS::Guts/wppd.pid")) {
	print PIDFILE "$pid\n";
	close(PIDFILE);
    } else { # non-fatal
	&WriteToErrorLog("wppd.pl",
	  "Couldn't write process ID $pid to $ROADS::Guts/wppd.pid: $!");
    }
    # we're the first-born, so die
    exit;
}

# after all that, hopefully we're not a zombie!

# See if we should do an in-memory cache of the index for speed.
if ($cache_index and $wgiapp eq 'undefined') {
    # Cache the current database index in memory for faster response
    &initIndexCache("$target_index");
  
    #  Remember the last modification time so we can check to see
    #  if it's been updated and automagically re-read if neccessary
    $cachedIndexMtime = -C "$target_index";
    &WriteToErrorLog("wppd.pl",
     "Initialised in memory wppd index cache to $cachedIndexMtime") 
     if $debug;
}

# The usual sockets stuff to set up a TCP socket on the configured port and
# start the server listening on it.
socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp'))
    || &WriteToErrorLogAndDie("wppd.pl", "couldn't get socket: $!");
setsockopt(SOCK, SOL_SOCKET, SO_REUSEADDR, pack("l", 1))
    || &WriteToErrorLogAndDie("wppd.pl", "couldn't setsockopt: $!");
bind(SOCK, sockaddr_in($port_number, INADDR_ANY))
    || &WriteToErrorLogAndDie("wppd.pl", "bind failed: $!");
listen(SOCK, SOMAXCONN)
    || &WriteToErrorLogAndDie("wppd.pl", "listen failed: $!");

for ( ; ($client = accept(NEWSOCK, SOCK)); close NEWSOCK) {

    # test to see whether the index cache is stale, e.g. if
    # extra templates were added since we last updated our
    # in-memory copy of it
    if ($cache_index) {
        $currentIndexMtime = -C "$target_index";
        &WriteToErrorLog("wppd.pl",
         "currentIndexMtime = $currentIndexMtime")
         if $debug;
        &WriteToErrorLog("wppd.pl",
         "cachedIndexMtime = $cachedIndexMtime")
         if $debug;
        if ($cachedIndexMtime > $currentIndexMtime) {
            # Index cache is stale, better re-read it
            &initIndexCache("$target_index");
            $indexTimeStamp = -C "$target_index";
            #  Remember the last modification time so we can check to see
            #  if it's been updated and automagically re-read if neccessary
            $cachedIndexMtime = -C "$target_index";
            &WriteToErrorLog("wppd.pl",
             "Updated in memory wppd index cache to $cachedIndexMtime")
             if $debug;
        }
    }

    ($clientport,$clientaddr) = sockaddr_in($client);

    if ($log_hostname eq "yes" || $acls) {
        $clientname = gethostbyaddr($clientaddr, AF_INET);
    } else {
        undef($clientname);
    }
    $printableaddr = inet_ntoa($clientaddr);

    if ($to_log eq "yes" && $debug) {
      if (defined($clientname)) {
        &WriteToErrorLog("wppd.pl", "connect from $clientname");
      } else {
        &WriteToErrorLog("wppd.pl", "connect from $printableaddr");
      }
    }

    # Do some funky access control stuff on the WHOIS++ connection.  This
    # is currently based on the IP address of the client machine.  Note that
    # if we don't have ACLs turned on we allow both searching and polling
    # by default - use ACLs if you want something different!
    $directive = "poll";
    if ($acls) {
      if (open(ACL, "$ROADS::Config/hostsallow")) {
        $directive = "deny"; # disable all access by default when using ACLs
        while(<ACL>) {
          chomp;
          next if /^(\s|#)/;
          next if /^$/;
          tr [A-Z] [a-z];
          /^([^:]+):\s+(.*)$/ && ($match=$1, $this_directive=$2);

          if ($match =~ /\*/) {
            $directive = "$this_directive";
            last;
          } elsif ($match =~ /^\d/) {
            if ($printableaddr =~ /^$match$/) {
              $directive = "$this_directive";
              last;
            }
          } elsif ($clientname) {
            if ($clientname =~ /^$match$/) {
              $directive = "$this_directive";
              last;
            }
          }
        }
        close(ACL);
        close(NEWSOCK), next if $directive eq "deny";
      }
    }

    $pid = fork;
    unless (defined($pid)) {
	&WriteToErrorLog("wppd.pl", "couldn't fork to service client: $!");
	# log this info
	close(NEWSOCK);
	next;
    }
    if ($pid == 0) {
	close(NEWSOCK);
        # parent cycles round to start of loop ready for new calls
        next;
    } else {
      # write Our Kid's process ID out for the admin tools
      if (open(PIDFILE, ">$ROADS::Guts/wppd.pid")) {
        print PIDFILE "$pid\n";
        close(PIDFILE);
      } else { # non-fatal
        &WriteToErrorLog("wppd.pl",
        "Couldn't write process ID $pid to $ROADS::Guts/wppd.pid: $!");
      }
      # make socket line buffered
      open(STDIN,  "<&NEWSOCK") 
        || &WriteToErrorLogAndDie("wppd",
              "can't dup client socket to stdin: $!");
      open(STDOUT, ">&NEWSOCK") 
        || &WriteToErrorLogAndDie("wppd",
              "can't dup client socket to stdout: $!");
      $X = select(STDIN); $|=1; select($X); 
      $X = select(STDOUT); $|=1; select($X); 
      # drop out to main code block
      last;
    }
    &WriteToErrorLog("wppd", "fork to disassociate client failed: $!");
}

# Set up an alarm call and signal handler to kill us off in an hour's
# time (in case something goes wrong and we end up hanging about far 
# longer than we should)
sub topmyself { exit(0); }
alarm(3600);

print STDOUT "% 220 LUT WHOIS++ server $ROADS::Version ready.  Hi!\r\n";

$GLOB{hold} = "y";
while ($GLOB{hold} eq "y") {
    undef(%GLOB); # don't preserve any state!
    $GLOB{case} = "ignore";
    $GLOB{format} = "full";
    $GLOB{maxfull} = $default_maxfull;
    $GLOB{maxhits} = $default_maxhits;
    $GLOB{search} = "exact";

    chomp($query = <NEWSOCK>);
    $query =~ s/[\r\n]//g;
    $log_query = $query;

    ($wgiapp,$wgiparam) = split(" ",$wgiapp,2);
    if ($wgiapp ne "undefined" && -x "$wgiapp") {
        $ENV{"GATEWAY_INTERFACE"} = "WGI/1.0";
        $ENV{"QUERY_STRING"} = $query;
        $ENV{"REMOTE_ADDR"} = $printableaddr;
        $ENV{"REMOTE_HOST"} = $clientname if $clientname;
        $ENV{"SERVER_NAME"} = $ROADS::MyHostname if $ROADS::MyHostname;
        $ENV{"SERVER_PROTOCOL"} = "WHOIS++/1.0";
        $ENV{"SERVER_PORT"} = "$port_number";
        $ENV{"SERVER_SOFTWARE"} = "LUT-WHOIS++/$ROADS::Version";
        $ENV{"OPERATION"} = "DoSearch";

        exec "$wgiapp $wgiparam" || &WriteToErrorLogAndDie("wppd",
                          "couldn't exec $wgiapp $wgiparam: $!");
    }

    if ($query =~ /^#/) {
      &system_command($query, $directive);

      &wpp_log(0, 0);
      next;
    }

    if ($query =~ /:([^:]+)$/) {
	$globals = $1;
	$query =~ s/:[^:]+$//;
    }

    if ($globals) {
	$query =~ s/:([^:]+)$//;
	print STDOUT "% 204 after extracting globals, query: $query\r\n"
          if $debug;
	$globals =~ tr/[A-Z]/[a-z]/;
	@globs = split(/;/, $globals);
	foreach (@globs) {
            # these two don't take a value
            if (/^hold$/) { $GLOB{hold} = "y"; next; }
	    if (/^debug$/) { $debug = 1; next; } # this is actually state!

	    print STDOUT "% 204 glob: $_\r\n" if $debug;
	    ($l,$r) = split(/=/);

            if ($l eq "case") {
                if ($r =~ /^(ignore|consider)$/) {
                    $GLOB{case} = $r;
	            print STDOUT "% 204 case: $GLOB{case}\r\n" if $debug;
                } else {
                    print STDOUT "% 112 don't know how to handle case $r\r\n";
                }
                next;
            }

            if ($l eq "search") {
	        if ($r =~ /^(exact|lstring|substring)$/) {
                    $GLOB{search} = $r;
	            print STDOUT "% 204 search: $GLOB{search}\r\n" if $debug;
                } else {
                    print STDOUT "% 112 don't understand search method $r\r\n";
                }
                next;
            }

            if ($l eq "format") {
                if ($r =~ /^(full|summary|abridged|handle)$/) {
                    $GLOB{format} = $r;
	            print STDOUT "% 204 format: $GLOB{format}\r\n" if $debug;
                } else {
                    print STDOUT "% 112 don't understand format $r\r\n";
                }
            }
	    
            if ($l eq "maxfull") {
                if ($r =~ /^\d+$/) {
                    $GLOB{maxfull} = $r;
	            print STDOUT "% 204 maxfull: $GLOB{maxfull}\r\n" if $debug;
                    if ($r <= 0) {
                        $GLOB{maxfull} = $admin_maxfull;
                    }
                } else {
                    print STDOUT "% 112 don't understand maxfull $r\r\n";
                }
            }

            if ($l eq "maxhits") {
                if ($r =~ /^\d+$/) {
                    $GLOB{maxhits} = $r;
                    if ($r > $admin_maxhits || $r <= 0) {
                        print STDOUT "% 204 you can only have $admin_maxhits!\r\n";
                        $GLOB{maxhits} = $admin_maxhits;
                    }
                } else {
                    print STDOUT "% 112 don't understand maxhits $r\r\n";
                }
            }

            if ($l eq "authenticate") {
                $GLOB{authenticate} = $r;
            }

            if ($l eq "name") {
                $GLOB{name} = $r;
            }

            if ($l eq "password") {
                $GLOB{password} = $r;
            }
	}
    }

    if ($GLOB{authenticate} && $GLOB{password} && $GLOB{name}) {
        print STDOUT "% 204 Doing an authentication...\r\n" if $debug;
        $authenticated = "no";
        if (open (PASSWD, "$ROADS::Config/adminpasswd")) {
            while(<PASSWD>) {
              chomp;
              next unless /^$GLOB{name}:/;
              ($uname,$passwd,$junk) = split(/:/,$_,3);
              print STDOUT "% 204 passwd = $passwd\r\n" if $debug;
              print STDOUT "% 204 clr p = `".$GLOB{password}."`\r\n"
                if $debug;
              print STDOUT "% 204 c(s,p) = ".
                crypt($GLOB{password},$passwd)."\r\n" if $debug;
              if (crypt($GLOB{password},$passwd) eq $passwd) {
                $authenticated = "yes";
                print STDOUT "% 204 Authenticated!\r\n" if $debug;
              }
            }
            close(PASSWD);
        }
        undef($uname,$passwd,$GLOB{password});
        if ($authenticated eq "yes") {
            $restrictfile = "$ROADS::Config/admin-restrict";
        }
    }

    print STDOUT "% 204 hold: $GLOB{hold}\r\n" if $debug;
    print STDOUT "% 204 debug: $debug\r\n" if $debug;

    # system commands
    if ($query =~ /^(commands|constraints|describe|list)$/i
      || $query =~ /^(polled-by|polled-for|version|poll)$/i 
      || $query =~ /^(# poll|help|show)\s*/i) {
        &system_command($query, $directive);

        if ($GLOB{hold} eq "y") {
	    print STDOUT "% 226 holding connection open\r\n";
        } else {
            print STDOUT "% 226 Transaction complete\r\n";
        }

        &wpp_log(0, 0);
        next;
    }

    # lookups by handle
    if ($query =~ /^\!(.*)/ || $query =~ /^handle=(.*)/ 
       || $query =~ /^\(handle=(.*)\)/) {
        $handle = $1;
        $handle =~ s/\.\\//g;
        print STDOUT "% 204 returning handle: $handle\r\n" if $debug;
        &displayfull($handle); 

        if ($GLOB{hold} eq "y") {
	    print STDOUT "% 226 holding connection open\r\n";
        } else {
            print STDOUT "% 226 Transaction complete\r\n";
        }

        &wpp_log(0, 0);
        next;
    }

    $_ = $query;

    # normalize query to internal format!

    s/value=//g;           # value= is redundant
    s/;[^\s]+\s/ /g;       # we don't believe in local constraints :-)
    s/;[^\s]+$//g;         # ... well, not just yet

    while (/\"(((\w+)\s*)+)\"/) {
	$phrase = $1;
	$phrase =~ s/\s+/\_/g;
	s/\"(((\w+)\s*)+)\"/$phrase/;
    }

#    s/-/&/g;
    s/^\s*//;
    s/\s*$//;
    s/\s*=\s*/=/g;
    s/^not\s+/!/i;
    s/\(not\s+/\(!/ig;
    s/^not\(/!\(/i;
    s/\s+and\s+/&/ig;
    s/\s+not\s+/ !/ig;
    s/\s+not\(/ !\(/ig;
    s/\!(\w+)/!\(\1\)/ig;
    s/\s*&\s*/&/ig;
    s/\s+or\s+/|/ig;
    s/\s*\|\s*/|/ig;
    s/&\s*not\s+/&!/ig;
    s/\s+/&/ig;
    s/\)!/\)&!/ig;
    s/(\w)!(\w)/$1&!$2/ig;
    s/(!?[\w-]*=?\w+\)*)\s(!?[\w-]*=?\w+)/$1 & $2/ig;
    $query = $_;

    #print STDOUT "% 600 ISO-8859-1\r\n";
    print STDOUT "% 200 Searching for $query\r\n";

    $considercase = $GLOB{case} eq "ignore" ? 0 : 1;
    if ($GLOB{search} eq "exact") {
      $stemming = 0;
    } elsif ($GLOB{search} eq "lstring") {
      $stemming = 1;
    } elsif ($GLOB{search} eq "substring") {
      $stemming = 2;
    } else {
      $stemming = 0;
    }

    print STDOUT "% 204 considercase: $considercase\r\n" if $debug;
    print STDOUT "% 204 stemming: $stemming\r\n" if $debug;

    $num_hits = 0;
    @handles = &dosearch($query);
    @referrals = &doreferrals($query);

    $GLOB{format} = "summary" if $num_hits > $GLOB{maxfull};

    print STDOUT "% 110 Too many hits\r\n" if $num_hits > $GLOB{maxhits};

    if ($GLOB{format} eq "abridged" || $GLOB{format} eq "handle") {
        &displayhandles(@handles);
    } elsif ($GLOB{format} eq "summary") {
        &displaysummary(@handles);	
    } else {
        unless ($GLOB{format} eq "full") {
          print STDOUT "% 111 don't know how to deal with format $GLOB{format}\r\n";
        }
        &displayfull(@handles);
    }

    $referral_hits = 0;
    foreach $serverhandle (@referrals) {
      $referral_hits++;
      unless (open(SERVER,"$ROADS::Config/wig/$serverhandle")) {
	  &WriteToErrorLog("wppd",
            "got referral for server $serverhandle, but no server info");
	  next;
      }
      $HostName = $HostPort = $HostURI = "";
      while(<SERVER>) {
        chomp;
        /^Host-Name:\s*(.*)/ && ($HostName = $1);
        /^Host-Port:\s*(.*)/ && ($HostPort = $1);
        /^URI:\s*(.*)/ && ($HostURI = $1);
      }
      close(SERVER);
      print STDOUT "# SERVER-TO-ASK $serverhandle\r\n";
      print STDOUT " Server-Handle: $serverhandle\r\n";
      print STDOUT " Host-Name: $HostName\r\n" if ($HostName);
      print STDOUT " Host-Port: $HostPort\r\n" if ($HostPort);
      print STDOUT " URI: $HostURI\r\n" if ($HostURI);
      print STDOUT "# END\r\n\r\n";
    }

    &wpp_log($num_hits, $referral_hits);

    if ($return_hit_count) {
      print STDOUT <<EOF;
# FULL COUNT $serverhandle HITS\r
 Local-Count: $num_hits\r
 Referral-Count: $referral_hits\r
# END

EOF
    }

    if ($GLOB{hold} eq "y") {
	print STDOUT "% 226 holding connection open\r\n";
    } else {
        print STDOUT "% 226 Transaction complete\r\n";
    }
}

print STDOUT "% 203 Sayonara\r\n";
exit;

#
# return only matching handles
#
sub displayhandles {
    my(@handles) = @_;
    my($handle,$count);

    $count = 1;
    foreach $handle (@handles) {
        last if $count > $GLOB{maxhits};
        $count++;
	open(IN, "$iafa_source/$handle") 
	    || print STDOUT "% 204 Can't open template $handle: $!\r\n", next;
	undef($TT);
	while(<IN>) {
	    chomp;
	    s/\t/ /g;
	    s/\s+/ /g;
	    /^template-type:\s+(.*)/i && ($TT=$1);
	    last if $TT;
	}
        close(IN);
	print STDOUT "# HANDLE $TT $serverhandle $handle\r\n";
    }
}

#
# summary format
#
sub displaysummary {
    my(@handles) = @_;
    my($handle);

    foreach $handle (@handles) {
	open(IN, "$iafa_source/$handle") 
	    || print STDOUT "% 204 Can't open template $handle: $!\r\n", next;
	undef($TT);
	while(<IN>) {
	    chomp;
	    s/\t/ /g;
	    s/\s+/ /g;
	    /^template-type:\s+(.*)/i && ($templates{"$1"}=$1, last);
	}
        close(IN);
    }
    print STDOUT "# SUMMARY $serverhandle\r\n";
    print STDOUT " Matches: $num_hits\r\n";
    print STDOUT " Templates:";
    foreach (keys %templates) {
	print STDOUT " $_\r\n";
    }
    print STDOUT "# END\r\n";
}

#
# full template matches
#
sub displayfull {
    my(@handles) = @_;
    my(%AV,$handle,$TT,$HANDLE,$value,$attrib,$vattrib,@avkeys,$base,$gotcha);
    my($variant,$check,$include,$cluster);

    &initRestrictions($restrictfile) 
      unless $FieldRestrictionInit;

    $count = 1;
    foreach $handle (@handles) {
	undef(%AV);
        last if $count > $GLOB{maxhits};
	next if $handle =~ /^\./;
        $TT="";
        $HANDLE="";
        $attrib="";
        $vattrib="";
        $value="";
        $count++;
        #
        # This is NOT the standard readtemplate() routine - do NOT try to
        # replace it with the one from lib/ROADS/ReadTemplate.pm!!!!
        #
	open(IN, "$iafa_source/$handle") 
	    || print STDOUT "% 204 Can't open template $handle: $!\r\n", next;
	while(<IN>) {
	    chomp;
  
	    s/\t/ /g;
	    s/\s+/ /g;
	    /^template-type:\s+(.*)/i && ($TT=$1);
	    /^handle:\s+(.*)/i && ($HANDLE=$1);
	    
	    next if /^[^:]+:(\s+\|)$/;
	    
	    if (/^\s/ && $value) { # continuation line
		$value .= "$_";
		next;
	    }
	    
	    if (/^([^\s:]+)\s/ && $value) { # hmm...  blooper ?  try to recover
		$value .= "$_"; 
		next;
	    }
	    
	    if (/^([^:]+):\s+(.*)/) { # easy!  attrib: value
		if ($attrib) {
		    $AV{"$vattrib"} = "$attrib: $value";
		}
		
		$vattrib = $attrib = $1; $value = $2;
		$attrib =~ s/-v\d+//;
		$vattrib =~ tr/[a-z]/[A-Z]/;
	    }
	}
        $AV{"$vattrib"} = "$attrib: $value";
	close (IN);

	@avkeys = keys(%AV);
	
	print STDOUT "% 204 No template type!\r\n", next unless $TT;
	$TT =~ tr/[A-Z]/[a-z]/;
	
	print STDOUT "# FULL $TT $serverhandle $HANDLE\r\n"; 

	open(OUTLINE, "$ROADS::Config/outlines/$TT") 
	    || print STDOUT "Can't open outline $ROADS::Config/outlines/$TT: $!", next;
	while(<OUTLINE>) {
	    chomp;
	    next if /^template-type:/i;
	    next if /^handle:/i;

	    s/:.*//;
	    $check = $_;
	    $check =~ tr/[a-z]/[A-Z]/;
	    print STDOUT "% 204 $check\r\n" if $debug;
	    #next unless grep(/$check/i, (keys %{ $RestrictFields{"$TT"} }));
	    $gotcha = "n";
	    foreach $restrictfield (keys %{ $RestrictFields{"$TT"} }) {
		print STDOUT "% 204 comparing $check with $restrictfield\r\n"
		  if $debug;
		if (lc($check) eq lc($restrictfield)) {
		    $gotcha = "y";
		    last;
		}
	    }
	    next unless $gotcha eq "y";

	    print STDOUT "% 204 check OK\r\n" if $debug;

	    unless (/\(/ || /-v\*/i) { # plain attrib 
		&prettyprint(" $AV{$check}\r\n") if $AV{"$check"};
		next;
	    }
	    
	    unless (/\(/) { # unclustered variant
		$base = $_;
		$base =~ s/-v\*//i;
		$variant=1;
		while(1) {
		    print STDOUT "% 204 looking for variant $base-v$variant\r\n"
		        if $debug;
		    @cluster = grep(/$base-v$variant$/i, @avkeys);
		    last if $#cluster < 0;
		    foreach (@cluster) { &prettyprint(" $AV{$_}\r\n"); }
		    $variant++;
		}
		next;
	    }
	    
	    # must be including a cluster here...
	    $base=$include="";
	    $_ =~ tr/[a-z]/[A-Z]/;
	    /^([^\(]+)\(([^\*]+)\*\)/ && ($base = $1, $include = $2);
	    $variant=1;
	    while(1) {
		print STDOUT "% 204 looking for cluster $base($include)-V$variant\n" 
		    if $debug;
		@cluster = grep(/$base.+-V$variant$/i, @avkeys);
		last if $#cluster < 0;
		foreach (@cluster) { &prettyprint(" $AV{$_}\r\n"); }
		$variant++;
	    }
	}
	close(OUTLINE);
	print STDOUT "# END\r\n\r\n";
    }
}

#
# call the index code to actually do the search
#
sub dosearch {
    my($query) = @_;
    my($hitdb)=0;

    @allwords = ();
    %matchlist = 
	&index_search($restrictfile,$expansionfile,$stoplistfile,
                        $query,$considercase,$stemming,$indexfile);
    @hits = (keys %matchlist);

    $num_hits = $#hits;
    $num_hits++;

    return @hits;
}

sub prettyprint {
  local($_)=@_;

  if (length($_) < 70) { print STDOUT "$_"; return; }

  s/\s+/ /g;

  if (/^(.{75})(.*)/) {
    print STDOUT "$1\r\n";
    &prettyprint("+$2\r\n");
  } else {
    print STDOUT "$_\r\n";
  }
}

sub system_command {
    my($command,$directive)=@_;
    my($template,$count);

    $command =~ tr/[A-Z]/[a-z]/;

    # don't implement these - yet!
    next if $command eq "polled-by";
    next if $command eq "polled-for";

    # Check to see if we're talking to something that wants to use CIP v3
    if ($command =~ /^# CIP-Version: (.+)$/i) {
      if ($1 ne "3") {
        print STDOUT "% 500 CIP Version not supported\r\n";
      } else {
        &CIPv3PollHandler(\*NEWSOCK,$iafa_source,$target_index);
      }
      exit;
    }

    # Process the poll command to generate a centroid
    if ($command =~ /poll/ && $directive eq "poll") {
       &PollCommand(\*NEWSOCK,$iafa_source,$target_index);
       return;
    }

    if ($command eq "commands") {
        print STDOUT <<EOF;
# FULL COMMANDS $serverhandle COMMANDS\r
 Commands: commands\r
-constraints\r
-describe\r
-help\r
-list\r
-poll\r
-polled-by\r
-polled-for\r
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
 Range: full,abridged,summary,handle\r
# END\r
# FULL CONSTRAINT $serverhandle CONSTRAINT2\r
 Constraint: maxhits\r
 Default: $default_maxhits\r
# END\r
# FULL CONSTRAINT $serverhandle CONSTRAINT3\r
 Constraint: search\r
 Default: exact\r
 Range: exact,lstring\r
# END\r
# FULL CONSTRAINT $serverhandle CONSTRAINT4\r
 Constraint: maxfull\r
 Default: $default_maxfull\r
# END\r
# FULL CONSTRAINT $serverhandle CONSTRAINT5\r
 Constraint: case\r
 Range: consider,ignore\r
 Default: $caseful\r
# END\r
# FULL CONSTRAINT $serverhandle CONSTRAINT6\r
 Constraint: hold\r
# END\r
EOF
        return;
}

    if ($command eq "describe") {
        print STDOUT <<EOF;
# FULL SERVICES $serverhandle SERVICES\r
 Text: This is an LUT WHOIS++ server with a\r
-ROADS database for a backend.\r
-\r
-You can get more information by issuing the command\r
-HELP, or HELP <SUBJECT>\r
# END\r
EOF
        return;
    }

    if ($command eq "?" || $command eq "help") {
        print STDOUT <<EOF;
# FULL HELP $serverhandle HELP\r
 Command: HELP\r
 Usage: HELP [command]\r
 Text: The command HELP can take one argument.\r
 NB: The HELP templates aren't built-in to the server!\r
# END\r
EOF
        return;
    }

    if ($command eq "list") {
        print STDOUT "# FULL LIST $serverhandle LIST\r\n";
        print STDOUT " Templates: ";
        opendir(OUTLINEDIR, "$ROADS::Config/outlines")
          || &WriteToErrorLogAndDie("wppd",
               "couldn't open $ROADS::Config/outlines: $!");
        $count = 0;
        while($template = readdir(OUTLINEDIR)) {
            chomp;
            next if $template =~ /^\./;
            if ($count == 0) {
                print STDOUT " $template\r\n";
            } else {
                print STDOUT "-$template\r\n";
            }
            $count++;
        }
        close(OUTLINEDIR);
        print STDOUT "\r\n" if $count == 0;
        print STDOUT "# END\r\n";
        return;
    }

    if ($command =~ /show\s+([^\s]+)/) {
        $template = $1;
        $template =~ s/\.\\//g;
        print STDOUT "# FULL $template $serverhandle $template\r\n";
        open (TEMPLATE, "$ROADS::Config/outlines/$template")
          || &WriteToErrorLogAndDie("wppd",
               "couldn't open $ROADS::Config/outlines/$template: $!");
        while(<TEMPLATE>) {
          chomp;
          s/:.*/:/;       ### should be expanding clusters/variants ? ###
          print STDOUT " $_\r\n";
        }
        close(TEMPLATE);
        print STDOUT "# END\r\n";
        return;
    }

    if ($command eq "version") {
        print STDOUT <<EOF;
# FULL VERSION $serverhandle VERSION\r
 Version: 1.0\r
 Program-Name: ROADS\r
 Program-Version: $ROADS::Version\r
 Program-Author: Martin Hamilton\r
 Program-Author-Email: m.t.hamilton\@lut.ac.uk\r
 Program-Author: Jon Knight\r
 Program-Author-Email: j.p.knight\@lut.ac.uk\r
 Bug-Report-Email: roads-liaison\@bris.ac.uk\r
# END\r
EOF
        return;
    }
}

# write WHOIS++ server log file entry in WWW common log file format
sub wpp_log {
    ($num_hits, $num_referrals) = @_;

    if ($to_log eq "yes") {
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
	($gsec,$gmin,$ghour,$gmday,$gmon,$gyear,$gwday,$gyday,$gisdst)
	    = gmtime;
	$offset = $hour - $ghour;
	    
	$datestr = sprintf("%02d/%s/%4d:%02d:%02d:%02d %s%02d00", $mday, 
			   $MON[$mon + 1], $year + 1900, $hour, $min, $sec, 
			   $offset >= 0 ? '+' : '-', $offset);
	    
	open(HITLOG,">>$hitlog")
	    || &WriteToErrorLog("wppd", "couldn't open $hitlog: $!");
	flock(HITLOG,2);
	printf HITLOG "%s - %s [%s] \"%s\" %d %d\n",
	  $clientname ? $clientname : $printableaddr,
          $GLOB{name} ? $GLOB{name} : "-",
	  $datestr, 
	  $log_query,
	  $num_hits,
  	  $num_referrals;
	  # places reserved for ident info and auth name
        flock(HITLOG,8);
	close(HITLOG);
    }
}
__END__


=head1 NAME

B<bin/wppd.pl> - LUT WHOIS++ server

=head1 SYNOPSIS

  bin/wppd.pl [-cCdDiLR] [-a admin-maxhits] [-e expansions]
    [-f maxfull] [-g wgipath] [-h serverhandle]
    [-l logfile] [-m maxhits] [-p portnumber]
    [-r restrictionsfile] [-s sourcedir]
    [-S stoplistfile] [-T thesaurus_prog] [-t indexdir]
 
=head1 DESCRIPTION

This is a WHOIS++ server (see RFC 1835) which can be used to make
the contents of the ROADS server's database available for searching
over the Internet using the WHOIS++ protocol.

=head1 OPTIONS

=over 4

=item B<-a> I<admin-maxhits>

Administratively assigned upper limit on the number of hits which
may be returned in response to a search.

=item B<-c>

Make searches case sensitive - by default they are case insensitive,
i.e. the case of the letters in search terms is ignored.

=item B<-C>

Whether or not to return a hit count with the WHOIS++ response.

=item B<-d>

Return debugging information in the WHOIS++ protocol stream.

=item B<-D>

Do DNS lookups to find out the client's hostname - off by default,
since it results in lots of unnecessary traffic.  You can always
do this in a batch job later on using the server logs.

=item B<-e> I<expansions>

File containing list of expansions to use in stemming search, e.g.

  colour color

indicates that all instances of the search term I<colour> should
automatically be expanded to consider the search term I<color>
too.

=item B<-f> I<maxfull>

Sets the default upper limit on the number of records which may
be returned in full.  The server administrator can set an upper
limit on this value, and the client can indicate in their request 
how many records they would like to be returned in full - though
there is no guarantee the server will honour this request.

=item B<-g> I<wgipath>

Path to WHOIS++ Gateway Interface (WGI) executable which should
be run on receiving a request.  Off by default.

=item B<-h> I<serverhandle>

Server handle, unique ID for your server.  This should be set by
the ROADS installation program, but you can override it here.

=item B<-i>

Don't keep an in-memory cache of the database index.  We do this
by default because it speeds up searching.  If your machine only
has a small amount of RAM you might prefer to read the index off
disk rather than cache it in memory.

=item B<-L>

Whether to log search terms and hit counts.  The default is to
keep logs of these things.

=item B<-l> I<logfile>

The name of the file where log entries should be placed.

=item B<-m> I<maxhits>

The default maximum number of hits to return.  The client can 
request an alternative upper limit, but there is no guarantee
that the server will honour this request.  In particular, the
server administrator may have set an adminstratively defined
upper limit which is lower than the value requested by the
client.

=item B<-p> I<portnumber>

The TCP port number to listen on.  You will need to run the
server as root if you want it to listen on ports less than
1023.  This is discouraged.

=item B<-r> I<restrictionsfile>

File to look in for search restrictions.  This is a list of
the templates, and attributes within those templates, which 
the ordinary user will be allowed to search on.  Anything
which does not appear in this file will be ignored.

=item B<-R>

Use access control lists.

=item B<-s> I<sourcedir>

This is the directory where the ROADS database may be found,
if different from the default.

=item B<-S> I<stoplistfile>

This is the file in which the stoplist used when building the database
index may be found.  Words which appear in here are silently discarded
when they're searched for.  For example, if the word "the" was in the
stoplistfile, a search for "the AND big AND breakfast" would be
trimmed to "big AND breakfast."

=item B<-T> I<thesaurus_prog>

This is the location of WHOIS++ Gateway Interface (WGI) conformant 
thesaurus program.

=item B<-t> I<index>

This is the location of the ROADS database index.

=back

=head1 FILES

I<config/admin-restrict> - search restrictions for admin users.

I<config/adminpasswd> - password(s) for admin users in
I</etc/passwd> format.

I<config/expansions> - list of simple query expansions, e.g.
'color' to 'colour'.

I<config/hostsallow> - TCP wrapper format list of client domain
names and IP addresses, and allowed operations.

I<config/outlines> - template outline definitions (schemas).

I<config/search-restrict> - search restrictions for end users.

I<guts/alltemps> - list of template handle to filename mappings.

I<guts/index*> - database index used in searching.

I<guts/wppd.pid> - WHOIS++ server process ID.

I<source> - the actual templates themselves.

=head1 SEE ALSO

L<bin/wppdc.pl>, L<admin-cgi/wppdc.pl>, L<bin/snarf.pl>,
L<cgi-bin/search.pl>, L<admin-cgi/admin.pl>, ...

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

Martin Hamilton E<lt>martinh@gnu.orgE<gt>,
Jon Knight E<lt>jon@net.lut.ac.ukE<gt>,
with apologies to Tom Christiansen, and Larry Wall :-)

