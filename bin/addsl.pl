#!/usr/bin/perl
use lib "/home/roads2/lib";

#
# addsl.pl - generate resource description breakdown by subject category
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#         Martin Hamilton <martinh@gnu.org>
# $Id: addsl.pl,v 3.27 1999/07/29 14:39:37 martin Exp $

use Getopt::Std;

require ROADS;
use ROADS::ErrorLogging;
use ROADS::Override;
use ROADS::PreferredURL;
use ROADS::ReadTemplate;
use ROADS::Render;

# Process command line arguments
getopts('ANacdf:hil:m:n:o:p:s:t:u:w:');

if ($opt_h) {
    print STDERR "Usage $0: [options] [handle [handle...]]\n";
    print STDERR "\t[-A]\t: Don't generate alphabetical subject index\n";
    print STDERR "\t[-N]\t: Don't generate numeric subject index\n";
    print STDERR "\t[-a]\t: Process all templates in source directory\n";
    print STDERR "\t[-c]\t: Caseful alphabetising\n";
    print STDERR "\t[-d]\t: Enter debug mode\n";
    print STDERR "\t[-f <directory>]\t: Directory for config files (default: $ROADS::Config/subject-listing)\n";
    print STDERR "\t[-h]\t: This help\n";
    print STDERR "\t[-i]\t: Ignore timestamps and always (re)generate HTML\n";
    print STDERR "\t[-l <view>]\t: Set subject listing view name (default: Default)\n";
    print STDERR "\t[-m <file>]\t: Set classification mapping file (default: $ROADS::Config/class-map)\n";
    print STDERR "\t[-n <name>]\t: Set database name (default: $ROADS::ServiceName)\n";
    print STDOUT "\t[-o <file>]\t: Set override file (default: $ROADS::Config/override)\n";
    print STDERR "\t[-p <pattern>]\t: match <pattern> in URI field\n";
    print STDERR "\t[-s <directory>]\t: Set IAFA template source directory (default: $ROADS::IafaSource)\n";
    print STDERR "\t[-t <directory>]\t: Set class mapping file target directory (default: $ROADS::HtDocs/subject-listing/Default)\n";
    print STDERR "\t[-u <scheme>]\t: Set scheme (default: UDC)\n";
    print STDERR "\t[-w <url>\t: Set the URL of the waylay CGI script (default: /$ROADS::WWWCgiBin/waylay.pl)\n";
    exit;
}

#
# Main code
#

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

# Default location of the subject listing tree structure
$ListingDirectory = $opt_t || "$ROADS::Guts/subject-listing/Default";
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

# Default of whether to generate listing entry for child resources.
$GenerateChildren = 0;

# Default of caseless alphabetising
$opt_c = $opt_c || 0;

# Default URI matching pattern matches everything
$pattern = $opt_p || "(.*)";

# Protocol schemes to override
$protocols = $opt_o || "$ROADS::Config/protocols";

# The URL of the "waylay" script (sits between result listing and object)
$waylay = $opt_w || "/$ROADS::WWWCgiBin/waylay.pl";

# Load in the protocols to override with redirections to waylay.pl
&Override;

# Open the selected Subject Listing view.
open(VIEW,"$SubjectListingViews/$SubjectListing")
  || &WriteToErrorLogAndDie("addsl",
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
	$scheme_name =~ s/^Subject-Scheme:\s*//i;
    } elsif (/^Section-Editors-File:\s+(.*)/i) {
        $SecEdFile = $1;
        $SecEdFile = "$ROADS::Config/$SecEdFile"
          unless $SecEdFile =~ /^\//;
    } elsif (/^Casefold-List/i) {
	$opt_c = 1;
    } elsif (/^Generate-Children:\s*(.*)/i) {
        $GenerateChildren = 1 if ($1 =~ /^yes/i);
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

# If the target listing directory doesn't exist, create it.
unless (-d "$ListingDirectory") {
    mkdir("$ListingDirectory", 0755)
      || &WriteToErrorLogAndDie("addsl", "Can't create $ListingDirectory: $!");
}

# Slurp in the subject descriptor scheme name mapping file.
open(SCHEMEMAP,$MappingFile)
  || &WriteToErrorLogAndDie("addsl", "Can't open scheme map $MappingFile: $!");
while(<SCHEMEMAP>) {
    chomp;
    ($classno,@name) = split(':');
    $namelist{"$classno"}=shift @name;
    $shortname{"$classno"}=shift @name;
    $parentOf{"$classno"}=shift @name; # if there is one
    $relatedList{"$classno"}=shift @name; # if there are any (';' separated)
    $longname=$namelist{"$classno"};
    $long2short{"$longname"}=$shortname{"$classno"};
}
close(SCHEMEMAP);

# Read in the handle to filename mappings from the alltemps file in the
# guts directory
chdir ($iafa_source)
  || &WriteToErrorLogAndDie("addsl", "Can't chdir($iafa_source): $!");
%MAPPING = &readalltemps;
push(@ARGV, keys %MAPPING) if $opt_a;

# Get section editors
if (open(SEC_ED,$SecEdFile)) {
  while(<SEC_ED>) {
    next if (/^\#/);
    chomp;
    my ($name, $file, @sub) = split(':');
    foreach $sub (@sub) {
      $SEC_ED{$sub} = "$name:$file";
    }
  }
  close(SEC_ED);
} else {
  &WriteToErrorLog("addsl", "Can't open section editors file $SecEdFile: $!");
}

# Build any parent/child hashes
foreach $num (keys %parentOf) {
  next unless ($parentOf{$num});
  $parents{$num} .= "$parentOf{$num}:$namelist{$parentOf{$num}}:$shortname{$parentOf{$num}}\n";
  $children{$parentOf{$num}} .= "$num:$namelist{$num}:$shortname{$num}\n";
}

# Build any related hashes
foreach $num (keys %relatedList) {
  my @relList = split /\s*;\s*/,$relatedList{"$num"};
  foreach $num2 (@relList) {
    $related{"$num"} .= "$num2:$namelist{$num2}:$shortname{$num2}\n";
  }
}

# Actually process the template(s) to generate the list files
foreach $handle (@ARGV) {
    warn "Doing template \"$handle\"\n" if $debug;
    %TEMPLATE = &readtemplate("$handle","$iafa_source/$MAPPING{$handle}");
    &inserttemplate($handle) if $TEMPLATE{handle} eq $handle;
    undef(%TEMPLATE);
}

# Add empty list files for those sections without resources
# important for hierarchical browsing
foreach $number (keys %shortname) {
  if(!-e "$ListingDirectory/$shortname{\"$number\"}.lst") {
    &WriteToErrorLog("addsl",
		     "$ListingDirectory/$shortname{$number}.lst doesn't exist - creating");
    open(INDEX,">$ListingDirectory/$shortname{$number}.lst")
      || &WriteToErrorLogAndDie("addsl",
				"Can't open $ListingDirectory/$shortname{$number}.lst: $!");
    close(INDEX);
    $ChangedList{"$number"} = 1;
  }
}

# Convert each list file that has changed into an HTML document
$NewHTML = 0;
chdir($ListingDirectory)
  || &WriteToErrorLogAndDie("addsl", "Can't chdir($ListingDirectory): $!");
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

if (($NewHTML == 1 || $opt_i) && !$opt_A) {
    system("mkdir -p $HTMLDirectory") unless -d "$HTMLDirectory";
    chdir($HTMLDirectory)
      || &WriteToErrorLogAndDie("addsl", "Can't chdir($HTMLDirectory): $!");
    close(STDOUT);
    open(STDOUT,">$AlphaListFile")
      || &WriteToErrorLogAndDie("addsl", "Can't write to $AlphaListFile: $!");

    @handles = ();
    foreach $longname (sort(keys %long2short)) {
	$filename = $long2short{"$longname"};
        next unless (-e "$ListingDirectory/$filename.lst" && 
                     -s "$ListingDirectory/$filename.lst");
	$TEMPLATE{"$filename"} =
	  "# FULL DOCUMENT $ROADS::Serverhandle $filename\n"
	. " TITLE: $longname\n"
	. " URI: $me/$filename.html\n"
	. "# END\n";
	
        push(@handles, "$filename");
    }

    local $myurl = "$name.html";
    &render("", "${SubjectListing}Alpha", @handles);
    close(STDOUT);
}

if (($NewHTML == 1 || $opt_i) && !$opt_N) {
    system("mkdir -p $HTMLDirectory") unless -d "$HTMLDirectory";
    chdir($HTMLDirectory)
      || &WriteToErrorLogAndDie("addsl", "Can't chdir($HTMLDirectory): $!");
    close(STDOUT);
    open(STDOUT,">$NumListFile")
      || &WriteToErrorLogAndDie("addsl", "Can't write to $NumListFile: $!");

    @handles = ();
    undef %TEMPLATE;
    foreach $classno (sort(keys %shortname)) {
	$filename = $shortname{"$classno"};
	$longname = $namelist{"$classno"};
        next unless (-e "$ListingDirectory/$filename.lst" && 
                     -s "$ListingDirectory/$filename.lst");
	$TEMPLATE{"$classno"} =
	  "# FULL DOCUMENT $ROADS::Serverhandle $filename\n"
	. " TITLE: $longname\n"
	. " URI: $me/$filename.html\n"
	. "# END\n";
	
        push(@handles, "$classno");
    }

    local $myurl = "$name.html";
    &render("", "${SubjectListing}Number", @handles);
    close(STDOUT);
}
exit;

#
# Generate an HTML file from a listing file
#
sub GenHTML {
    my($number) = @_;

    $name = $shortname{"$number"};
    $longname = $namelist{"$number"};
    local $parents;
    my ($num, $longname, $shortname) = split /:/,$parents{"$number"};
    chomp $shortname;
    if (-f "$ListingDirectory/$shortname.lst") {
      $parents = "$longname:$shortname:$num";
    }
    local $children;
    my @tmp;
    foreach $child (split /\n/,$children{"$number"}) {
      my ($num, $longname, $shortname) = split /:/,$child;
      if (-f "$ListingDirectory/$shortname.lst") {
	push @tmp,"$longname:$shortname:$num";
      }
    }
    $children = join "\n",(sort @tmp);
    undef $children unless $children;
    undef @tmp;
    local $related;
    foreach $rel (split /\n/,$related{"$number"}) {
      my ($num, $longname, $shortname) = split /:/,$rel;
      if (-f "$ListingDirectory/$shortname.lst") {
	push @tmp,"$longname:$shortname:$num";
      }
    }
    $related = join "\n",(sort @tmp);
    undef $related unless $related;
    local ($sec_ed, $sec_ed_page) = split /\:/,$SEC_ED{"$number"};
    undef $sec_ed unless $sec_ed;
    undef $sec_ed_page unless $sec_ed;
    system("$ROADS::SortPath -bf $name.lst >$name.$$");
    rename("$name.$$","$name.lst");
    $NewHTML = 1 unless -f "$name.html";

    system("mkdir -p $HTMLDirectory") unless -d "$HTMLDirectory";
    close(STDOUT);
    open(STDOUT, ">$HTMLDirectory/$name.html")
      || &WriteToErrorLogAndDie("addsl.pl",
           "Can't open HTML file $HTMLDirectory/$name.html: $!");

    $EscapedDatabaseName = $DatabaseName;
    $EscapedDatabaseName =~ s/\s/%20/g;

    open(LSTFILE,"$ListingDirectory/$name.lst")
	|| &WriteToErrorLogAndDie("addsl.pl",
             "Can't reopen listing file $ListingDirectory/$name.lst: $!");

    @handles = ();
    while(<LSTFILE>) {
	chomp;
	($title,$handle,$mtime,$url) = split(":",$_,4);
	push(@handles, $handle);
    }
    close(LSTFILE);

    local $myurl = "$name.html";
    &render("", "$SubjectListing", @handles);
    close(STDOUT);
}

#
# Subroutine to scan a template for Subject-Descriptor entries and put
# them in the right place in the subject listing tree.
#
sub inserttemplate {
    my($handle) = @_;

    my($attr,$number,$do) = 0;
    my(@udclist,@keylist);

    # Ignore stale templates
    return if($TEMPLATE{status} =~ /stale/i);

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

    # Check if the template has a ParentOf relation (or no relations
    # at all) if not set to generate listings for children
    unless ($GenerateChildren) {
      my($do,$type,$relcount);
      $do = 0;
      $relcount = 0;
      foreach $attr (keys %TEMPLATE) {
        $_ = $attr;
        if(/^Relation-Type/i) {
            $relcount++;
            $type = $TEMPLATE{"$attr"};
            $do = 1 if ($type =~ /ParentOf/i);
            warn "Do = $do,\tType = $type,\tRelcount = $relcount\n" if $debug;
         }
      }
      return if (($do == 0) && ($relcount > 0));
    }
    warn "Can do $TEMPLATE{handle}\n" if $debug;

    # Get the preferred URL of the resource.
    $url = &preferredURL(%TEMPLATE);
    warn "Preferred URL = $url\n" if $debug;
    @keylist = keys %TEMPLATE;
    ($title) = grep(/^title/i,@keylist);

    foreach $attr (@keylist) {
        $_ = $attr;
        warn "Got a field called $attr.\n" if $debug;
        if(/^Subject-Descriptor-Scheme-v([0-9]+)/i) {
            $variant = $1;
            $schemeattr = $TEMPLATE{"$attr"};
            $schemeattr =~ s/^\s*//;
            warn "Found scheme called $schemeattr\n" if $debug;
            if($schemeattr eq $scheme_name) {
                $attr = "subject-descriptor-v$variant";
	        @udclist = split(/[ ,]/,$TEMPLATE{"$attr"});
                warn "$attr = @udclist\n" if $debug;
                $newresource = 0;
                foreach $number (@udclist) {
                    &addtosubjlist($number,$handle);
                }
            }
        }
    }
}

#
# Subroutine to add the details of a template a subject list record file
# NOTE: This is NOT creating the HTML file - that comes later
#
sub addtosubjlist {
    my($number,$handle) = @_;
    my($inserted,$oldtitle,$oldhandle,$oldmtime,$normtitle,$mtime) = 0;
    my(@stat);

    # If there isn't a name mapping for this subject descriptor, then quietly
    # ignore it.
    return if ($namelist{"$number"} eq "");

    # Get the last modification time of the template file.  Note that in the
    # cases where there exists more than one template in a file, this will
    # show that all templates have been modified at the same time.  Which is
    # a bit of a bummer, but then none of the ROADS software _generates_ 
    # multiple templates in a single file.
    (@stat) = stat($MAPPING{"$handle"});
    $mtime = $stat[9];

    # Strip out any nasty carriage returns and/or linefeeds from the title of
    # the record being processed and convert it to lower case if caseless
    # alphabetising is being done.
    $normtitle = $TEMPLATE{"$title"};
    $normtitle =~ s/\x0D/ /g;
    $normtitle =~ s/\x0A/ /g;
    $normtitle =~ s/^\s+//;
    $normtitle =~ s/:/;/g;
    $normtitle =~ y/A-Z/a-z/ if ($opt_c == 0);

    # Generate a carriage return and linefeed-less version of the title, but
    # maintain its given case for use in outputing to the listing files.
    $outtitle = $TEMPLATE{"$title"};
    $outtitle =~ s/\x0A/ /g;
    $outtitle =~ s/\x0D/ /g;
    $outtitle =~ s/^\s+//;
    $outtitle =~ s/\s+/ /g;
    $outtitle =~ s/:/;/g;

    # See if a subject listing for this subject class number already exists
    # and if not generate one.  If one does exist, merge the current template
    # into the file.
    my($inserted) = 0;
    if(!-e "$ListingDirectory/$shortname{\"$number\"}.lst") {
        &WriteToErrorLog("addsl",
	 "$ListingDirectory/$shortname{$number}.lst doesn't exist - creating");
        open(INDEX,">$ListingDirectory/$shortname{$number}.lst")
          || &WriteToErrorLogAndDie("addsl",
               "Can't open $ListingDirectory/$shortname{$number}.lst: $!");
        print INDEX "$outtitle:$handle:$mtime:$url\n";
        warn "Creating initial entry of \"$outtitle:$handle:$mtime:$url\"\n"
	    if $debug;
        close(INDEX);
        $ChangedList{"$number"} = 1;
    } else {
        open(OLDINDEX,"$ListingDirectory/$shortname{$number}.lst")
          || &WriteToErrorLogAndDie("addsl", 
               "Can't open $ListingDirectory/$shortname{$number}.lst: $!");
        open(INDEX,">$ListingDirectory/$shortname{$number}.lst.$$")  
          || &WriteToErrorLogAndDie("addsl",
               "Can't open $ListingDirectory/$shortname{$number}.lst.$$: $!");
        while(<OLDINDEX>) {
            # We'll use lines starting with hash as comments.
            next if /^#/;
            next if /^\n$/;
            chomp;
            # Split up the next entry in the subject listing file.
            ($oldtitle,$oldhandle,$oldmtime,$oldurl) = split(":",$_,4);
            # Normalise the old title in the same way that we did for the
            # title of the template being merged into the list
            $normoldtitle = $TEMPLATE{"$title"};
            $normoldtitle =~ s/\x0D/ /g;
            $normoldtitle =~ s/\x0A/ /g;
            $normoldtitle =~ s/^\s+//g;
            $normoldtitle =~ s/:/;/g;
            $normoldtitle =~ y/A-Z/a-z/ if ($opt_c == 0);

            # If we're processing a template that has been changed since it
            # was last recorded in this subject listing, change the entry.
            # If it hasn't changed put, old value back in the listing.  If
            # the current index entry's handle doesn't match the handle of
            # the current template then just write the old entry back out.
            if($oldhandle eq $handle) {
                if($mtime ne $oldmtime) {
                    print INDEX "$outtitle:$handle:$mtime:$url\n";
                    $ChangedList{"$number"} = 1;
                    warn "Updating index with \"$outtitle:$handle:$mtime:$url\"\n" if $debug;
                } else {
                    print INDEX "$oldtitle:$oldhandle:$oldmtime:$oldurl\n";
		    if($opt_i) {
			$ChangedList{"$number"} = 1;
			warn "Added $number to ChangedList (used -i option)\n"
			  if $debug;
		    } else {
                    	warn "Template matches existing entry, not touching\n"
			  if $debug;
		    }
                }
                $inserted = 1;
            } else {
                print INDEX "$oldtitle:$oldhandle:$oldmtime:$oldurl\n";
            }
        }
        # If we didn't find an old version of the template to overwrite, tack
        # an entry for it onto the end of the subject listing.
        if($inserted == 0) {
            print INDEX "$outtitle:$handle:$mtime:$url\n";
            $ChangedList{"$number"} = 1;
        }
        close(OLDINDEX);
        close(INDEX);
        rename("$ListingDirectory/$shortname{$number}.lst.$$",
          "$ListingDirectory/$shortname{$number}.lst");
    }
}


exit;
__END__


=head1 NAME

B<bin/addsl.pl> - generate HTML subject listings from ROADS templates

=head1 SYNOPSIS

  bin/addsl.pl [-ANacdhi] [-f config_dir] [-l view]
    [-m filename] [-n database_name] [-o override_file]
    [-p pattern] [-s source_dir] [-t target_dir] [-u name]
    [-w waylay_url] [handle1, handle2 ... handleN]

=head1 DESCRIPTION

The B<addsl.pl> program generates a set of subject listing files for
the templates with the specified handles.  These listing files are
also converted into static HTML documents which can be placed on the
WWW.  The program can also generate HTML lists in numerical and
alphabetical order based on the contents of a subject descriptor
mapping file.

The B<addsl.pl> program can generate a number of different subject
listings.  This allows, for example, a subject listing of UK based
resources in addition to a subject listing of all resources.  The
views also allow easy selection of which subject listing a template
should be added to in the B<admin-cgi/mktemp.pl> editor.

=head1 USAGE

You can arrange for the ROADS software to generate listings of some or
all of your templates broken down by subject area.  Note that each
template which you would like to appear in a subject listing should
contain at least one B<URI> attribute and at least one
B<Subject-Descriptor> cluster.

You may have as many different I<views> of your templates as you
like.  Each view is normally a collection of statically generated HTML
documents created by I<addsl.pl>, though in version 2 of ROADS you can
also browse dynamically through your database using "canned" queries.
The subject listings may be customized in a number of ways - notably
via HTML I<outline files> may be used to specify the overall format of
each HTML document generated by the ROADS software.  These have some
extra pseudo-HTML tags which allow you to indicate where in the
resulting documents you would like the subject listing information to
appear.

It is also possible to specify a pattern which the URIs in the
resource description templates will have to match in order to be
included in a subject listing.  This can be used to generate, for
example, lists of resources which are found in the UK academic
community, resources which are generated dynamically by scripts, all
resources of a particular type (e.g. MPEG movies), and so on.

I<addsl.pl> will also generate customizable lists of the
available subject categories in both alphabetical and numerical order
(assuming the B<Subject-Descriptor> classification is numeric.

I<addsl.pl> can link sections together via 'parent/child' relationships
defined in the subject descriptor mapping file. Sections can also be
linked together via a 'related' relationship. As well as this, each section
can have an editor attributed, together with a link to a profile page.

A default set of subject categories based on the different programme
areas in the UK Electronic Libraries Programme (to match our sample
database) is distributed with the ROADS software as I<config/classmap>,
under the top level ROADS installation directory.  You will probably want
to change this to reflect your installation.

The file format of the subject listing I<views> is explained in detail
below.  Essentially, it should contain pointers to the location of each of
the following:

=over 4

=item *

Outline HTML files for the subject listings themselves, and the
breakdowns of subject categories by alphabetical and numerical order

=item *

The directory (visible to your WWW server) where the generated
HTML files should be placed

=item *

The directory where any internal files used by the subject
listing generator should be stored

=item *

The location of the mapping file which provides titles for each
of the classifications in your scheme, and the names of the HTML files
which should be generated for each classification

=back

A typical view specification would look like this:

  HTML-Directory:         subject-listing
  WWW-Directory:          subject-listing
  Listing-Directory:      subject-listing
  Mapping-File:           class-map
  Subject-Scheme:         DDC
  AlphaList-File:         alphalist.html
  NumList-File:           numlist.html

The meanings of these path names are explained below.  It is worth
noting that they can be either relative (to the various directories
involved in generating the subject listings, such as the ROADS I<config>,
I<guts> and I<htdocs> directories), or absolute - e.g.
I</usr/local/roads/guts/subject-listing/Default>.  You may prefer to
refer to them by the full path name to avoid confusion, but be aware
that this may cause you problems if you move the ROADS installation to
another directory tree.

Note that the ROADS software comes shipped with defaults for the
I<Default>, I<DefaultAlpha> and I<DefaultNumber> outlines.  The
outline HTML used to generate the actual subject listings lives by
default under I<config/multilingual/*/subject-listing-views>.  In
version 2 of ROADS we switched to using our generic HTML rendering
code, away from the old hard-coded HTML rendering embedded in the
older versions of this code.

If your B<Subject-Descriptor-Scheme> is I<UDC> (the
default), you should be able generate subject listings for all your
templates using the default view by running I<addsl.pl> with the
B<-a> argument:

  % addsl.pl -a

You will not need to do this if you are creating templates from
scratch using the WWW based forms editor - this gives you the option
of entering new templates into the subject listings automatically.  In
fact, it runs I<addsl.pl> behind the scenes.  If you only want
to add a subset of your templates (such as those which have changed
recently), I<addsl.pl> should be called without the B<-a>
argument, and with the B<handles> of the templates as
arguments, e.g.

  % addsl.pl 0123 0124 0125

If you would like to create more than one view of your resource
description templates, e.g. to have a separate B<AllUK> listing
of resources which pertain to the UK higher education community
(Internet domain - I<ac.uk>), you will need to make another view
file and run I<addsl.pl> with the B<-l> specifying this,
e.g.  the view file for B<AllUK> might look something like
this:
 
  Outline-File: subject-listing/Default
  HTML-Directory: subject-listing/AllUK/
  Listing-Directory: subject-listing/AllUK/
  Mapping-File: subject-listing/classmap
  Alpha-Outline: subject-listing/DefaultAlpha
  Number-Outline: subject-listing/DefaultNumber

Whilst in this example the same HTML outline documents have been used
for both views, this is entirely under the control of the ROADS server
administrator.  To create the B<AllUK> view, you would need to
run I<addsl.pl> with both the B<-l> and B<-p>
arguments, e.g.

  % addsl.pl -a -p '\.ac\.uk' -l AllUK

The resulting subject listing files will be generated in the directory
specified in the view file as B<HTML-Directory>, e.g.
I</usr/local/www/ROADS/subject-listing/AllUK>.  The following
files will be generated:

=over 4

=item *

I<alphalist.html> - breakdown of subject categories in alphabetical order

=item *

I<numlist.html> - breakdown of subject categories in numerical order

=item *

A separate HTML file for each of the subject categories listed in
your B<Mapping-File>.  These will be based on the short
name for the subject category, with a I<.html> tacked on the end

=back

Should you ever need to completely re-generate your subject listings,
it will be necessary to remove the files in the directory specified by
the B<Listing-Directory> entry in the view file, e.g. 
I</usr/local/roads/guts/subject-listing/AllUK>.  You may also choose
to remove the HTML documents generated by I<addsl.pl> in the
B<HTML-Directory>.  Alternatively, I<cullsl.pl> the
subject list culling tool, may be adequate for your needs - see its
manual page for more information.

Note that if they do not exist already, you will need to create parent
directories for the directories referred to in a subject listing view
configuration file.

=head1 OPTIONS

A number of options are available for the B<addsl.pl> program to
control which files are used for generating the subject listings and
where configuration options are located.  Note that most of these can
also be supplied in the B<addsl.pl> view config file (see below), and
that settings which appear in this will usually override command line
arguments.

=over 4

=item B<-A>

Don't generate alphabetical subject index

=item B<-a>

Process all templates in source directory.

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

=item B<-i>

Regenerate HTML files regardless of timestamps on subject listing
files.

=item B<-l> I<view>

Set subject listing view name.  This is the name of the file that
contains the configuration information concerning the location of the
listings, HTML and outline files.  For more information on this see
below.

Be aware that for a given view you will actually need three sub-
directories under the I<config/multilingual/*/subject-listing-views>
directory, named I<view>, I<view>Alpha, and I<view>Number.  This is
because the B<addsl.pl> tool generates three separate sets of HTML
files when it runs - the regular view of your database, plus views
sorted by numerical and alphabetical order.

Just another reminder that the settings specified in a view file
typically override other command line arguments,
e.g. I<Subject-Scheme> overrides the I<-u> argument.

=item B<-m> I<filename>

Specify the subject descriptor mapping file to use.

=item B<-N>

Don't generate numeric subject index.

=item B<-n> I<name>

Specifies the name of the database to use when generating HTML.  The
default is the service name which was entered when the ROADS software
was installed.

=item B<-p> I<pattern>

Only enter entries in the subject listings for templates that have URI
fields that match the supplied pattern.  The pattern can be a full
Perl regular expression and allows one to, for example, restrict
entries in the subject listings to only include UK academic sites.  By
default the pattern matches all URLs and so all templates are included
in the hypertext lists.

=item B<-s> I<source_dir>

Set the I<absolute> pathname of the directory containing the IAFA
templates.

=item B<-t> I<target_dir>

Set the I<absolute> pathname of the directory where the files created
by I<addsl.pl> will be placed.

=item B<-u> I<name>

Sets the name of the Subject-Descriptor-Scheme to search for in the
templates.  The default is I<UDC>.

=item B<-w> I<waylay_url>

The URL to waylay people too when dealing with an unusual or complex
URL scheme, e.g. B<wais>.  See L<cgi-bin/waylay.pl> for more
information on this.

=back

These options are then followed by zero or more templates' handles
(note - B<not> filenames).  If the B<-a> option is given, no handles
need be given on the command line; all templates in the database will
be added to the subject listings.

=head1 FILES

I<config/class-map> - where to get default mappings from.

I<Subject-Descriptor-Scheme> attributes in templates
to filenames used for generating HTML.

I<config/subject-listing/*> - view files, each of which
describing a particular way of rendering the templates
into HTML.

I<config/multilingual/*/subject-listing-views/*> - HTML
rendering rules for B<addsl.pl> subject listing views, with
a separate directory per view.  The actual rendering rules
are as per search results.

I<guts/subject-listing/*.lst> - default location of the
internal files used to maintain state between runs of
subject listing tools.

I<htdocs/subject-listing> - default location of the HTML
generated by B<addsl.pl>

I<config/section-editors> - default location of the section
editors definition file.

=head1 FILE FORMATS

=over 4

=item Section Editors File

The section editors file provides information about the people who
maintain your subject sections. It is only necessary if you want to
display editor details on your subject listing pages. Each line should
contain the section editor's printable name, the filename of their
profile, and a list of all the subject section codes this edotor is
responsible for. All the fields should be colon separated. Here's an example:

  Editor One:editor1:anr:lsrd:digi

The printable name and the filename can be displayed by using the ROADS
HTML tags <SECTION-EDITOR> and <SECTION-EDITOR-PAGE>. See I<ROADS::HTMLOut>.

=item Subject Descriptor Mapping File

The subject descriptor mapping file specifies the code for a
particular subject section, the name given to that section in the HTML
documents and the root of the filename used to hold that section's
hypertext listing, each element being separated by a colon.  An
example line from a subject descriptor mapping file (for the UDC
subject descriptor scheme) is:

  30.442:Development Studies:devstud

Note that the section name should not contain the colon character ":"
- this would confuse B<addsl.pl>.

You can optionally add some more information to detail 'parent/child' and
'related' relationships between sections.

A section with a parent is denoted by an extra entry at the end of the line.
The entry is the subject-descriptor of the parent. e.g.:

  1:Philosophy:philos
  11:Metaphysics:metaphys:1
  14:Philosophical Systems:philsys:1

In this example the philosophy section has no parent, but is the parent 
of the two other sections. Child relationships are deduced by I<bin/addsl.pl>
from the defined parent relationships.

You can also list related sections by adding an optional fifth field to a 
class-map entry. This field is a semi-colon separated list of subject-descriptors.

  159.9:Psychology:psych::301.151;364.264;377.015.3

Note that the parent field and the related resource field are optional,
but if you include the latter you must include the former, even if empty as above.

To display this information in your listings, use the ROADS HTML tags <TREEPARENT>,
<TREECHILDREN> and <RELATED>. See I<ROADS::HTMLOut>.

=item Subject Listing Views

Each available HTML view of the templates is specified by a view file.
A sample file is:

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

=item I<Section-Editors-File>

The path to the section editors file.  If this is a relative
path, it is assumed to be relative to the ROADS I<config> directory.
Only necessary if you want to display editor information in your
subject-listings.

=item I<Subject-Scheme>

The name of the subject scheme that this view relates to.

=item I<WWW-Directory>

The WWW path to the directory in which the HTML generated by
B<addsl.pl> will appear.  This includes the I<AlphaList-File> and
I<NumList-File> listings.

=back

=head1 SEE ALSO

L<bin/addwn.pl>, L<bin/cullsl.pl>, L<bin/cullwn.pl>, L<bin/mkinv.pl>

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

=head1 Author

Jon Knight E<lt>jon@net.lut.ac.ukE<gt>,
Martin Hamilton E<lt>martinh@gnu.orgE<gt>

