#!/usr/bin/perl
use lib "/home/roads2/lib";

# search.pl - search WHOIS++ servers via WWW CGI interface
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#         Martin Hamilton <martinh@gnu.org>
# $Id: search.pl,v 3.27 1999/07/29 14:39:54 martin Exp $

# Fix for stupid Netscape server bug/misfeature
close(STDERR) if $ENV{"SERVER_NAME"} =~ /netscape/i;

use Getopt::Std;
use File::Basename;

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::DatabaseNames;
use ROADS::ErrorLogging;
use ROADS::HTMLOut;
use ROADS::Index;
use ROADS::Override;
use ROADS::Rank;
use ROADS::Render;
use ROADS::WPPC;
use ROADS::MeshTraversal;

# Handle command line parameters
getopts('C:L:df:l:o:u:v:w:');

#
# Globals
#

# Get the name that this script was called under.
$scriptname = basename($0,".pl");

if ($scriptname =~ /^nph-(.*)$/) {
    $run_as_nph = 1;
    $scriptname = $1;
} else {
    $run_as_nph = 0;
}

# Source for the HTML FORM
$htmlform = $opt_f || "$scriptname.html";
# Logfile to record hits from queries in.
$hitlog = $opt_l || "$ROADS::Logs/$scriptname"."-hits";
# Protocol schemes to override
$protocols = $opt_o || "$ROADS::Config/protocols";
# The URL of this script
$myurl = $opt_u 
  || $scriptname eq "admin" ? "/$ROADS::WWWAdminCgi/$scriptname.pl"
       : "/$ROADS::WWWCgiBin/$scriptname.pl";
# Stoplist for result rendering
$stopfile = "$ROADS::Config/stoplist";
# Result view
$view = $opt_v || "default";
# The URL of the "waylay" script (sits between result listing and object)
$waylay = $opt_w || "/$ROADS::WWWCgiBin/waylay.pl";
# What language to return
$Language = $opt_L || "en-uk";
# What character set to use.
$CharSet = $opt_C || "ISO-8859-1";

# Set up a signal handler for SIGALRM
$SIG{'ALRM'} = 'signalhandler';

#
# Main code
#

# Set up an alarm call for 1 hours time (in case something goes wrong and we
# end up hanging about far longer than we should).  Not that there are any
# HTTP daemons which have this problem, oh no... ;-)
alarm(3600);

if ($run_as_nph) {
    $the_date = gmtime;

    print <<EOF
HTTP/1.0 200 OK
Date: $the_date
Server: ROADScgi/0.0
Connection: close
Content-type: text/html

<!-- gratuitous comment -->
EOF
    ;
} else {
    print "Content-type: text/html\n\n";
}

&initStoplist($stopfile) unless $StoplistInit;
&ReadDBNames;
Override;
&cleaveargs;
if ($scriptname eq "admin") {
  &CheckUserAuth("admin_users");
} else {
  &CheckUserAuth("search_users");
}

$debug = $opt_d || $CGIvar{debug};
$CGIvar{stemming} = "off" unless ($CGIvar{stemming} eq "on" || $CGIvar{stemming} eq "sub");
$CGIvar{highlight} = "off" unless $CGIvar{highlight} eq "on";
$CGIvar{ranking} = "off" unless $CGIvar{ranking} eq "on";

if ($debug) { 
    foreach (keys %CGIvar) { 
        print STDOUT "CGI variable: $_: $CGIvar{$_}\n";
    }
}

# Change the output language if specified in either the HTTP headers or the
# CGI variables passed from the browser.
if($ENV{"HTTP_ACCEPT_LANGUAGE"} ne "") {
    $Language = $ENV{"HTTP_ACCEPT_LANGUAGE"};
}
if($CGIvar{language} ne "") {
    $Language = $CGIvar{language};
}

# Change the character set if specified in either the HTTP headers of the
# CGI variables passed from the browser.
if($ENV{"HTTP_ACCEPT_CHARSET"} ne "") {
    $CharSet = $ENV{"HTTP_ACCEPT_CHARSET"};
}
if($CGIvar{charset} ne "") {
    $CharSet = $CGIvar{charset};
}

if ($CGIvar{headlines} eq "on") { # keep for backwards compatibility
  $view = "headlines";
}

if($CGIvar{boolean} eq "") {
    $CGIvar{boolean} = "and";
}

if (defined($CGIvar{view})) { # this is much more flexible - use it!
  $view = $CGIvar{view};
  $view =~ tr/[A-Za-z0-9]//c; # this is going to be a directory name
}

if (defined($CGIvar{form})) { # lets us choose the form independently
  $htmlform = $CGIvar{form};
  $htmlform =~ tr/[A-Za-z0-9]//c; # this is going to be a file name
  $htmlform .= ".html";
}

if ($ENV{QUERY_STRING} eq "" ||
    (defined($CGIvar{form}) && $CGIvar{query} eq "" && $CGIvar{term1} eq ""
     && $CGIvar{term2} eq "" && $CGIvar{term3} eq "")) {

    &OutputHTML($scriptname, $htmlform,$Language,$CharSet);
    exit;
}

if (defined($ROADS::DodgySyntax)) {
    if ($CGIvar{query} =~ /$ROADS::DodgySyntax/) {
	&OutputHTML($scriptname, "syntax.html",$Language,$CharSet);
	exit;
    }
}

if (($CGIvar{term1} eq "") && ($CGIvar{term2} eq "") &&
    ($CGIvar{term3} eq "") && ($CGIvar{query} eq "")) {
    &OutputHTML($scriptname, "nosearchterm.html",$Language,$CharSet);
    exit;
}

if ($CGIvar{query}) {
  # Get a version of the query string that we can display to the user.
  $CGIvar{query} =~ s/\&/ AND /g;
  $CGIvar{query} =~ s/\|/ OR /g;
  $CGIvar{query} =~ s/!/ NOT /g;
  $CGIvar{query} =~ s/\s\s+/ /g;

  @querybits = split(/ /, $CGIvar{query});
} else {
  # Do AND'ing implicitly unless instructed otherwise
  $bop = $CGIvar{boolean};
  if ($bop ne "and" && $bop ne "or") {
    $bop = "and";
  }
  
  $query = "";
  if ($CGIvar{term1}) {
      while ($CGIvar{term1} =~ m/("[^"]*")/) {
          $termstart = $`;
          $termend = $';
          $tempterm = $1;
          $tempterm =~ s/\s/_/g;
          $tempterm =~ s/"//g;
          $CGIvar{term1} = $termstart . " " . $tempterm . " " . $termend;
      }

      if ($CGIvar{attrib1} eq "ANY") {
	  $query = "$CGIvar{term1}";
      } else {
	  $query = "($CGIvar{attrib1}=$CGIvar{term1})";
      }
  }
  if ($CGIvar{term2}) {
      while ($CGIvar{term2} =~ m/("[^"]*")/) {
          $termstart = $`;
          $termend = $';
          $tempterm = $1;
          $tempterm =~ s/\s/_/g;
          $tempterm =~ s/"//g;
          $CGIvar{term2} = $termstart . " " . $tempterm . " " . $termend;
      }

      if ($query) {
	  if ($CGIvar{attrib2} eq "ANY") {
	      $query .= " $bop $CGIvar{term2}";
	  } else {
	      $query .= " $bop ($CGIvar{attrib2}=$CGIvar{term2})";
	  }
      } else {
	  if ($CGIvar{attrib2} eq "ANY") {
	      $query = "$CGIvar{term2}";
	  } else {
	      $query = "($CGIvar{attrib2}=$CGIvar{term2})";
	  }
      }
  }
  if ($CGIvar{term3}) {
      while ($CGIvar{term3} =~ m/("[^"]*")/) {
          $termstart = $`;
          $termend = $';
          $tempterm = $1;
          $tempterm =~ s/\s/_/g;
          $tempterm =~ s/"//g;
          $CGIvar{term3} = $termstart . " " . $tempterm . " " . $termend;
      }

      if ($query) {
	  if ($CGIvar{attrib3} eq "ANY") {
	      $query .= " $bop $CGIvar{term3}";
	  } else {
	      $query .= " $bop ($CGIvar{attrib3}=$CGIvar{term3})";
	  }
      } else {
	  if ($CGIvar{attrib3} eq "ANY") {
	      $query = "$CGIvar{term3}";
	  } else {
	      $query = "($CGIvar{attrib3}=$CGIvar{term3})";
	  }
      }
  }
  @querybits = split(/ /, $query);
}
  
# Implicitly AND if necessary
$skipping = 0;
foreach $querybit (@querybits) {
  next if $querybit =~ /^$/;

  # make a note of whether we're in skipping mode
  $skipping = 1 if $querybit =~ /^"/;
  if ($skipping) {
    if (defined($displayquery)) {
      $displayquery = "$displayquery $querybit";
    } else {
      $displayquery = "$querybit";
    }
    $skipping = 0 if $querybit =~ /"$/;
    next;
  }

  # initialise query string
  unless (defined($displayquery)) {
    if ($querybit !~ /^(and|or)$/i) {
      $displayquery = "$querybit";
    }
    next;
  }

  # deal with ordinary terms
  unless ($querybit =~ /^(and|or|not)$/i) {
    # don't implicitly AND if the query ends in a Boolean operator
    if ($displayquery =~ / \(*(and|or|not)$/i) {
      $displayquery .= " $querybit";
    } else {
      $displayquery .= " AND $querybit";
    }
    next;
  }

  # deal with Boolean operators
  $displayquery .= " $querybit";
}

undef (@results,@add,@tempstore);

if ($CGIvar{stemming} eq "on") { push(@add, "search=lstring"); }
if ($CGIvar{stemming} eq "sub") { push(@add, "search=substring"); }
if ($CGIvar{debug} eq "on") { push(@add, "debug"); }
if ($CGIvar{caseful} eq "on") { push(@add, "case=consider"); }

# If we're the admin script then we need to authenticate ourselves to the
# whois++ server.  This is duff way we do it at the moment.
if($scriptname eq "admin") {
  push(@add, "authenticate=yes");
  push(@add, "name=admin");
  push(@add, "password=roads");
}

if ($#add >= 0) {
    $globals = join(";", @add);

    $displayquery =~ s/\s+$//;
    if ($displayquery =~ /:[^:]+$/) {
        $displayquery .= ";$globals";
    } else {
        $displayquery .= ":$globals";
    }
}

$CGIvar{"templatetype"}=~tr/[A-Z]/[a-z]/;
unless ($CGIvar{"templatetype"} =~ /^all$/i) {
    $displayquery = "template=$CGIvar{\"templatetype\"} and $displayquery";
}

# Do the searches over the selected databases, returning the hits in the
# configured log file.
&ReadDBNames;
undef %QueriedServers;
if($CGIvar{database} eq "ALL" || $CGIvar{database} eq "") {
    foreach $dbname (keys %database) {
        push(@{$search{"$host{$dbname} $port{$dbname}"}},$dbname);
    }
    foreach $hostport (keys %search) {
        local($targethost,$targetport) = split(" ",$hostport);
        $disjunction = "";
        $destination = "";
        foreach $destdb (@{$search{"$targethost $targetport"}}) {
            next if ($database{$destdb} eq "");
            $destination = $destination.$disjunction."destination=".
              $database{$destdb};
            $disjunction = " or "; 
            $QueriedServers{$serverhandle{$destdb}} = 1;
        }
        if($destination ne "") {
          if (length($globals) > 0) {
              $query = "($destination) and ($displayquery";
              $query =~ s/\s\(([^:]+):/ ($1):/;
          } else {
              $query = "($destination) and ($displayquery)";
	  }
        } else {
          $query = $displayquery;
        }
        print STDOUT "[<EM>Searching host '$targethost', port '$targetport'"
	    . "with query '$query'</EM>]<P>\n" if $debug;
        @tempstore = &wppc($targethost, $targetport, $query);
        if ($tempstore[0] =~ /noconnect/) {
            $oops = "noconnect";
        } else {
            push(@results, @tempstore);
        }
    }
} else {
    foreach $dbname (split(/,/, $CGIvar{database})) {
        push(@{$search{"$host{$dbname} $port{$dbname}"}},$dbname);
    }
    foreach $hostport (keys %search) {
        local($targethost,$targetport) = split(" ",$hostport);
        $disjunction = "";
        $destination = "";
        foreach $destdb (@{$search{"$targethost $targetport"}}) {
            next if ($database{$destdb} eq "");
            $destination = $destination.$disjunction."destination=".
              $database{$destdb};
            $disjunction = " or ";
            $QueriedServers{$serverhandle{$destdb}} = 1;
        }
        if($destination ne "") {
          if (length($globals) > 0) {
              $query = "($destination) and ($displayquery";
              $query =~ s/\s\(([^:]+):/ ($1):/;
          } else {
              $query = "($destination) and ($displayquery)";
          }
        } else {
          $query = $displayquery;
        }
        print STDOUT "[<EM>Searching host '$targethost', port '$targetport'"
	    . " with query '$query'</EM>]<P>\n" if $debug;
        @tempstore = &wppc($targethost, $targetport, $query);
        if ($tempstore[0] =~ /noconnect/) {
            $oops = "noconnect";
        } else {
            push(@results, @tempstore);
        }
    }
}

$bogons=0;

$localtotal=0;
foreach (@results) {
    next unless /^localcount:(\d+)/;
    $localtotal += $1;
    $bogons++;
}

$referraltotal=0;
foreach (@results) {
    next unless /^referralcount:(\d+)/;
    $referraltotal += $1;
    $bogons++;
}

if ($CGIvar{referrals} eq "on") {
    # Time to do WHOIS++ mesh traversal if applicable.  This is tucked inside
    # a module for neatness (and reusability/maintainability).  The CGI
    # variable maxserver comes from the search form and specifies the maximum
    # number of servers to query duing mesh traversal.
    push(@results,
      &traversemesh($displayquery,$CGIvar{maxserver},$debug,@results));
}

if ($debug) { 
    print STDOUT "<H2>Raw Results:</H2>\n";
    foreach (@results) { 
        print STDOUT "hit... $_<BR>\n";
    }
    print STDOUT "<HR>\n";
}

# rank the results 
@ranked_results =
  ($CGIvar{ranking} eq "on") ? &rank($displayquery,@results) : @results;

# write hit search stats in common log format
@MON = ('Dummy', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
        'Aug', 'Sep', 'Oct', 'Nov', 'Dec');

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
($gsec,$gmin,$ghour,$gmday,$gmon,$gyear,$gwday,$gyday,$gisdst)
    = gmtime;
$offset = $hour - $ghour;

$datestr = sprintf("%02d/%s/%4d:%02d:%02d:%02d %s%02d00", $mday, 
		   $MON[$mon + 1], $year + 1900, $hour, $min, $sec, 
		   $offset >= 0 ? '+' : '-', $offset);

open(HITLOG,">>$hitlog")
    || &WriteToErrorLog("$0", "couldn't open $hitlog: $!");
flock(HITLOG,2);
printf HITLOG "%s %s %s [%s] \"%s\" %d %d\n",
    $ENV{REMOTE_HOST} ? $ENV{REMOTE_HOST} : $ENV{REMOTE_ADDR},
    $ENV{REMOTE_IDENT} ? $ENV{REMOTE_IDENT} : "-",
    $ENV{REMOTE_USER} ? $ENV{REMOTE_USER} : "-",
    $datestr, 
    $query,
    $localtotal,
    $referraltotal;
flock(HITLOG,8);
close(HITLOG);

if (($#ranked_results - $bogons) < 0) {
    $query = $displayquery;
    &OutputHTML($scriptname,
      $oops eq "noconnect" ? "noconnect.html" : "nohits.html",$Language,
      $CharSet);
    exit 0;
}

# render the results as HTML
&render($displayquery, $view, @ranked_results);

exit 0;


#
# Signal handler subroutine - mainly to handle SIGALRM in order to commit
# suicide when crappy CERN httpd's leave us lying around for hours.  We don't
# write anything anywhere as we don't know what state we're in at the moment.
#
sub signalhandler {
    exit(0);
}

exit;
__END__


=head1 NAME

B<cgi-bin/search.pl> - user/admin CGI front end to ROADS search

=head1 SYNOPSIS

  cgi-bin/search.pl> [-C charset] [-L language] [-d]
    [-f form] [-l logfile] [-o protocols] [-u url]
    [-v view] [-w waylay_url]

I<aka> B<admin.pl>

=head1 DESCRIPTION

The B<search.pl> program is a Common Gateway Interface (CGI) program used
to provide an end user search front end to ROADS databases.  When accessed
with no CGI query, the program can return an HTML form to the user to fill
in to make a query.  This form can be customized by the ROADS administrator
and can include a number of options.

When the ROADS software is installed, a symbolic link to the program is
made from the ROADS I<admin-cgi> directory under the name B<admin.pl>.
You may find that following symbolic links is disabled by default on your
server for security reasons, though this can usually be overridden on a
per directory basis.  We used to actually copy I<cgi-bin/search.pl> over
to I<admin-cgi/admin.pl>, but this made maintenance unnecessarily complex.

It is desirable to differentiate between the search
program running as an admin user (who will be able to edit, create and
delete records) and the search program running as an end user (who will
only be able to search for and view records).  This differentiation is done
in practice by checking the name by which the program was invoked. 

=head1 USAGE

The ROADS software comes with its own search subsystem, which is
capable of dealing with small to medium size databases of tens of
thousands of records.  This consists of a Common Gateway Interface (CGI)
based WWW front end, and as the back end, a WHOIS++ server which uses
a simple inverted index.  Whilst using our WHOIS++ implementation has
benefits for distributed searching, it's not essential that you use
this - e.g. we also provide tools to convert your ROADS data into a
variety of other formats, such as the Summary Object Interchange Format
(SOIF) used by Harvest and Glimpse, the Generic Record Syntax (GRS-1)
format used by some Z39.50 servers, and the input format used by
Bunyip's Digger WHOIS++ server.

The basic model for searching using the ROADS software is as follows:

=over 4

=item 1. Query submitted by end user via HTML form.

=item 2. WWW search front end parses query and passes on to any number of
back end WHOIS++ servers.

=item 3. WHOIS++ servers return search results.

=item 4. WWW search front end parses results and constructs an HTML
document from them.

=back

Queries may consist of:

=over 4

=item *

single terms, e.g. I<podule>, which will be matched in the
right side of any records they occur in.

=item *

attribute/value pairs, e.g. I<title=podule>, which will be
matched in the specific attribute's value.

=item *

Phrases, such as I<podule module>, which match the words
supplied if they occur in the value component of a record with no
other intervening text.

=back

These may be combined in Boolean expressions, e.g.
I<template=DOCUMENT and title=podule>, each component of which will
be evaluated separately and the results combined.  Brackets may be
used to group Booleans together.  Boolean support extends to the
B<AND>, B<OR> and B<NOT> operations, though
B<NOT> is not recommended and may not work entirely as expected in
complex expressions.

In addition, it is possible to constrain a search to a particular
WHOIS++ server, search case sensitively or insensitively, display only
the titles of the results, rank the results according to relevance,
use stemming to match other similar words in addition to the ones
supplied in the query, and perform query expansion using a thesaurus.
All but the last of these options is configurable at search-time,
whereas the thesaurus support is either enabled or disabled for
searches as a whole.

=head1 SEARCHING ACROSS MULTIPLE WHOIS++ SERVERS

The default ROADS configuration assumes that you are going to run a
single WHOIS++ server to make your ROADS database available for
searching.  A side effect of the use of WHOIS++ in searching is that
it is also possible to search other WHOIS++ servers.  You can tell
your ROADS installation about other WHOIS++ servers by editing the
file I<config/databases>, to add their names and addresses.

With the default configuration we ship, the names of the other WHOIS++
servers your ROADS installation knows about will appear on the HTML
returned by the ROADS search tool I<search.pl>.  You may wish to
alter the HTML outline for this page to list only those WHOIS++
servers you want to make visible to end users.  The end user can
choose to have their search directed some or all of these, and
I<search.pl> will combine the results and present them in the form of
HTML.  See also L<bin/wig.pl> for a more advanced way of searching
across multiple servers using I<centroids>.

Note that whilst you may be able to see multiple WHOIS++ servers using
the admin search tool I<admin.pl>, you can only edit ROADS database
entries which are held locally.

=head1 ALTERING SEARCH BEHAVIOUR

Within the ROADS search subsystem there are a number of possibilities
for local customisation (without modifying any code), substitution of
locally written code for individual modules of the search subsystem,
and enabling or disabling search features:

=over 4

=item *

The CGI based search front end comes with a number of
configurable options which are exposed to the end user by default.
You may wish to hide some or all of these, e.g. to create ``simple''
and ``advanced'' search forms.  This can be done by editing the
outline HTML in I<config/multilingual/*/search/search.html> and
also I<config/multilingual/*/admin/search.html>.  We suggest that
you make form elements which you would like to hide from your end
users into hidden fields.

=item *

You can alter the way the search results are rendered into HTML
by editing the outline HTML files in
I<config/multilingual/*/search-views> and
I<config/multilingual/*/admin-views>.

=item *

You can control which URL schemes are redirected to help pages
in rendering the search results by putting their names in the file
I<config/protocols>.  This is done by default for the
B<mailto>, B<wais> and URL schemes other than B<ftp>,
B<gopher> and B<http>, and the outline HTML files can be found in
I<config/multilingual/*/waylay>.

=item *

The code used in ranking search results and rendering them into
HTML lives in separate modules I<ROADS::Rank> and I<ROADS::Render>
respectively, and can easily be updated or replaced as necessary.

=item *

The search and retrieval capability provided by the ROADS
WHOIS++ server may be augmented by an external thesaurus module -
this can be any arbitrary piece of code which will take a word or
words, and perform query expansion on them.  We also provide an
internal query expansion capability which is intended for use with a
small number of commonly occurring words, e.g. to expand ``colour''
to match ``color''.  This is configured by editing the file
I<config/expansions>.

=item *

The search component of the WHOIS++ server may effectively be
replaced by any piece of code which implements the WHOIS++ Gateway
Interface, described in a separate document.  This provides a way to
use alternative back end databases with the ROADS software without
having to do any network programming.  WGI is also used to implement
the external thesaurus feature.  The locations of these WGI programs
may be specified in I<ROADS.pm> as the variables B<WGIPath>
and B<WGIThesaurus> respectively.

=back

=head1 SEARCH RESTRICTIONS

It is assumed that you will not want to make all of the information in
your templates visible to the world at large.  The attributes which
can be searched on and the information which appears when a template
is rendered into HTML are limited to those attributes and templates
which are listed in the file I<config/search-restrict> under the
top level ROADS installation directory.  The I<admin.pl> program
has its own list of restrictions in the file
I<config/admin-restrict>.

The defaults shipped have entries for a small subset of the attributes
which may be found in the B<DOCUMENT>, B<SERVICE> and
B<USER> templates.  If you want your users to be able to search
on or see the contents of any other templates, you will need to add
them to one or both of these lists.  More information is provided on
the I<admin.pl> manual page and the I<search.pl> manual
page.

=head1 OPTIONS

=over 4

=item B<-C> I<charset>

Character set to use.

=item B<-L> I<language>

Language to use.

=item B<-d>

Whether to run in debug mode or not - default is not.

=item B<-f> I<form>

The default HTML form to return to the end user.

=item B<-l> I<logfile>

Log file to record search requests and results in

=item B<-o> I<protocols>

Protocols to override using the B<waylay.pl> program.

=item B<-u> I<url>

The URL of this program

=item B<-v> I<view>

The search results view to use

=item B<-w> I<waylay_url>

The URL of the B<waylay.pl> program.  See its documentation for more
information.

=back

=head1 CGI VARIABLES

There are a number of inputs that the form must have for the program to
execute correctly; these are listed below.  Note that the end user need
not necessarily be presented with these on their browser if an input type
of "hidden" is used.

It is important to note that there are two way of composing queries -
one way is to use a simple text entry box B<query>, and the other is
to use up to three attribute/value pairs, e.g. B<attrib1> and B<term1>
would comprise one attribute/value pair.  In the HTML form which the
user fills in to generate a query, the attributes, the values, or even
both, may be generated using a combination of HTML elements such as
drop down lists and text entry boxes.  This can be used to provide
(for example) a way of selecting the attribute to search on using an
HTML SELECT menu, or to constrain the value being searched for
similarly.

=over 4

=item B<attrib[123]>

When constructing the query out of attribute/value pairs, these
variables are the attributes corresponding to the terms B<term[123]>.

=item B<boolean>

When constructing the query out of a combination of B<attrib[123]> and
B<term[123]>, this CGI variable specifies the Boolean operator which
should be used.  The only sensible choices for this are "and" and
"or".

=item B<caseful>

This is a Boolean variable that specifies whether a search should be
case sensitive or not.  The value "on" specifies that the search should
take notice of the case of the terms, any other value (or none at all)
implies that the search will be case insensitive.

=item B<charset>

The character set to use.

=item B<database>

This is a CGI variable that allows the database(s) that are to be
searched for the query in this form to be specified.  A fake database
name of "ALL" tells the B<search.pl> program to search through all the
databases it knows about.

=item B<debug>

This is a Boolean variable which specifies whether the B<search.pl>
program should operate in debug mode - in debug mode it generates
copious extra HTML documenting its progress.

=item B<form>

The HTML form to return to the end user if no query is supplied.  The
default form is I<search.html>.  This will be the name of a file in
the I<config/multilingual/*/search/> directory, or the
I<config/multilingual/*/admin/> directory.

=item B<headlines>

This is a Boolean variable that specifies whether a search should
return headlines instead of full template discriptions.  It is
included for compatibility with previous versions of ROADS, and
actually has the effect of setting the results "view" to "headlines".

=item B<highlight>

This is a Boolean variable which specifies whether search results
should have matches (rendered in bold) for the original query
highlighted.

=item B<language>

The language to use.

=item B<query>

This is the query as entered by the user.  This will typically be a
text input element in the form.  See also the CGI variables
B<admin[123]> and B<term[123]>.

=item B<ranking>

This is a Boolean variable which specifies whether the results should
be ranked into order, based on the frequency with which the words in
the query occur in the records which were returned as a result of the
search.

=item B<referrals>

A Boolean variable specifying whether or not the B<search.pl> program
should follow referrals generated in the process of carrying out a
WHOIS++ search.

=item B<stemming>

This is a Boolean variable which indicates to B<search.pl> whether the
query terms should be stemmed when searching the database.  The ROADS
software currently implements the Porter stemming algorithm, with
hooks for user supplied stemming or thesaurus lookup.  If the value
"on" is returned, the software will use stemming, otherwise the search
terms will be used as is.

=item B<templatetype>

This CGI variable permits the end user or ROADS administrator to limit
the returned resources down to those that are in an IAFA template of
the specified type.  A special template type of "ALL" is understood by
B<search.pl> to mean all template types.  All the template types
should be in upper case.

=item B<term[123]>

When constructing the query out of attribute/value pairs, these fields
are the values corresponding to the attributes B<attrib[123]>.

=item B<view>

The name of a "view" to use when rendering the search results into
HTML.  The default view is "default".  This will be the name of a
subdirectory of I<config/multilingual/*/search-views/> or of
I<config/multilingual/*/admin-views/>.

=back

=head1 FILES

I<config/databases> - known WHOIS++ servers.

I<config/protocols> - protocols to override using B<waylay.pl>.

I<config/multilingual/*/search/nohits.html> - default HTML form
sent to end user when no query is specified.

I<config/multilingual/*/search/noconnect.html> - default HTML form
sent to end user when no query is specified.

I<config/multilingual/*/search/nosearchterm.html> - default HTML form
sent to end user when no query is specified.

I<config/multilingual/*/search/search.html> - default HTML form
sent to end user when no query is specified.

I<config/multilingual/*/search/syntax.html> - default HTML form
sent to end user when no query is specified.

I<config/multilingual/*/search-views/*> - 

I<logs/search-hits> - searches carried out and result details.

All of the I<search> and I<search-views> files and directories
have I<admin> and I<admin-views> equivalents when the program is
run as B<admin.pl>.

=head1 FILE FORMATS

The format of the I<search-hits> and I<admin-hits> logfiles is as per
the WWW Common Log File format :-

=over 4

=item Client domain name

If domain name lookups enabled on HTTP server or IP address.

=item Remote user name

as returned by AUTH/IDENT lookup if enabled on the HTTP server.

=item Remote user name

as provided by HTTP authentication, if authentication is required
by the HTTP server configuration.

=item Date of the request.

=item The query string itself.

=item The number of local hits

i.e. hits resulting from local records on the WHOIS++ servers being queried.

=item The number of referral hits

i.e. hits resulting from referrals sent back by the WHOIS++ servers being
queried.

=back

This file can be used to assess which terms are being searched for
most frequently, how many searches are not matching anything in the
available database and other statistics which may provide useful
feedback to the ROADS administrator.

=head1 SEE ALSO

L<admin-cgi/mktemp.pl>, L<cgi-bin/tempbyhand.pl>

=head1 COPYRIGHT

Copyright (c) 1988, Martin Hamilton E<lt>martinh@gnu.orgE<gt> and Jon
Knight E<lt>jon@net.lut.ac.ukE<gt>.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

It was developed by the Department of Computer Studies at Loughborough
University of Technology, as part of the ROADS project.  ROADS is
funded under the UK Electronic Libraries Programme (eLib), and the
European Commission Telematics for Research Programme, and the TERENA
development programme.

=head1 AUTHOR

Martin Hamilton E<lt>martinh@gnu.orgE<gt>,
Jon Knight E<lt>jon@net.lut.ac.ukE<gt>

