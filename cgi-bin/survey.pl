#!/usr/bin/perl
use lib "/home/roads2/lib";

# survey.pl
#
# Author: Jon Knight <jon@net.lut.ac.uk>
# $Id: survey.pl,v 3.15 1998/09/05 14:00:43 martin Exp $

# Fix for stupid Netscape server bug/misfeature
close(STDERR) if $ENV{"SERVER_NAME"} =~ /netscape/i;

require ROADS;
use ROADS::CGIvars;
use ROADS::HTMLOut;
use ROADS::ErrorLogging;

use Getopt::Std;
getopts('L:C:f:u:r:');

#
# Main code
#

# File to append results to
$results_file = $opt_r || "$ROADS::Logs/survey-results";

# File to return to end user
$htmlform = $opt_f || "survey.html";

# The URL of this program
$myurl = $opt_u || "/$ROADS::WWWCgiBin/survey.pl";

# What language to return
$Language = $opt_L || "en-uk";

# What character set to use.
$CharSet = $opt_C || "ISO-8859-1";

&cleaveargs;

# Change the output language if specified in either the HTTP headers or the
# CGI variables passed from the browser.
if ($ENV{"HTTP_ACCEPT_LANGUAGE"} ne "") {
    $Language = $ENV{"HTTP_ACCEPT_LANGUAGE"};
}
if ($CGIvar{language} ne "") {
    $Language = $CGIvar{language};
}

# Change the character set if specified in either the HTTP headers of the
# CGI variables passed from the browser.
if ($ENV{"HTTP_ACCEPT_CHARSET"} ne "") {
    $CharSet = $ENV{"HTTP_ACCEPT_CHARSET"};
}
if ($CGIvar{charset} ne "") {
    $CharSet = $CGIvar{charset};
}

if ($CGIvar{form} ne "") {
    $htmlform = "$CGIvar{form}";
    $htmlform =~ tr/[A-Za-z0-9]//c;
    $htmlform .= ".html";
}

if ($CGIvar{resultsfile} ne "") {
    $results_file = "$CGIvar{resultsfile}";
    $results_file =~ tr/[A-Za-z0-9]//c;
    $results_file .= ".html";
}

print "Content-type: text/html\n\n";
if ($CGIvar{handle} eq "") {
   &OutputHTML("survey","$htmlform",$Language,$CharSet);
} else {
   &record_results;
   &OutputHTML("survey","done.html",$Language,$CharSet);
}
exit;

#
# Subroutine to record the useful attributes from the questionaire
#
sub record_results {
    # Open the survey results file and then wait until we can lock it.
    open(RESULTS,">>$results_file") || return;
    flock(RESULTS,2);

    # Output some potentially useful fields
    # These are:
    #   date/time, 
    #   http user agent, 
    #   IP address of user agent/cache,
    #   FQDN of user agent/cache,
    #   Remote username (if Ident is working)
    # 
    print RESULTS "\"".gmtime(time)."\",";
    print RESULTS "\"".$ENV{HTTP_USER_AGENT}."\",";
    print RESULTS "\"".$ENV{REMOTE_ADDR}."\",";
    print RESULTS "\"".$ENV{REMOTE_IDENT}."\",";
    print RESULTS "\"".$ENV{REMOTE_HOST}."\",";

    # Output all the numeric fields

    $comma="";
    foreach $var (split(",",$CGIvar{list})) {
        $_ = $CGIvar{$var};
        s/[\n\r]/ /g;
        s/"/'/g;
        s/,/;/g;
        print RESULTS "$comma\"$_\"";
        $comma=",";
    }
    print RESULTS "\n";
    flock(RESULTS,8);
    close RESULTS;
}

exit;
__END__


=head1 NAME

B<cgi-bin/survey.pl> - dump out a questionnaire and record the results

=head1 SYNOPSIS

  cgi-bin/survey.pl [-C charset] [-f form] [-L language]
    [-r resultsfile] [-u url]

=head1 DESCRIPTION

The B<survey.pl> program is a Common Gateway Interface (CGI) program
used to provide a survey form to end users of a ROADS based subject
service.  The survey form is an HTML file that is presented to the end
user by the program if it does not receive any CGI parameters.  This
form can include multiple choice questions, selections and questions
requiring free text answers.  When this form is submitted back to the
program, the values of the CGI variables are saved in comma separated
value format.  This result file can then be processed offline by other
programs to analyze the survey's returns.  The link to the B<survey.pl>
program can be made from any of the other HTML in the ROADS system,
such as that returned by the B<addsl.pl>, B<addwn.pl> B<search.pl>
programs.

=head1 ELEMENTS IN THE B<survey.pl> FORM

The B<survey.pl> program uses a HTML form normally called
F<survey.html> to read the HTML form for the survey in from.  This
file can contain any HTML.  However, within the B<FORM> there is an
extra "fake" HTML tag that is required.  This is the B<X-HANDLE> tag
which is replaced by an unique handle when the program returns the
form to the end user.  This fake tag B<MUST> be present in the form as
each IAFA-like template must have a unique handle.

It is also necessary to list all of the form fields which should be
stored in the survey results file - in the order which they should
appear in the file.  This list should be stored in the hidden form
field B<list>, using commas to separate the fields.

=head1 OPTIONS

These options are only practically useful for debugging.

=over 4

=item B<-C> I<charset>

Character set to use.

=item B<-f> I<form>

HTML form to return to end user.

=item B<-L> I<language>

Language to use.

=item B<-r>

File to save survey results to.

=item B<-u>

URL of the B<survey.pl> program.

=back

=head1 CGI VARIABLES

=over 4

=item B<charset>

Character set to use.

=item B<form>

HTML form to return to end user.  Note that only alphanumeric characters
will be used.

=item B<language>

Language to use.

=back

=head1 FILES

I<logs/survey-results> - the survey results themselves.

I<config/multilingual/*/survey/survey.html> - default HTML form
to return to end user.

I<config/multilingual/*/survey/done.html> - HTML message to
return to end user once the session is complete.

=head1 FILE FORMAT

In addition to the fields specified on the WWW form, the following
fields will also be saved for each entry in the survey log :-

  * The time in UTC (GMT)
  * The HTTP user agent if available
  * The client machine's IP address
  * The value returned by the IDENT/AUTH server on the remote
      machine if available
  * The domain name of the remote machine if available

Typically domain name and IDENT lookups have to be configured on the
WWW server which is running the B<survey.pl> program.  Note also that
some browsers will withhold HTTP user agent information.

=head1 SEE ALSO

L<bin/addsl.pl>, L<bin/addwn.pl>, L<cgi-bin/search.pl>

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

Jon Knight E<lt>jon@net.lut.ac.ukE<gt>

