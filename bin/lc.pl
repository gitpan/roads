#!/usr/local/bin/perl
use lib "/home/roads2/lib";

# simple IAFA/HTML link checker
# needs libwww-perl - cf. <URL:http://www.oslonett.no/home/aas/perl/www/>
# recommend you use perl 5.003 or above and libwww-perl 5

# Author: Martin Hamilton <martinh@gnu.org>
# $Id: lc.pl,v 3.16 1998/09/05 14:00:05 martin Exp $

require LWP::Protocol::http;
require LWP::UserAgent;
use Getopt::Std;
use HTML::LinkExtor;
use Cwd;

require ROADS;
use ROADS::ErrorLogging;

getopts("ab:cdg:ilp:Pr:st:uvw:x");
$debug = $opt_d || 0;
$opt_i = 1 if $opt_a;
$sourcedir = $opt_t || "$ROADS::IafaSource";
$gutsdir = $opt_g || "$ROADS::Guts";
$REST = $opt_r || 2;
$BASE = $opt_b || "http://localhost/";
$PWD = getcwd();

# file suffixes which might be expected to be for HTML documents
@HTML = ('htm', 'html', 'shtml');

# checkable protocols for URLs
@PROTO = ('ftp', 'gopher', 'http', 'file', 'wais');

# URL suffixes which won't be checked unless we're in strict mode (-s)
@EX = ('jpg', 'jpeg', 'gif', 'mpg', 'mpeg', 'pl', 'ps', 'gz', 'z', 'tgz',
       'tar', 'doc', 'exe', 'com', 'hqx', 'bin', 'sit', 'lha', 'xbm', 
       'xpm', 'zip', 'c', 'f', 'cpp');

# for now at least we don't want to croak on unknown protocol schemes
URI::URL::strict(0);

$ua = new LWP::UserAgent;
$ua->env_proxy unless $opt_P;
$ua->proxy(['http', 'ftp', 'gopher', 'wais'], $opt_p) if $opt_p;
$ua->agent('lc/$ROADS::Version libwww-perl/5.00')
  if $ROADS::Version; 
$ua->from($ROADS::DBAdminEmail) if $ROADS::DBAdminEmail;


if ($opt_a && -d "$sourcedir") {
  opendir(THISDIR, "$sourcedir") || &WriteToErrorLogAndDie("lc",
                                      "couldn't open $sourcedir: $!");
  @things = readdir(THISDIR);
  closedir(THISDIR);
  chdir("$sourcedir");
} else {
  # get list of things from command line or stdin
  @things = $#ARGV >= 0 ? @ARGV : <STDIN>;
}

dbmopen(%LASTMODIFIED, "$gutsdir/lastmodified", 0644)
    || &WriteToErrorLog("$0", "couldn't open $gutsdir/lastmodified: $!");

dbmopen(%CONTENTLENGTH, "$gutsdir/contentlength", 0644)
    || &WriteToErrorLog("$0", "couldn't open $gutsdir/contentlength: $!");

#
# run through each file/URL in turn
#
foreach $thing (@things) {
  $thing =~ s/\n$//;
  print STDERR "Examining thing... $thing\n" if $debug;

  $opt_x && do (&check_url("URL", $thing), next);

  next if -d $thing; # skip directories!
  next if $thing =~ /^\./; # skip files whose names start with a '.'

  $opt_i && do (&check_iafa($thing), next);

  if ($thing =~ /\.([^\.]+)$/) {
    print STDERR "Checking suffix... $1\n" if $debug;
    unless (grep(/$1/i, @HTML)) { # skip unless file looks like HTML
      print STDERR "Skipping... $thing\n" if $debug;
      next;
    }
    &check_html($thing);
  }
}

dbmclose(%LASTMODIFIED);
dbmclose(%CONTENTLENGTH);

#
# check IAFA style template - may be good for others too!
# NB: assumes UR[IL] fits on one line
#
sub check_iafa {
  my($file) = @_;
  print STDERR "\n check_iafa: file is $file\n" if $debug;
  unless (open(IN, "$file")) {
    print STDERR "Couldn't open $file: $!" if $debug;
    return;
  }

  # skip to URIs/URLs
  while(<IN>) {
    chomp;
    next unless /UR[IL]/; # skip lines which don't contain URL or URI
    /^[^:]+:\s+(.*)/ && &check_url($file, $1); # further sanity check
  }
  close(IN);
}


#
# check HTML documents
#
sub check_html {
  my($file) = @_;
  my($h);

  print STDERR "\n check_html: file is $file, base is $BASE\n" if $debug;
  $h = HTML::LinkExtor->new();
  $h->parse_file("$file");

  print STDERR "\n check_html: looking at list of references\n" if $debug;
  # what follows is the list of references in this document
  foreach $bit ($h->links) {
    my(@bits) = @{ $bit };
    next unless ($bits[0] eq "a" || $bits[0] eq "img");
    $link = $bits[2];

    if ($link =~ m!^\.\.!) {
      $nlink = newlocal URI::URL $link;
    }
    else {
      $nlink = new URI::URL $link;
    }
    $nlink->base($BASE);

    print $nlink->as_string, "\n" if $debug;
    &check_url($file, $nlink->as_string);
  }
}


#
# do the business!
#
sub check_url {
  my($file,$url) = @_;
  my($flagm) = 0;
  my($flagl) = 0;

  unless ($url) {
    print STDERR "  check_url: $file: <no URL!>\n" if $debug;
    print STDERR "$file:no URL\n" if $opt_u;
    return;
  }

  print STDERR "  check_url: $file: $url\n" if $debug;
  if ($opt_l) { print "$file: $url\n"; return; }

  if ($VISITED{$url}) {
    print STDERR "  check_url: already visited $url\n" if $debug;
    print $VISITED{$url} == 0 ? "OK" : "BAD", " $file $url\n";
    return;
  }

  # if not in strict mode, check target is OK before proceeding
  unless ($opt_s) {
    if ($url =~ /\.([^\.\/]+)$/) { # isolate URL suffix, e.g. .mpeg
      $suffix = $1;
      $suffix =~ s/#.*//; # get rid of internal anchor info if present
      print STDERR "  check_url: > suffix... $suffix\n" if $debug;
      if (grep(/$1/i, @EX)) {
        print STDERR "  check_url: > skipping... $file: $1\n" if $debug;
        print STDERR "$file: $url\n" if $opt_u;
        return;
      }
    }

    unless ($opt_c) { # don't check for query/script chars in URL
      if ($url =~ m!/cgi-bin/! || $url =~ m!/htbin/! || $url =~ /\?/) {
        print STDERR "  check_url: > skipping... $file: $url\n" if $debug;
        print STDERR "$file: $url\n" if $opt_u;
        return;
      }
    }

    if ($url =~ /^([^:]+):/) { # check we can speak the protocol
      print STDERR "  check_url: > protocol... $1\n" if $debug;
      unless (grep(/$1/, @PROTO)) {
        print STDERR "  check_url: > skipping... $file: $1\n" if $debug;
        print STDERR "$file: $url\n" if $opt_u;
        return;
      }
    }
  }

  # send only a HEAD request if the protocol is HTTP
  $request = new HTTP::Request $url =~ /^http/ ? 'HEAD' : 'GET', $url;
  $response = $ua->request($request);
  $VISITED{$url} = $response->is_success ? 0 : -1;

  print STDERR "  check_url: > ", $response->is_success ? "ok" : "bad", "\n"
    if $debug;

  print "  Last-Modified: ", $response->last_modified, "\n" if $debug;
  print "  Content-Length: ", $response->content_length, "\n" if $debug;

  if ($response->last_modified) {
    if ($LASTMODIFIED{"$url"}) {
      print "  > comparing ", $LASTMODIFIED{"$url"},
        ": ", $response->last_modified, "\n" if $debug;
      $flagm = 1 if ($LASTMODIFIED{"$url"} ne $response->last_modified);
    }
    $LASTMODIFIED{"$url"} = $response->last_modified;
  }

  if ($response->content_length) {
    if ($CONTENTLENGTH{"$url"}) {
      print "  > comparing ", $CONTENTLENGTH{"$url"},
        ": ", $response->content_length, "\n" if $debug;
      $flagl = 1 if ($CONTENTLENGTH{"$url"} ne $response->content_length);
    }
    $CONTENTLENGTH{"$url"} = $response->content_length;
  }

  sleep($REST);
  unless ($flagm || $flagl) {
    return if ($response->is_success && !$opt_v);
  }
  $modtime = gmtime($response->last_modified);

  if ($opt_w) {
    return unless ($response->code eq 200
          && ($response->last_modified < (60 * 60 * 24 * $opt_w)));
  }

  print $response->code . " $file $url ";
  print "(modified < $opt_w days) " if $opt_w;
  print "(len=", $response->content_length, ") " if $flagl;
  print "(mod=$modtime) " if $flagm;

  print "\n";
}


exit;
__END__


# docs in POD format - use perldoc et al to extricate

=head1 NAME

B<bin/lc.pl> - Perl based HTML/IAFA link checker

=head1 SYNOPSIS

  bin/lc.pl [-acdilPsvux] [-b base_url] [-g guts_dir]
    [-p proxyurl] [-r seconds] [-t templatedir]
    [-w when_changed] [file1 file2 ... fileN]

=head1 DESCRIPTION

This program will take a set of URLs on their own, in a set of IAFA
templates, or in HTML documents and attempt to check their
accessibility.  It can be passed a list of file names to examine on
the command line or via standard input, e.g.

  find . -print | lc.pl -i

or

  lc.pl -v *.html > logfile

Normal behaviour is to ignore directories, files whose names begin
with a dot ".", and files which do not appear to contain HTML - based
on their suffix.  This last restriction can be removed with a command
line option which tells the program to assume the files are all IAFA
templates.

Currently the only URL schemes which can be checked with B<lc.pl> are
"http:", "gopher:", "ftp:" and "wais:".  A future version may try to
check other URL schemes.

B<lc.pl> will not follow links in HTML documents recursively!

=head1 PROXIES AND CACHING

It is recommended that a World-Wide Web cache server be used as a
go-between in the link checking process.  This can be enabled via
environmental variables, e.g.  in the style of csh and tcsh:

  setenv http_proxy "http://wwwcache.lut.ac.uk:3128/"
  setenv gopher_proxy "http://wwwcache.lut.ac.uk:3128/"
  setenv ftp_proxy "http://wwwcache.lut.ac.uk:3128/"
  setenv wais_proxy "http://wwwcache.lut.ac.uk:8001/"
  setenv no_proxy "lut.ac.uk"

Or in the sh/bash/ksh/zsh style:

  http_proxy="http://wwwcache.lut.ac.uk:3128/"
  gopher_proxy="http://wwwcache.lut.ac.uk:3128/"
  ftp_proxy="http://wwwcache.lut.ac.uk:3128/"
  wais_proxy="http://wwwcache.lut.ac.uk:8001/"
  no_proxy="lut.ac.uk"
  export http_proxy gopher_proxy ftp_proxy wais_proxy no_proxy

The B<-p> and B<-P> options may also be used to affect
proxying and hence caching behaviour.  Note that if you use
B<-p> to specify a single proxy server for all your requests,
this must be capable of handling any "wais:" URLs that may be 
passed to it.  You can run B<lc.pl> with the B<-l> option
to check for these in advance of doing the actual link check.

In addition to cache support via the proxy HTTP mechanism -
URLs which have already been visited during an link checking
session will not be requested again in the same session, and
the HTTP "HEAD" method is used whenever an "http" URL is
requested.  The time to sleep between requests is
configurable, defaulting to two seconds.

=head1 OPTIONS

=over 4

=item B<-a>

check all IAFA templates.  Uses ROADS default template
directory, or another directory specified with the B<-t>
option.  Implies B<-i>.

=item B<-b> I<baseurl>

specifies a base URL which will be used to make any relative
links absolute, e.g.

  -b http://www.roads.lut.ac.uk/

=item B<-c>

check HTTP URLs which appear to run a script, i.e. contain
the strings "/htbin/", "/cgi-bin/", or "?".  Normally these
will not be checked

=item B<-d>

generate debugging info

=item B<-g>

'guts' directory, used to hold DBM databases of Last-Modified times and
Content-Length information on a per URL basis.

=item B<-i>

specify source is IAFA templates, default is HTML

=item B<-l>

don't actually check, just dump out URLs.  This can be useful
in finding out which URLs are cited, which documents make the
citations, and so on

=item B<-p> I<proxyurl>

proxy all requests through the URL which follows, e.g.

  -p http://wwwcache.lut.ac.uk:3128/

=item B<-P>

don't import any proxy settings from the environment

=item B<-r> I<seconds>

rest time between URL lookups (default is 2 seconds).  This
feature is turned off is you enabled the B<-l> option, since
there is not going to be any networking going on

=item B<-s>

strict checking mode, default is not to follow links which look
as though they might be to large objects, e.g. MPEG movies.
Strict mode causes all links to be checked

=item B<-t> I<templatedir>

look in this directory for IAFA templates when B<-a> option is
enabled

=item B<-u>

list unchecked URLs to stderr, e.g.

  lc.pl -u *.html >successlog 2>failslog

=item B<-v>

list OK URLs as well as stale URLs

=item B<-w> I<when_changed>

list only URLs which have changed in the last N days

=item B<-x>

the input is a series of URLs, rather than IAFA or HTML files, e.g.

  lc.pl -x < my_list_of_urls

=back

=head1 OUTPUT FORMAT

The basic format for B<lc.pl> output is

  <HTTP response code> <name of file containing URL> <URL>

e.g.

  404 SOSIG347 http://www.iss.u-tokyo.ac.jp/center/SSJ.html

Libwww-perl automatically translates the result codes of requests
in protocols other than HTTP into their HTTP equivalents.  If you
use the B<-v> option to get the results of successful requests too,
the successful requests will be stamped with a B<200> repsonse code,
e.g.

  200 SOSIG345 http://www.ssd.gu.se/enghome.html

The output generated by the B<-u> and B<-l> options takes the form

  <name of file containing URL> <URL>

e.g.

  SOSIG345 http://www.ssd.gu.se/enghome.html

=head1 DEPENDENCIES

The libwww-perl package is used to parse HTML documents, and to
check the links themselves.  At the time of writing, libwww-perl
version 5 and Perl version 5.003 or above are recommended

=head1 TODO

Add support for other protocol schemes ? "finger:" should be easily
done via proxy HTTP, but the cache servers don't speak this protocol
scheme yet (and neither do many WWW authors?)  "mailto:" and "mailserver:"
could be done up to a point with code which checked for valid domain
names, MX records and so on.  An SMTP session to the remote server
would be do-able, but then we wouldn't be able to take advantage of
the current caching infrastructure...  "telnet:" is another case in
point.  We could check the machine had a working DNS entry, and
perhaps try to ping it, or even connect to the listed port.  How
far to take this is a matter for debate!

=head1 SEE ALSO

L<admin-cgi/lc.pl>, L<bin/report.pl>, L<admin-cgi/report.pl>

=head1 COPYRIGHT

Copyright (c) 1988, Martin Hamilton E<lt>martinh@gnu.orgE<gt> and Jon
Knight E<lt>jon@net.lut.ac.ukE<gt>.  All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

It was developed by the Department of Computer Studies at Loughborough
University of Technology, as part of the ROADS project.  ROADS is funded
under the UK Electronic Libraries Programme (eLib), the European
Commission Telematics for Research Programme, and the TERENA
development programme.

=head1 AUTHOR

Martin Hamilton E<lt>martinh@gnu.orgE<gt>

