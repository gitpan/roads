#!/usr/bin/perl
use lib "/home/roads2/lib";

# cullwn.pl
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#         Martin Hamilton <martinh@gnu.org>
# $Id: cullwn.pl,v 3.14 1999/01/19 19:54:04 jon Exp $

use Getopt::Std;
use POSIX;
use Time::Local;

require ROADS;
use ROADS::ErrorLogging;
use ROADS::Render;

#
# Main code
#

# Process command line arguments
getopts('cdf:hn:w:');

if ($opt_h) {
    print STDERR "Usage $0: [options] time\n";
    print STDERR "\t[-d]\t: Enter debug mode\n";
    print STDERR "\t[-f <directory>]\t: Directory for config files (default: $ROADS::Config/whats-new/views\n";
    print STDERR "\t[-h]\t: This help\n";
    print STDERR "\t[-n <name>]\t: Set database name (default: $ROADS::ServiceName)\n";
    print STDERR "\t[-w <name>]\t: Set Whats New view name (default $ROADS::Config/whats-new/views)\n";
    print STDERR "The time format is a 14 character string: hhmmssddmmyyyy\n";
    exit;
}

$debug = $opt_d || 0;

# Get the name that this script was called under.
$scriptname = "whats-new";

# URL for the tempbyhand.pl script for hyperlinking direct to entries
$TempByHandURL = "http://$ROADS::MyHostname:$ROADS::MyPortNumber/"
    . "$ROADS::WWWCgiBin/tempbyhand.pl";

# Default Database name
$DatabaseName = $opt_n || "$ROADS::ServiceName";

# Location of What's New views
$WhatsNewViews = $opt_f || "$ROADS::Config/whats-new";

# Default basename of the What's New file
$WhatsNew = $opt_w || "Default";

# URL for the bullet image
$bulletref = "http://$ROADS::MyHostname:$ROADS::MyPortNumber/$ROADS::Bullet";

# Default of caseless alphabetising
$opt_c = 0 unless $opt_c;

# Open the selected What's New view.
open(VIEW,"$WhatsNewViews/$WhatsNew")
  || &WriteToErrorLogAndDie("cullwn",
       "Can't open view file $WhatsNewViews/$WhatsNew: $!");
while(<VIEW>) {
    chomp;
    if (/^HTML-File:\s+(.*)/i) {
        $HTMLFile = $1;
        $HTMLFile = "$ROADS::HtDocs/$HTMLFile"
          unless $HTMLFile =~ /^\//;
    } elsif (/^Listing-File:\s+(.*)/i) {
        $ListingFile = $1;
        $ListingFile = "$ROADS::Guts/$ListingFile"
          unless $ListingFile =~ /^\//;
    }
}

# Open the new index file.
open(NEWINDEX,">$ListingFile.new")
  || &WriteToErrorLogAndDie("cullwn", "Can't open $ListingFile.new: $!");

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
$time = shift;
$timesize = length($time);
# Be nice and let people put in 2 digit dates if they want, even though
# this won't work after the year 2000.
&WriteToErrorLogAndDie("cullwn", "Unrecognised time") 
  if(($timesize != 12) && ($timesize != 14));
$hour = substr($time,0,2);
$min = substr($time,2,2);
$sec = substr($time,4,2);
$mday = substr($time,6,2);
$mon = substr($time,8,2);
$mon -= 1;
$year = substr($time,10,4);
$year -= 1900 unless ($year < 100);

$culltime = timegm($sec,$min,$hour,$mday,$mon,$year);

# Add the existing listing file to the entries just added.
if(open(OLDINDEX,"$ListingFile")) {
    while(<OLDINDEX>) {
        ($addedtime,$title,$handle,$mtime,$url) = split(":",$_,5);
        print NEWINDEX $_ if($addedtime > $culltime);
    }
    close(OLDINDEX);
}
close(NEWINDEX);
rename("$ListingFile.new","$ListingFile");
if (!$opt_c) {
    system("$ROADS::SortPath -bf -t: +0 -1rn +1 -2bf $ListingFile >$ListingFile.$$");
} else {
    system("$ROADS::SortPath -b -t: +0 -1rn +1 -2b $ListingFile >$ListingFile.$$");
}
rename("$ListingFile.$$","$ListingFile");

# Convert the listing file to HTML.
&GenHTML;

exit;

#
# Generate an HTML file from a listing file
#
sub GenHTML {
    close(STDOUT);
    open(STDOUT,">$HTMLFile")
      || &WriteToErrorLogAndDie("cullwn",
           "Can't open html file $HTMLFile: $!");

    open(LSTFILE,"$ListingFile")
	|| &WriteToErrorLogAndDie("cullwn",
			"Can't reopen listing file $ListingFile: $!");
    $oldaddedtime = 0;
    while(<LSTFILE>) {
	chomp;
	($addedtime,$title,$handle,$mtime,$url) = split(":",$_,5);

	next if $addedtime == $oldaddedtime;
	$oldaddedtime = $addedtime;

	# tart up the added time info so it's useful
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    gmtime($addedtime);
	$year += 1900 if ($year < 100);
	$month=(Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mon];
	$day=(Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];
	
	# tart up the last modified time so its useful
	($mod_sec,$mod_min,$mod_hour,$mod_mday,$mod_mon,$mod_year,
	 $mod_wday,$mod_yday,$mod_isdst) = gmtime($mtime);
	$mod_year += 1900 if ($mod_year < 100);
	$mod_month=
	    (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mod_mon];
	$mod_day=(Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];

	$ADDED_TIME{"$handle"} =
	    sprintf("%s %2.2d %s %2.2d:%2.2d:%2.2d UTC",
		    $day,$mday,$month,$hour,$min,$sec);
	$MODIFIED_TIME{"$handle"} =
	    sprintf("%s %2.2d %s %2.2d:%2.2d:%2.2d UTC",
		    $mod_day,$mod_mday,$mod_month,$mod_hour,$mod_min,$mod_sec);

	push(@handles, $handle);
    }
    close(LSTFILE);

    &render("", "$WhatsNew", @handles);
    close(HTMLFILE);
}

exit;
__END__


=head1 NAME

B<bin/cullwn.pl> - cull stale entries from what's new listings

=head1 SYNOPSIS

  bin/cullwn.pl [-cdh] [-f directory] [-n name]
    [-w name] hhmmssDDMMYYYY

=head1 DESCRIPTION

The B<cullwn.pl> program removes entries from a I<What's New> listing
file that were added before a certain date.  The new listing file is
then converted into a static HTML document which can be placed on the
WWW.  The I<What's New> file is intended to show end users what
resources have just been catalogued by the ROADS service and/or when
some aspect of a catalogued resource's template has changed.

=head1 USAGE

It is anticipated that you will want to remove B<What's New> listing
entries which are past their use-by date, and the ROADS software provides
a tool to help you do this.  I<cullwn.pl> will remove any B<What's New>
entries which are older than a given date - or the current date if no date
is specified.  At the moment you have to run this from the command line,
but in a future version of the software we will be providing a
World-Wide Web front end.

The I<cullwn.pl> tool uses the same view configuration
information as the I<addwn.pl> tool - see the section on this
for more information.  It can be run either with or without a date
from which to begin culling, e.g.

(start culling from now...)

  % cullwn.pl

(start culling from the 15th of January 1997...)

  % cullwn.pl 00000015011997

=head1 OPTIONS

A number of options are available for the B<cullwn.pl> program to
control which files are used for generating the subject listings and
where configuration options are located:

=over 4

=item B<-c>

Specify that the alphabetical listing should take acount of the case
of the characters.  Without this option, I<acorn> , I<Apple> and
I<Zebra> are sorted in that order.  With this flag set, they would be
sorted as I<Apple> , I<Zebra> and I<acorn>.

=item B<-d>

Specify that some (fairly copious) debugging information should be
generated during the generation of the hypertext tree.  This option is
probably not of interest to anyone bar the developers.

=item B<-f> I<directory>

Specify the directory for views configuration files.

=item B<-h>

Provide some online help outlining the options available and exit.

=item B<-n> I<name>

Specifies the name of the database to use - defaulting to the service
name which was entered when the ROADS server was created.

=item B<-w> I<name>

Sets the name of I<What's New> view to use in configuring the
B<cullwn.pl> script.

=back

These options are then followed by a 14 character time and date string
in the following format:

  hhmmssDDMMYYYY

where (in order):

=over 4

=item *

B<hh> is the hours,

=item *

B<mm> is the minutes,

=item *

B<ss> is the seconds,

=item *

B<DD> is the day of the month,

=item *

B<MM> is the month (1-12),

=item *

B<YYYY> is the year.

=back

This time and date string specifies the culling time; all entries in
the what's new list generated before that date are removed.  Thus the
string B<10452312031995> tells B<cullwn.pl> to remove any entries
added the I<What's New> list before 10:45:23am on 12th March 1995.

=head1 FILES

I<config/whats-new/*> - "What's New" view specifications

I<config/multilingual/*/whats-new-views/*> - rendering rules
for the various "What's New" views

I<htdocs/whats-new.html> - default location of listing.

=head1 FILE FORMAT

The B<cullwn.pl> program can generate a number of different subject
listings.  This allows, for example, a subject listing of UK based
resources in addition to a subject listing of all resources.  The
views also allow easy selection of which subject listing a template
should be added to in the B<mktemp.pl> editor.

The view is specified by a view file.  An example file is:

  HTML-File:      /WWW/htdocs/ROADS/whats-new.html
  Listing-File:   /usr/local/ROADS/guts/whats-new/Default.lst

The various attributes currently defined in the view file are:

=over 4

=item HTML-File:

The path to the file in which the subject listing HTML document should
be generated.  This file should be accessible to the HTTP daemon that
serves the ROADS documents if the HTML document is to be accessible
via the World Wide Web.  If the path is a relative one, it is assumed
to be relative to the ROADS F<htdocs> directory, i.e. the directory
where ROADS related HTML documents are rooted.

=item Listing-File:

The path to the file in which the I<What's Newm> listing file should
be located.  This is typically located in the F<guts> directory of the
ROADS installation, which is where the internal files needed by the
ROADS software are found.  If the path is a relative one, it is
assumed to be relative to the ROADS F<guts> directory.

=back

=head1 SEE ALSO

L<bin/addsl.pl>, L<bin/addwn.pl>, L<bin/cullsl.pl>, L<bin/mkinv.pl>

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

Jon Knight E<lt>jon@net.lut.ac.ukE<gt>,
Martin Hamilton E<lt>martinh@gnu.orgE<gt>
