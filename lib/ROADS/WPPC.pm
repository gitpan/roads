#
# ROADS::WPPC - WHOIS++ client code for ROADS search engine
#
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: WPPC.pm,v 3.14 1998/09/05 13:58:57 martin Exp $

package ROADS::WPPC;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(wppc %TEMPLATE $matches);

use Socket;

use ROADS::ErrorLogging;
use ROADS::HTMLOut;

sub wppc {
    my ($host, $port, $request) = @_;
    my ($socket, $buffer, $ttype, $serverhandle, $handle, $hostport);
    my (@results);

    $debug = $::debug || 0;

    print "[<EM>Contacting server $host, port $port\n" if $debug;
    print "sending request \"$request\"</EM>]\n" if $debug;
    
    ######## should fail gracefully in the event that it can't get
    ######## a socket, or connection to the server fails

    socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
    $sin = sockaddr_in($port,inet_aton("$host"));
    return("noconnect") unless connect(SOCK,$sin);
    $X = select(SOCK); $| = 1; select($X);
    print SOCK "$request\r\n";

    ######## should handle timeout gracefully
    while($buffer = <SOCK>) {
	$buffer =~ s/[\r\n]//g;
	next if $buffer =~ /^$/;
	
	#$buffer =~ s/^[\+\-]/ /;
	#print ">>> $buffer <<<\n" if $debug;
	
	$buffer =~ /^% 203/ && do { # the end!
	    close(SOCK);
	    last;
	};
	
	$buffer =~ /^% ([1245]..)/ && do { # keep record of sys msgs
	    push(@return_codes, $1);
	    next;
	};

	####### stash the response in the $TEMPLATE{} hash array

        $buffer =~ /^#\s+SUMMARY\s+([^\s]+)/i && do {
    	    while($buffer = <SOCK>) {
		$buffer =~ s/[\r\n]//g;
	        last if $buffer =~ /^# END/;
		next if $buffer =~ /^\s*$/;

		if ($buffer =~ /Matches:\s+(\d+)/) {
                    $matches = $1;
                    last;
		}
	    }
            &OutputHTML("lib", "toomanyhits.html");
            exit;
        };

        $buffer =~ /^#\s+FULL\s+COUNT\s+([^\s]+)/i && do {
            undef($serverhandle,$localcount,$referralcount);

            while($buffer = <SOCK>) {
               chomp($buffer);
#               print "... $buffer ...\n" if $debug;

               $buffer =~ /^ Local-Count:\s+(.*)/i && 
		   ($localcount = $1, next);
               $buffer =~ /^ Referral-Count:\s+([^\s]+)/i && 
		   ($referralcount = $1, next);

               last if $buffer =~ /^# END/;
           }
	   push(@results, "localcount:$localcount") if $localcount;
	   push(@results, "referralcount:$referralcount") if $referralcount;
           next;
	};

        $buffer =~ /^#\s+ABRIDGED\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)/i && do {
            $ttype=$1; $serverhandle=$2; $handle=3;

	    print "<HR>[Type <EM>$ttype</EM>, handle <EM>$handle</EM>]<P>\n" 
	        if $debug;
	
  	    $::TEMPLATE{"$serverhandle:$handle"} = "$buffer";

#	    print "its... >>$::TEMPLATE{\"$serverhandle:$handle\"}<<\n"
#		if $debug;

	    push (@results, "$serverhandle:$handle");
	    next;
        };

        $buffer =~ /^#\s+HANDLE\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)/i && do { 
            $ttype=$1; $serverhandle=$2; $handle=3;

	    print "<HR>[Type <EM>$ttype</EM>, handle <EM>$handle</EM>]<P>\n" 
	        if $debug;
	
  	    $::TEMPLATE{"$serverhandle:$handle"} = "$buffer";

#	    print "its... >>$::TEMPLATE{\"$serverhandle:$handle\"}<<\n"
#		if $debug;

	    push (@results, "$serverhandle:$handle");
	    next;
        };

	$buffer =~ /^#\s+FULL\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)/i && do {
	    $ttype=$1; $serverhandle=$2; $handle=$3;

	    print "<HR>[Type <EM>$ttype</EM>, handle <EM>$handle</EM>]<P>\n" 
	        if $debug;
	
  	    $::TEMPLATE{"$serverhandle:$handle"} = "$buffer";

    	    while($buffer = <SOCK>) {
		$buffer =~ s/[\r\n]//g;
	        last if $buffer =~ /^# END/;
		next if $buffer =~ /^\s*$/;

		if ($buffer =~ /^\+/) {
		    $buffer =~ s/^.//;
		    $::TEMPLATE{"$serverhandle:$handle"} .= "$buffer";
		} elsif ($buffer =~ /^\-/) {
		    $buffer =~ s/^.//;
		    $::TEMPLATE{"$serverhandle:$handle"} .= " $buffer";	
		} else {
		    $::TEMPLATE{"$serverhandle:$handle"} .= "\n$buffer";
		}
	    }
	
#	    print "its... >>$::TEMPLATE{\"$serverhandle:$handle\"}<<\n"
#		if $debug;

	    push (@results, "$serverhandle:$handle");
	    next;
        };

        $buffer =~ /^#\s+SERVER-TO-ASK\s+(.*)/i && do {
            $serverhandle = $1;

	    print "<HR>[<EM>Got referral</EM>]<P>\n" 
	        if $debug;
	
            $::TEMPLATE{"$serverhandle:referral"} = "$buffer";

            while($buffer = <SOCK>) {
		$buffer =~ s/[\r\n]//g;
	        last if $buffer =~ /^# END/;
		next if $buffer =~ /^\s*$/;

                print "... $buffer ...\n" if $debug;

		if ($buffer =~ /^\+/) {
		    $buffer =~ s/^.//;
		    $::TEMPLATE{"$serverhandle:referral"} .= "$buffer";
		} elsif ($buffer =~ /^\-/) {
		    $buffer =~ s/^.//;
		    $::TEMPLATE{"$serverhandle:referral"} .= " $buffer";	
		} else {
		    $::TEMPLATE{"$serverhandle:referral"} .= "\n$buffer";
		}
            }
#            print "its... >>$::TEMPLATE{\"$serverhandle:referral\"}<<\n"
#		if $debug;

	    push (@results, "$serverhandle:referral");
            next;
        };
    }
    close(SOCK);

    return (@results);
}

1;
__END__


=head1 NAME

ROADS::WPPC - A class to talk to WHOIS++ servers

=head1 SYNOPSIS

  use ROADS::WPPC;
  @results = wppc($host, $port, $request);
  foreach $I (@results) { print $I, ": ", $TEMPLATE{$I}, "\n"; }

=head1 DESCRIPTION

This class implements a simple WHOIS++ client which returns raw
WHOIS++ responses in a hash array with global scope, together with an
index of matching templates and server handles.

=head1 METHODS

=head2 wppc( host, port, request );

Invoking this method causes the following to happen :-

=over 4

=item A TCP connection is made to port I<port> on the machine whose
Internet address or domain name is I<host>.

=item The request I<request> is sent.

=item We sit and wait for responses to come back.

=item For each template which comes back from the remote server, we
record its details (server handle and local handle) as an entry in a
scalar array which is returned when we reach the end of the responses
and drop out of I<wppc>.

=back

=head1 DATA FORMATS

The format of the per-template information returned by I<wppc> will be
one of the following :-

I<serverhandle>:I<handle> - if the response is a simple template.
I<serverhandle>:I<referral> - if the response is a referral.
localcount:I<NN> - if the response is a COUNT template containing
hit count information.
referralcount:I<NN> - if the reponse is a COUNT template containing
hit count information.
noconnect - if the server couldn't be contacted.

The format of the individual templates, as indexed by the
I<serverhandle:handle> notation, is as they appear on the wire when
send from the WHOIS++ server back to the client.  This means that any
code which processes them will need to do some extra work to get at
individual fields in the templates.  This will change in a future
version of the ROADS software.

Here's a sample on-the-wire WHOIS++ record :-

  # FULL DOCUMENT MULTICS xdom01
   Title: cross domain search test
   Description: this is really just a test
   URI: http://www.roads.lut.ac.uk/
  # END

Note that it will not include the variant suffixes, since these
are generally not used in WHOIS++ implementations.  Note also that the
four fields on the first line of the record correspond to :-

=over 4

=item I<format>

=item I<template type>

=item I<serverhandle>

=item I<handle>

=back

=head1 FILES

I<config/multilingual/*/lib/toomanyhits.html> - if the number of hits
was so great that it exceeded a pre-defined administrative upper
limit.

=head1 BUGS

We shouldn't be trying to do HTML rendering in this code.  We also
shouldn't be trying to return a list of templates (and other things -
all mushed up together!) and also poking around in the shared global
namespace at the same time.  Searches and search results probably
ought to be objects in their own right, with search results being
comprized of metadata objects.

It would be neat if we could open connections to multiple servers and
use select()/poll() to divide our time between them.  Currently we're
limited to contacting servers strictly in series :-(

=head1 SEE ALSO

L<admin-cgi/admin.pl>, L<admin-cgi/lookupcluster.pl>, L<cgi-bin/search.pl>

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

