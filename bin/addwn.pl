#!/usr/bin/perl
use lib "/home/roads2/lib";

# addwn.pl
#
# Author: Jon Knight <jon@net.lut.ac.uk>
# $Id: addwn.pl,v 3.17 1998/11/05 19:36:35 jon Exp $

use Getopt::Std;
use POSIX;

require ROADS;
use ROADS::ErrorLogging;
use ROADS::PreferredURL;
use ROADS::ReadTemplate;
use ROADS::Render;

# Process command line arguments
getopts('acdf:hl:n:p:rs:w:z:');

if ($opt_h) {
    print STDERR "Usage $0: [options] [handle [handle...]]\n";
    print STDERR "\t[-a]\t: Process all templates in source directory\n";
    print STDERR "\t[-c]\t: Caseful alphabetising\n";
    print STDERR "\t[-d]\t: Enter debug mode\n";
    print STDERR "\t[-f <directory>]\t: Directory for config files (default: $ROADS::Config/whats-new/views\n";
    print STDERR "\t[-h]\t: This help\n";
    print STDERR "\t[-l N]\t: Last N resources to be added\n";
    print STDERR "\t[-n <name>]\t: Set database name (default: $ROADS::ServiceName)\n";
    print STDERR "\t[-p <pattern>]\t: match <pattern> in URI field\n";
    print STDERR "\t[-r]\t: remove duplicates\n";
    print STDERR "\t[-s <directory>]\t: Set IAFA template source directory (default: $ROADS::IafaSource)\n";
    print STDERR "\t[-w <name>]\t: Set Whats New view (default: Default)\n";
    print STDERR "\t[-z <date>]\t: Resources added since date - hhmmssddmmyyyy\n";
    exit;
}

$debug = $opt_d || 0;

# Get the name that this script was called under.
$scriptname = "whats-new";

# Default location of the the IAFA template directory.
$iafa_source = $opt_s || "$ROADS::IafaSource";
$iafa_source =~ s/\/$//;

# URL for the tempbyhand.pl script for hyperlinking direct to entries
$TempByHandURL = "/$ROADS::WWWCgiBin/tempbyhand.pl";

# Default Database name
$DatabaseName = $opt_n || "$ROADS::ServiceName";

# Location of What's New views
$WhatsNewViews = $opt_f || "$ROADS::Config/whats-new";

# Default name of the What's New view
$WhatsNew = $opt_w || "Default";

# URL for the bullet image
$bulletref = "$ROADS::Bullet";

# Default of caseless alphabetising
$opt_c = 0 unless $opt_c;

# Default URI matching pattern matches everything
$pattern = $opt_p || "(.*)";

# Reference date - include entries 'zince' this :-)
if ($opt_z =~ /^(..)(..)(..)(..)(..)(....)/) {
  $ref_hour = $1;
  $ref_min = $2;
  $ref_sec = $3;
  $ref_mday = $4;
  $ref_mon = $5;
  $ref_year = $6;
}

#
# Main code
#

# Read in the handle to filename mappings from the alltemps file in the
# guts directory.
chdir $iafa_source
  || &WriteToErrorLogAndDie("addwn", "Can't chdir($iafa_source): $!");
%MAPPING = &readalltemps;
push(@ARGV, keys %MAPPING) if $opt_a;

# Open the selected What's New view.
open(VIEW,"$WhatsNewViews/$WhatsNew")
  || &WriteToErrorLogAndDie("addwn", 
       "Can't open [whats new views] view file $WhatsNewViews/$WhatsNew: $!");
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

print <<EOF
HTMLFile = $HTMLFile
ListingFile = $ListingFile
EOF
if $debug;

# Open the new index file.
open(NEWINDEX,">$ListingFile.new")
  || &WriteToErrorLogAndDie("addwn",
			    "Can't open [listing new] $ListingFile.new: $!");

# Get the time now (this is used as the Whats New time stamp for all templates
# added during this run of the script)
$now = time;

# Actually process the template(s) to generate the list files
foreach $handle (@ARGV) {
    warn "Doing template \"$handle\"\n" if $debug;
    undef %TEMPLATE;
    %TEMPLATE = &readtemplate("$handle");

    $destlist = $TEMPLATE{destination};

    if (($TEMPLATE{handle} eq $handle) &&
	(grep(/^$DatabaseName$/i, (split(/[\s,]+/,$destlist)))         
	 || (($DatabaseName eq $ROADS::ServiceName) &&
	     ($destlist eq "")))) {
	&inserttemplate($handle);
    }
}

# Add the existing listing file to the entries just added.
if (open(OLDINDEX,"$ListingFile")) {
    if (!$opt_r) {
        while(<OLDINDEX>) {
            print NEWINDEX $_;
        }
    } else {
        while(<OLDINDEX>) {
            ($addedtime,$title,$handle,$mtime,$url) = split(":",$_,5);
            warn "ADDED{$handle} = $ADDED{$handle}\n" if ($debug);
            if($ADDED{"$handle"}!=1){
                print NEWINDEX $_;
            }
        }
    }
    close(OLDINDEX);
}
close(NEWINDEX);

rename("$ListingFile.new","$ListingFile");
if (defined($opt_l) || defined($opt_z)) {
    system("$ROADS::SortPath -b -t: +3 -4rn $ListingFile >$ListingFile.$$");
} elsif(!$opt_c) {
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
    open(STDOUT, ">$HTMLFile")
      || &WriteToErrorLogAndDie("addwn",
			"Can't open html file $HTMLFile: $!");
    open(LSTFILE,"$ListingFile") 
	|| &WriteToErrorLogAndDie("addwn",
			"Can't reopen listing file $ListingFile: $!");

    @handles = ();
    $oldaddedtime = 0;
    while(<LSTFILE>) {
	chomp;
	($addedtime,$title,$handle,$mtime,$url) = split(":",$_,5);
	
	# tart up the added time info so it's useful
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    gmtime($addedtime);
	$year += 1900;
	$month=(Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mon];
	$day=(Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];
	
	# tart up the last modified time so its useful
	($mod_sec,$mod_min,$mod_hour,$mod_mday,$mod_mon,$mod_year,
	 $mod_wday,$mod_yday,$mod_isdst) = gmtime($mtime);
	$mod_year += 1900;
	$mod_month=
	    (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mod_mon];
	$mod_day=(Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];

	$ADDED_TIME{"$handle"} =
	    sprintf("%s %2.2d %s %2.2d:%2.2d:%2.2d UTC",
		    $day,$mday,$month,$hour,$min,$sec);
	$MODIFIED_TIME{"$handle"} =
	    sprintf("%s %2.2d %s %2.2d:%2.2d:%2.2d UTC",
		    $mod_day,$mod_mday,$mod_month,$mod_hour,$mod_min,$mod_sec);
	
	# If we were doing the last N items added...
	if (defined($opt_l)) {
	    last if $opt_l == 0;
	    $opt_l--;
	}
	
	if (defined($opt_z)) {
	    warn <<EOF
		
Checking $mod_year against $ref_year
         $mod_mon (+1) against $ref_mon
         $mod_mday against $ref_mday
         $mod_hour against $ref_hour
         $mod_min against $ref_min
         $mod_sec against $ref_sec
EOF
    if $debug;

	    # If we were doing items added since...
	    next if $mod_year < $ref_year;
	    
	    next if ($mod_year == $ref_year
		     && ($mod_mon + 1) < $ref_mon);
	    
	    next if ($mod_year == $ref_year
		     && ($mod_mon + 1) == $ref_mon
		     && $mod_mday < $ref_mday);
	    
	    next if ($year == $ref_year
		     && ($mod_mon + 1) == $ref_mon
		     && $mod_mday == $ref_mday
		     && $mod_hour < $ref_hour);
	    
	    next if ($mod_year == $ref_year
		     && ($mod_mon + 1) == $ref_mon
		     && $mod_mday == $ref_mday
		     && $mod_hour == $ref_hour
		     && $mod_min < $ref_min);
	    
	    next if ($mod_year == $ref_year
		     && ($mod_mon + 1) == $ref_mon
		     && $mod_mday == $ref_mday
		     && $mod_hour == $ref_hour
		     && $mod_min == $ref_min
		     && $mod_sec < $ref_sec);
	    
	    print "Template $handle passed checks!\n" if $debug;
	}
	push(@handles, $handle);
    }
    close(LSTFILE);

    &render("", "$WhatsNew", @handles);
    close(HTMLFILE);
}

#
# Subroutine to insert a template's details in the what's new listing
#
sub inserttemplate {
    local($handle) = @_;

    local($attr,$do,$url) = 0;
    local(@keylist,@stat);
    local($mtime) = 0;

    warn "Inserting template with handle $handle\n" if $debug;

    # Check if the template contains a URI attribute that matches the user
    # specified pattern.  Only proceed if it does.
    $do = 0;
    foreach $attr (keys %TEMPLATE) {
        $_ = $attr;
        if(/^UR[IL]/i) {
            $url = $TEMPLATE{"$attr"};
	    $_ = $url;
            $do = 1 if /$pattern/;
            warn "Do = $do,\tURL = $url,\tPattern = $pattern\n" if $debug;
        }
    }
    return if ($do == 0);
    warn "Can do $TEMPLATE{handle}\n" if $debug;

    # Get the preferred URL of the resource.
    $url = &preferredURL(%TEMPLATE);
    warn "Preferred URL = $url\n" if $debug;
    @keylist = keys %TEMPLATE;
    ($title) = grep(/^title/i,@keylist);

    # Get the last modification time of the template file.  Note that in the
    # cases where there exists more than one template in a file, this will
    # show that all templates have been modified at the same time.  Which is
    # a bit of a bummer, but then none of the ROADS software _generates_ 
    # multiple templates in a single file.
    (@stat) = stat($MAPPING{"$handle"});
    $mtime = $stat[9];

    # Generate a carriage return and linefeed-less version of the title, but
    # maintain its given case for use in outputing to the listing files.
    $outtitle = $TEMPLATE{"$title"};
    $outtitle =~ s/\x0A//g;
    $outtitle =~ s/\x0D//g;
    $outtitle =~ s/^\s+//;
    $outtitle =~ s/:/;/g;
    $outtitle = "No title" if ($outtitle eq "");

    print NEWINDEX "$now:$outtitle:$handle:$mtime:$url\n";
    $ADDED{"$handle"}=1;
}

exit;
__END__


=head1 NAME

B<bin/addwn.pl> - add what's new entries for specified templates

=head1 SYNOPSIS

  bin/addwn.pl [-acdh] [-f directory] [-l number]
    [-n name] [-p pattern] [-r] [-s directory]
    [-w name] [-z date] [handle1 handle2 ... handleN]

=head1 DESCRIPTION

The B<addwn.pl> program adds templates with the specified handles to a
B<What's New> listing file.  This listing file is then converted into
a static HTML document which can be placed on the WWW.  The B<Whats New>
file is intended to show end users what resources have just been
catalogued by a subject service and/or when some aspect of a
catalogued resource's template has changed.

=head1 USAGE

The ROADS software can generate lists of resource descriptions which
have been entered recently or changed recently.  The configuration of
this is very similar to that of the resource listings.  Essentially,
each B<What's New> view is specified by an HTML outline file, a
file to add the new resource information to, and an internal file.
The default B<What's New> view can be found in the file
I<config/multilingual/*/whats-new-views/Default> under the top level
ROADS installation directory.

The default B<What's New> view installed by the ROADS
software will be configured to create a listing file called
I<whats-new.html> in the ROADS directory on your WWW server, and
use sub-directories of the ROADS installation for its outline and
internal files, e.g.

  Outline-File:   whats-new/outlines/Default
  HTML-File:      whats-new.html
  Listing-File:   whats-new/Default.lst

If you create your resource description templates using the WWW based
template editor, you will be given the option of entering them into a
B<What's New> list - I<addwn.pl> will be called to do
this.  Alternatively, if you wish to generate these listings manually,
you can run I<addwn.pl> yourself.  Use the B<-a> option to add all your
templates, e.g.

  % addwn.pl -a

If you only want to include a subset of the resource description
templates in your database, I<addwn.pl> takes a similar set of
options to I<addsl.pl> - e.g. the B<-p> option can
be used to restrict the templates which are included based on the
contents of their URIs, and individual templates to include can be
specified on the command line.

Note that your templates must include at least one
B<URI> attribute.
 
=head1 OPTIONS

A number of options are available for the B<addwn.pl> program to
control which files are used for generating the subject listings and
where configuration options are located:

=over 4

=item B<-a>

Process all templates in source directory.

=item B<-c>

Specify that the alphabetical listing should take acount of the case
of the characters.  Without this option, I<acorn> , I<Apple> and
I<Zebra> are sorted in that order.  With this flag set, they would be
sorted as I<Apple> , I<Zebra> and I<acorn>.

=item B<-d>

specify that some (fairly copious) debugging information should be
generated during the generation of the hypertext tree.  This option is
probably not of interest to anyone bar the developers.

=item B<-f> I<directory>

Specify the directory for views configuration files.

=item B<-h>

Provide some online help outlining the options available and exit.

=item B<-l> I<N>

Specifies that only the last I<N> resources added to the ROADS server
should be used in the "What's New" listing.

=item B<-n> I<name>

Specifies the name of the database to use - defaulting to the service
name which was entered when the ROADS server was created.

=item B<-p> I<pattern>

Only enter entries in the subject listings for templates that have URI
fields that match the supplied pattern.  The pattern can be a full Perl
regular expression and allows one to, for example, restrict entries in
the subject listings to only include UK academic sites.  By default the
pattern matches all URLs and so all templates are included in the
hypertext lists. 

=item B<-r>

Specifies that any duplicates should be removed (pared down to a single
entry).

=item B<-s> I<directory>

Set the I<absolute> pathname of the directory containing the IAFA templates.

=item B<-w> I<name>

Sets the name of B<What's New> view to use in configuring the
B<addwn.pl> script.

=item B<-z> I<hhmmssddmmyyyy>

Specifies that only resources added since this date should be included
in the "What's New" listing, where the date fields are:

  hh - hours
  mm - minutes
  ss - seconds
  dd - day
  mm - month
  yyyy - year

=back

These options are then followed by zero or more templates handles
(note - B<not> filenames).  If the B<-a> option is given, no handles
need be given on the command line; all templates in the database will
be added to the subject listings.

=head1 FILES

I<config/whats-new/*> - "What's New" view specifications

I<config/multilingual/*/whats-new-views/*> - rendering rules
for the various "What's New" views

I<htdocs/whats-new.html> - default location of listing.

=head1 FILE FORMAT

The B<addwn.pl> can generate a number of different subject listings.
This allows, for example, a subject listing of UK based resources in
addition to a subject listing of all resources.  The views also allow
easy selection of which subject listing a template should be added to
in the B<mktemp.pl> editor.

The view is specified by a view file.  A sample file is:

  HTML-File:      /WWW/htdocs/ROADS/whats-new.html
  Listing-File:   /usr/local/ROADS/guts/whats-new/Default.lst

The various attributes currently defined in the view file are:

=over 4

=item HTML-File:

The path to the file in which the subject listing HTML document should be
generated.  This file should be accessible to the HTTP daemon that serves
the ROADS documents if the HTML document is to be accessible via the
World Wide Web.  If the path is a relative one, it is assumed to be
relative to the ROADS I<htdocs> directory - i.e. the directory in which
ROADS related WWW pages are rooted.

=item Listing-File:

The path to the file in which the B<What's New> listing file should be
located.  This is typically located in the F<guts> directory of the ROADS
installation, which is where files needed for the internal operation of
the ROADS software are kept.  If the path is a relative one, it is assumed
to be relative to the ROADS F<guts> directory.

=back

=head1 SEE ALSO

L<bin/addwn.pl>, L<bin/cullsl.pl>, L<bin/mkinv.pl>

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


