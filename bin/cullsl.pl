#!/usr/bin/perl
use lib "/home/roads2/lib";

# cullsl.pl
#
# Author: Jon Knight <jon@net.lut.ac.uk>
# $Id: cullsl.pl,v 3.17 1998/09/05 14:07:11 martin Exp $

use Getopt::Std;

require ROADS;
use ROADS::ErrorLogging;
use ROADS::PreferredURL;
use ROADS::ReadTemplate;
use ROADS::Render;

# Process command line arguments
getopts('ANacdf:hl:m:n:p:s:t:u:');

if ($opt_h) {
    print STDERR "Usage $0: [options] [handle [handle...]]\n";
    print STDERR "\t[-A]\t: Don't generate alphabetical subject index\n";
    print STDERR "\t[-N]\t: Don't generate numeric subject index\n";
    print STDERR "\t[-a]\t: Process all templates in source directory\n";
    print STDERR "\t[-c]\t: Caseful alphabetising\n";
    print STDERR "\t[-d]\t: Enter debug mode\n";
    print STDERR "\t[-f <file>]\t: Subject listing view directory (default: $ROADS::Config/subject-listing)\n";
    print STDERR "\t[-h]\t: This help\n";
    print STDERR "\t[-l <file>]\t: Set view (default: Default)\n";
    print STDERR "\t[-m <file>]\t: Set classification mapping file (default: $ROADS::Config/class-map)\n";
    print STDERR "\t[-n <name>]\t: Set database name (default: $ROADS::ServiceName)\n";
    print STDERR "\t[-p <pattern>]\t: match <pattern> in URI field\n";
    print STDERR "\t[-s <directory>]\t: Set IAFA template source directory (default: $ROADS::IafaSource)\n";
    print STDERR "\t[-t <directory>]\t: Set subject listing mapping file target directory (default: $ROADS::Guts/subject-listing/Default/)\n";
    print STDERR "\t[-u <scheme>]\t: Set scheme (default: UDC)\n";
    exit;
}

$debug = $opt_d || 0;

# Get the name that this script was called under.
$scriptname = "subject-listing";

# Default location of the the IAFA template directory.
$iafa_source = $opt_s || "$ROADS::IafaSource";
$iafa_source =~ s/\/$//;

# Default location of subject listing views
$SubjectListingViews = $opt_f || "$ROADS::Config/subject-listing";
$SubjectListingViews =~ s/\/$//;

# Default name of subject listing view
$SubjectListing  = $opt_l || "Default";

# Default location of the UDC tree structure
$ListingDirectory = $opt_t || "$ROADS::Guts/subject-listing/Default/";
$ListingDirectory =~ s/\/$//;

# Default name of the alphabetical subject category breakdown
$AlphaListFile = "alphalist.html";

# Default name of the alphabetical subject category breakdown
$NumListFile || "numlist.html";

# Default name of the subject list docs directory as exported to the WWW
$WWWDirectory || "$ROADS::WWWHtDocs";

# Default location of UDC/section name mapping file
$MappingFile = $opt_m || "$ROADS::Config/class-map";

# URL for the tempbyhand.pl script for hyperlinking direct to entries
$TempByHandURL = "/$ROADS::WWWCgiBin/tempbyhand.pl";

# Default Database name
$DatabaseName = $opt_n || "$ROADS::ServiceName";

# Default Subject-Discriptor-Scheme to match
$scheme_name = $opt_u || "UDC";

# Default of caseless alphabetising
$opt_c = 0 unless $opt_c;

# Default URI matching pattern matches everything
$pattern = $opt_p || "(.*)";

# Open the selected Subject Listing view.
open(VIEW,"$SubjectListingViews/$SubjectListing")
  || &WriteToErrorLogAndDie("cullsl",
       "Can't open view file $SubjectListingViews/$SubjectListing: $!");
while(<VIEW>) {
    chomp;
    if (/^HTML-Directory:\s+(.*)/i) {
        $HTMLDirectory = $1;
        $HTMLDirectory = "$ROADS::HtDocs/$HTMLDirectory"
          unless $HTMLDirectory =~ /^\//;
    } elsif (/^WWW-Directory:\s+(.*)/i) {
        $WWWDirectory = $1;
	$WWWDirectory =~ s!^/!!;
	$WWWDirectory =~ s!/$!!;
    } elsif (/^Listing-Directory:\s+(.*)/i) {
        $ListingDirectory = $1;
        $ListingDirectory = "$ROADS::Guts/$ListingDirectory"
          unless $ListingDirectory =~ /^\//;
    } elsif (/^Mapping-File:\s+(.*)/i) {
        $MappingFile = $1;
        $MappingFile = "$ROADS::Config/$MappingFile"
          unless $MappingFile =~ /^\//;
    } elsif (/^NumList-File:\s+(.*)/i) {
        $NumListFile = $1;
        $NumListFile = "$ROADS::HtDocs/$NumListFile"
          unless $NumListFile =~ /^\//;
    } elsif (/^AlphaList-File:\s+(.*)/i) {
        $AlphaListFile = $1;
        $AlphaListFile = "$ROADS::HtDocs/$AlphaListFile"
          unless $AlphaListFile =~ /^\//;
    } elsif (/^Subject-Scheme:\s+(.*)/i) {
        $scheme_name = $1;
    }
}
close(VIEW);

# Dump out the contents of the config file if we're in debug mode
warn <<EOF if $debug; 
HTMLDirectory: $HTMLDirectory
WWWDirectory: $WWWDirectory
ListingDirectory: $ListingDirectory
MappingFile: $MappingFile
SubjectScheme: $scheme_name
AlphaListFile: $AlphaListFile
NumListFile: $NumListFile
EOF

# if the target listing directory doesn't exist, create it.
unless (-d "$ListingDirectory") {
    mkdir($ListingDirectory,0755)
      || &WriteToErrorLogAndDie("cullsl", "Can't create $ListingDirectory: $!");
}

# Slurp in the subject descriptor scheme name mapping file.
open(SCHEMEMAP,$MappingFile) || &WriteToErrorLogAndDie("cullsl",
                                  "Can't open scheme map $listing_map: $!");
while(<SCHEMEMAP>) {
    chomp;
    ($classno,@name) = split(':');
    $shortname{$classno}=pop @name;
    ($namelist{$classno})=@name;
    $longname=$namelist{$classno};
    $long2short{"$longname"}=$shortname{$classno};
}
close(SCHEMEMAP);

# Read in the handle to filename mappings from the alltemps file in the
# guts directory.
chdir $iafa_source
  || &WriteToErrorLogAndDie("cullsl", "Can't chdir($iafa_source): $!");
%MAPPING = &readalltemps;
push(@ARGV, keys %MAPPING) if $opt_a;

# Actually process the template(s) to generate the list files
foreach $handle (@ARGV) {
    warn "Doing template \"$handle\"\n" if $debug;
    %TEMPLATE = &readtemplate("$handle");
    if(%TEMPLATE == undef) {
      &WriteToErrorLog("cullsl.pl",
		       "Couldn't read template with handle $handle");
      next;
    }
    &removetemplate($handle) if $TEMPLATE{handle} eq $handle;
    undef(%TEMPLATE);
}

# Convert each list file that has changed into an HTML document
$NewHTML = 0;
chdir($ListingDirectory) || &WriteToErrorLogAndDie("cullsl",
                              "Can't chdir($ListingDirectory): $!");
foreach $number (keys %ChangedList) {
    &GenHTML($number);
}

# Generate the alphabetic and numeric index files if a new HTML file
# has been generated

$me = "http://$ROADS::MyHostname";
$me .= ":$ROADS::MyPortNumber" if $ROADS::MyPortNumber ne 80;
if ($WWWDirectory =~ m!^/!) {
    $me .= "$WWWDirectory";
} else {
    $me .= "/$ROADS::WWWHtDocs/$WWWDirectory";
}

if ($NewHTML == 1 && !$opt_A) {
    chdir($HTMLDirectory)
      || &WriteToErrorLogAndDie("cullsl", "Can't chdir($HTMLDirectory): $!");
    close(STDOUT);
    open(STDOUT,">$AlphaListFile")
      || &WriteToErrorLogAndDie("cullsl", "Can't write to $AlphaListFile: $!");

    @handles = ();
    foreach $longname (sort(keys %long2short)) {
	$filename = $long2short{"$longname"};

	$TEMPLATE{"$filename"} =
	  "# FULL DOCUMENT $ROADS::Serverhandle $filename\n"
	. " TITLE: $longname\n"
	. " URI: $me/$filename.html\n"
	. "# END\n";
	
        push(@handles, "$filename");
    }

    &render("", "${SubjectListing}Alpha", @handles);
    close(STDOUT);
}

if ($NewHTML == 1 && !$opt_N) {
    chdir($HTMLDirectory)
      || &WriteToErrorLogAndDie("cullsl", "Can't chdir($HTMLDirectory): $!");
    close(STDOUT);
    open(STDOUT,">$NumListFile")
      || &WriteToErrorLogAndDie("cullsl", "Can't write to $NumListFile: $!");

    foreach $classno (sort(keys %shortname)) {
	$filename = $shortname{"$classno"};
	$longname = $namelist{"$classno"};

	$TEMPLATE{"$classno"} =
	  "# FULL DOCUMENT $ROADS::Serverhandle $filename\n"
	. " TITLE: $longname\n"
	. " URI: $me/$filename.html\n"
	. "# END\n";
	
        push(@handles, "$classno");
    }

    &render("", "${SubjectListing}Number", @handles);
    close(STDOUT);
}
exit;

#
# Generate an HTML file from a listing file
#
sub GenHTML {
    local($number) = @_;

    $name = $shortname{$number};
    $longname = $namelist{$number};
    unless (-e "$ListingDirectory/$name.lst") {
        unlink("$HTMLDirectory/$name.html");
        $NewHTML = 1;
        return;
    }

    system("$ROADS::SortPath -bf $ListingDirectory/$name.lst >$ListingDirectory/$name.$$");
    rename("$ListingDirectory/$name.$$","$ListingDirectory/$name.lst");
    $NewHTML = 1 unless -f "$name.html";

    close(STDOUT);
    open(STDOUT, ">$HTMLDirectory/$name.html")
      || &WriteToErrorLogAndDie("cullsl.pl",
           "Can't open HTML file $HTMLDirectory/$name.html: $!");

    $EscapedDatabaseName = $DatabaseName;
    $EscapedDatabaseName =~ s/\s/%20/g;

    open(LSTFILE,"$ListingDirectory/$name.lst")
	|| &WriteToErrorLogAndDie("cullsl.pl",
             "Can't reopen listing file $ListingDirectory/$name.lst: $!");

    @handles = ();
    while(<LSTFILE>) {
	chomp;
	($title,$handle,$mtime,$url) = split(":",$_,4);
	push(@handles, $handle);
    }
    close(LSTFILE);

    &render("", "$SubjectListing", @handles);
    close(STDOUT);
}

#
# Subroutine to scan a template for Library-Catalog entries and remove
# any entries from the appropriate files.
#
sub removetemplate {
    local($handle) = @_;

    local($attr,$number,$do) = 0;
    local(@udclist,@keylist);

    # Check if the template contains a URI attribute that matches the user
    # specified pattern.  Only proceed if it does.
    $do = 0;
    foreach $attr (keys %TEMPLATE) {
        $_ = $attr;
        if(/^UR[IL]/i) {
            $url = $TEMPLATE{$attr};
	    $_ = $url;
            $do = 1 if /$pattern/;
            warn "Do = $do,\tURL = $url,\tPattern = $pattern\n" if $debug;
        }
    }
    return if($do == 0);
    warn "Can do $TEMPLATE{handle}\n" if $debug;

    # Get the preferred URL of the resource.
    $url = &preferredURL;
    warn "Preferred URL = $url\n" if $debug;
    @keylist = keys %TEMPLATE;
    ($title) = grep(/^title/i,@keylist);

    foreach $attr (@keylist) {
        $_ = $attr;
        warn "Got a field called $attr.\n" if $debug;
        if (/^Subject-Descriptor-Scheme-v([0-9]+)/i) {
            warn "Found scheme called $TEMPLATE{$attr}\n" if $debug;
	    $variant = $1;
            if($TEMPLATE{$attr} eq $scheme_name) {
                $attr = "subject-descriptor-v$variant";
	        @udclist = split(/[ ,]/,$TEMPLATE{$attr});
                warn "$attr = @udclist\n" if $debug;
                $newresource = 0;
                foreach $number (@udclist) {
                    warn "Doing removefromsubjlist($number)...\n" if $debug;
                    &removefromsubjlist($number);
                }
            }
        }
    }
}

#
# Subroutine to remove the details of a template from a subject list record file
# NOTE: This is NOT creating the HTML file - that comes later
#
sub removefromsubjlist {
    local($number) = @_;
    local($inserted,$oldtitle,$oldhandle,$oldmtime,$normtitle,$mtime) = 0;
    local(@stat);

    # If there isn't a name mapping for this subject descriptor, then quietly
    # ignore it.
    return if ($namelist{$number} eq "");

    # Get the last modification time of the template file.  Note that in the
    # cases where there exists more than one template in a file, this will
    # show that all templates have been modified at the same time.  Which is
    # a bit of a bummer, but then none of the ROADS software _generates_ 
    # multiple templates in a single file.
    (@stat) = stat($MAPPING{$handle});
    $mtime = $stat[9];

    # Strip out any nasty carriage returns and/or linefeeds from the title of
    # the record being processed and convert it to lower case if caseless
    # alphabetising is being done.
    $normtitle = $TEMPLATE{$title};
    $normtitle =~ s/\x0D//;
    $normtitle =~ s/\x0A//;
    $normtitle =~ s/^\s+//;
    $normtitle =~ y/A-Z/a-z/ if ($opt_c == 0);

    # Generate a carriage return and linefeed-less version of the title, but
    # maintain its given case for use in outputing to the listing files.
    $outtitle = $TEMPLATE{$title};
    $outtitle =~ s/\x0A//;
    $outtitle =~ s/\x0D//;
    $outtitle =~ s/^\s+//;
    $outtitle =~ s/\s+//;

    # See if a subject listing for this subject class number already exists
    # and if not generate one.  If one does exist, merge the current template
    # into the file.
    local($inserted) = 0;
    warn "Looking for listing file $ListingDirectory/$shortname{$number}.lst\n"
	if $debug;
    if(-e "$ListingDirectory/$shortname{$number}.lst") {
        open(OLDINDEX,"$ListingDirectory/$shortname{$number}.lst")
          || &WriteToErrorLogAndDie("cullsl.pl",
               "Can't open $listing_tree_root/$shortname{$number}.lst: $!");
        open(INDEX,">$ListingDirectory/$shortname{$number}.lst.$$")  
          || &WriteToErrorLogAndDie("cullsl.pl",
               "Can't open $ListingDirectory/$shortname{$number}.lst.$$: $!");
        warn "Culling from existing listing file...\n" if $debug;
        local($count) = 0;
        while(<OLDINDEX>) {
            # We'll use lines starting with hash as comments.
            next if /^#/;
            next if /^\n$/;
            chomp;
            # Split up the next entry in the subject listing file.
            ($oldtitle,$oldhandle,$oldmtime,$oldurl) = split(":",$_,4);
            # Normalise the old title in the same way that we did for the
            # title of the template being merged into the list
            $normoldtitle = $TEMPLATE{$title};
            $normoldtitle =~ s/\x0D//;
            $normoldtitle =~ s/\x0A//;
            $normoldtitle =~ s/^\s+//g;
            $normoldtitle =~ y/A-Z/a-z/ if ($opt_c == 0);

            # If we're processing a template that has been changed since it
            # was last recorded in this subject listing, change the entry.
            # If it hasn't changed put, old value back in the listing.  If
            # the current index entry's handle doesn't match the handle of
            # the current template then just write the old entry back out.
            if($oldhandle eq $handle) {
                $ChangedList{$number}=1;
                $inserted = 1;
            } else {
                print INDEX "$oldtitle:$oldhandle:$oldmtime:$oldurl\n";
                $count++;
            }
        }
        close(OLDINDEX);
        close(INDEX);
        rename("$ListingDirectory/$shortname{$number}.lst.$$",
          "$ListingDirectory/$shortname{$number}.lst");
        unlink("$ListingDirectory/$shortname{$number}.lst") if($count==0);
    }
}

exit;
__END__


=head1 NAME

B<bin/cullsl.pl> - cull entries from subject listings

=head1 SYNOPSIS

  bin/cullsl.pl [-ANacdh] [-f directory] [-l view]
    [-m filename] [-n name] [-p pattern]
    [-s directory] [-t directory] [-u name]
    [handle1 handle2 ... handleN]

=head1 DESCRIPTION

The B<cullsl.pl> program removes one or more templates from a set of
subject listing files.  These changed listing files are also converted
into static HTML documents which can be placed on the WWW.  The
program also generates HTML lists in numerical and alphabetical order
based on the contents of a subject descriptor mapping file.  This
program shares many of its configuration files with B<addsl.pl>.

=head1 USAGE

<em>cullsl.pl</em> which lets you remove selected templates' details from
the subject listings generated by I<addsl.pl>.  This uses the same
mechanism as I<addsl.pl>, and simply takes the handles of the templates you
wish to remove as its arguments when run, e.g.

  % cullsl.pl 814010256-14355

=head1 OPTIONS

A number of options are available B<cullsl.pl> program to control
which files are used for generating the subject listings and where
configuration options are located:

=over 4

=item B<-A>

Don't generate alphabetically sorted breakdown of subject categories.

=item B<-a>

Process all templates in source directory.

=item B<-c>

Specify that the alphabetical listing should take acount of the case
of the characters.  Without this option, B<acorn> , B<Apple> and
B<Zebra> are sorted in that order.  With this flag set, they would be
sorted as B<Apple> , B<Zebra> and B<acorn>.

=item B<-d>

Specify that some (fairly copious) debugging information should be
generated during the generation of the hypertext tree.  This option is
probably not of interest to anyone bar the developers.

=item B<-f> I<directory>

Specify the directory for views configuration files.

=item B<-h>

Provide some online help outlining the options available and exit.

=item B<-l> I<view>

Set subject listing view name.  This is the name of the file that
contains the configuration information concerning the location of the
listings, HTML and outline files.  For more information on this see
below.

=item B<-m> I<filename>

Specify the subject descriptor mapping file to use.

=item B<-n> I<name>

Specifies the name of the database to use - by default this is the
name of the service as entered when the ROADS software was installed.

=item B<-p> I<pattern>

Only enter entries in the subject listings for templates that have URI
fields that match the supplied pattern.  The pattern can be a full
Perl regular expression and allows one to, for example, restrict
entries in the subject listings to only include UK academic sites.  By
default the pattern matches all URLs and so all templates are included
in the hypertext lists.

=item B<-s> I<directory>

Set the B<absolute> pathname of the directory containing the IAFA
templates.

=item B<-t> I<directory>

Set the B<absolute> pathname of the directory where subject listing
mapping files (internal files used to maintain state between runs of
the ROADS subject listing tools) should be stored.

=item B<-u> I<name>

Sets the name of the Subject-Descriptor-Scheme to search for in the
templates.  The default is I<UDC>.

=back

These options are then followed by zero or more templates handles (note
- I<not> filenames).  If the B<-a> option is given, no handles need be
given on the command line; all templates in the database will be added
to the subject listings.

=head1 FILES

I<config/class-map> - default mappings from

I<Subject-Descriptor-Scheme> attributes in templates
to filenames used for generating HTML.

I<config/subject-listing/*> - view files, each of which
describing a particular way of rendering the templates
into HTML.

I<config/multilingual/*/subject-listing-views/*> - HTML
rendering rules for subject listing views.

I<guts/subject-listing/*.lst> - default location of the
internal files used to maintain state between runs of
subject listing tools.

I<htdocs/subject-listing> - default location of the HTML
generated by B<cullsl.pl>

=head1 FILE FORMATS

=over 4

=item Subject Descriptor Mapping File

The subject descriptor mapping file specifies the code for a
particular subject section, the name given to that section in the HTML
documents and the root of the filename used to hold that section's
hypertext listing, each element being separated by a colon.  An example
line from a subject descriptor mapping file (for the UDC subject
descriptor scheme) is:

 30.442:Development Studies:devstud

Note that the section name should not contain the colon character ":"
- this would confuse B<addsl.pl>.

=item CONFIGURING VIEWS

The B<cullsl.pl> can generate a number of different subject listings.
This allows, for example, a subject listing of UK based resources in
addition to a subject listing of all resources.  The views also allow
easy selection of which subject listing a template should be added to in the
B<mktemp.pl> editor.

The view is specified by a view file.  An example file is:

  HTML-Directory: /WWW/htdocs/ROADS/subject-listing/
  WWW-Directory: /ROADS/sl/
  NumList-File: /ROADS/sl/numeric.html
  AlphaList-File: /ROADS/sl/numeric.html
  Listing-Directory: /usr/local/ROADS/guts/subject-listing/
  Mapping-File: /usr/local/ROADS/config/subject-listing/class-map
  Generate-Children: yes

=back

The various attributes currently defined in the view file are:

=over 4

=item I<AlphaList-File>

The name of the file into which B<addsl.pl> will save a list of the
subject categories sorted by alphabetical order.

=item I<Casefold-List>

Turns on case folding when alphabetising the list - the same as the
I<-c> option on the command line.

=item I<Generate-Children>

Whether or not to generate subject listings for templates that only
have I<ChildOf> relation types in them.

=item I<HTML-Directory>

The path to the directory in which the subject listing HTML documents
should be generated.  This directory should be accessible to the HTTP
daemon that serves the ROADS documents if they are to be accessible
via the World Wide Web.  If the path is a relative one, it is assumed
to be relative to the ROADS I<htdocs> directory, i.e. the directory
under which the ROADS related HTML documents are rooted.

=item I<Listing-Directory>

The path to the directory in which the subject listing files should be
located.  This is typically a subdirectory of the F<guts> directory of
the ROADS installation, where internal files used only by the ROADS
software are kept.  If this is a relative path, it is assumed to be
relative to the ROADS I<guts> directory.

=item I<Mapping-File>

The path to the subject descriptor mapping file.  If this is a relative
path, it is assumed to be relative to the ROADS I<config> directory.

=item I<Subject-Scheme>

The name of the subject scheme that this view relates to.

=item I<WWW-Directory>

The WWW path to the directory in which the HTML generated by
B<addsl.pl> will appear.  This includes the I<AlphaList-File> and
I<NumList-File> listings.

=back

=head1 SEE ALSO

L<bin/addsl.pl>, L<bin/addwn.pl>, L<bin/cullwn.pl>, L<bin/mkinv.pl>

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

