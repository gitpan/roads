#!/usr/bin/perl
use lib "/home/roads2/lib";

# mktemp.pl
#
# Author: Jon Knight <jon@net.lut.ac.uk>
# $Id: mktemp.pl,v 3.25 1998/09/10 17:07:22 jon Exp $

use Getopt::Std;

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;
use ROADS::HTMLOut;
use ROADS::ReadTemplate;

require "$ROADS::Lib/mktemp-forms.pl";
require "$ROADS::Lib/mktemp-capture.pl";
require "$ROADS::Lib/mktemp-selectview.pl";
require "$ROADS::Lib/mktemp-size.pl";
require "$ROADS::Lib/mktemp-editform.pl";
require "$ROADS::Lib/mktemp-validedit.pl";
require "$ROADS::Lib/mktemp-lookupcluster.pl";
require "$ROADS::Lib/mktemp-authority.pl";

# Handle command line parameters.  These aren't used normally - consider them
# to be undocumented debugging aids for the developers.
getopts('C:L:m:o:s:t:u:v:w:');

# What language to return
$Language = $opt_L || "en-uk";

# What character set to use.
$CharSet = $opt_C || "ISO-8859-1";

# Where the template editing views live
$ViewDir = $opt_m || "$ROADS::Config/mktemp-views/";

# Where the template outlines live
$OutlineDir = $opt_o || "$ROADS::Config/outlines/";

# IAFA template source directory
$IafaSource = "$ROADS::IafaSource";
$opt_s && ($IafaSource = $opt_s);

# Inverted index directory
$IndexDir = "$ROADS::IndexDir";
$opt_t && ($IndexDir = $opt_t);

# The URL of this script
$myurl = $opt_u || "/$ROADS::WWWAdminCgi/mktemp.pl";

# Directory holding the Subject Listing views
$SubjectListingViews = $opt_v || "$ROADS::Config/subject-listing";

# Directory holding the Whats New views
$WhatsNewViews = $opt_w || "$ROADS::Config/whats-new";


##############################################################################
#
# Main code
#
##############################################################################

# Print out the HTTP Content-type header and then cleave the CGI URL into
# an associative array ready for use.
&cleaveargs;

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

print STDOUT "Content-type: text/html\n\n";

# Check to see if we're editing an existing template and if so, that we have
# a valid template Handle for the selected service
if ($CGIvar{mode} eq "edit") {
    &CheckUserAuth("mktemp");
    &CheckValidTemplate;
}

# If the templatetype CGI attribute isn't present then we must squirt out
# the introductory FORM for the user and then exit.
if ($CGIvar{templatetype} eq "") {
    &SendIntroForm;
    exit;
}

# Get a sanitized form of the Template-Type header
$tt = $CGIvar{templatetype};
$tt =~ y/A-Z/a-z/;

# If the user hasn't selected a view for the template, see if there is a
# file corresponding to the selected template type in the views directory.
# If there is, generate a form asking the user which view (s)he wishes to
# use.
if ($CGIvar{view} eq "") {
    &SelectEditingView;
}

# If the user has returned a FORM that tells use the sizes of the clusters
# required and the user is editing an existing template, we'd better spit
# out a FORM containing the current contents of the template (and any
# additional fields to be added).
if(($CGIvar{mode} eq "edit") && ($CGIvar{done} ne "yes") && 
  ($CGIvar{partdone} ne "true")){
    &WorkOutSize;
}

# Find out what fields view restrictions let us display (if there are
# any such restrictions in effect)
if (-f "$ViewDir/$tt") {
  open(VIEW,"$ViewDir/$tt");
  $line = <VIEW>;
  while(!eof(VIEW)) {
    chomp $line;
    ($attr,$value)=split(":",$line,2);
    if($attr ne "Template-Type") {
      foreach $viewname (split(":",$value)) {
        if($viewname eq $CGIvar{view}) {
          $_ = $attr;
          if(/\((.*)\)$/) {
            local($clusttype) = $1;
            local($clustviewname,$clustattr,$clustvalue);
            $clusttype =~ tr/A-Z/a-z/;
            $clusttype =~ s/\*//;
            if (-f "$ViewDir/$clusttype") {
              open(CLUSTVIEW,"$ViewDir/$clusttype");
              $attr =~ s/\(.*\)$//;
              $line = <CLUSTVIEW>;
              while(!eof(CLUSTVIEW)) {
                chomp $line;
                ($clustattr,$clustvalue)=split(":",$line,2);
                if($clustattr ne "Template-Type") {
                  foreach $clustviewname (split(":",$clustvalue)) {
                    if($clustviewname eq $CGIvar{view}) {
                      @viewattr=(@viewattr,"$attr$clustattr");
                    }
                  }
                }
                $line = <CLUSTVIEW>;
              }
              close(CLUSTVIEW);
            } else {
              local($clustname);
              $attr =~ /^([A-Za-z0-9\-]+)-\(/;
              $clustname = $1;
              @viewattr=(@viewattr,$clustname);
            }
          } else {
            @viewattr=(@viewattr,$attr);
          }
        }
      }
    }
    $line = <VIEW>;
  }
  close(VIEW);
} else {
  $CGIvar{view} = "ALL";
}


# If we haven't asked how number clusters and variants the user wants then
# we must do it now using another FORM (if the particular template type
# being created/edited doesn't have any clusters in it, then we can ignore
# this stage and just present them with the FORM ready to be filled in).
if ($CGIvar{asksize} eq "") {
    &sendsizeform;
    $CGIvar{asksize}="sizes";
}

# Check if the user pressed one of the cluster search submission buttons
#                           one of the authority file lookup buttons
#                           the add/delete cluster buttons
#                           the add/delete variant buttons
$lookupcluster="";
@insertcluster=();
$authoritylookup = $addvariant = $delvariant = $addcluster = $delcluster = "";
foreach $key (%CGIvar) {
    next if($CGIvar{$key} eq "");
    if($key =~ /^ROADSFind(.*)/) {
        $lookupcluster = $1;
        $partdone = 1;
        break;
    } elsif($key =~ /^ROADSAdd(.*)/) {
        push(@insertcluster,$1);
        break;
    } elsif($key =~ /^ROADSAuth(.*)/) {
        $authoritylookup = $1;
        $partdone = 1;
        break;
    } elsif($key eq "ROADSincrvarsize") {
        $addvariant = "yes";
        $partdone = 1;
        $CGIvar{"variantsize"}++;
        break;
    } elsif($key eq "ROADSdecrvarsize") {
        $delvariant = "yes";
        $partdone = 1;
        $CGIvar{"variantsize"}--;
	$CGIvar{"variantsize"} = 0
	    if $CGIvar{"variantsize"} < 0;
        break;
    } elsif($key =~ /^ROADScincr(.*)/) {
	$the_cluster = $1;
	$addcluster = "yes";
        $partdone = 1;
        $CGIvar{"cluster$the_cluster"}++;
        break;
    } elsif($key =~ /^ROADScdecr(.*)/) {
	$the_cluster = $1;
	$delcluster = "yes";
        $partdone = 1;
        $CGIvar{"cluster$the_cluster"}--;
	$CGIvar{"cluster$the_cluster"} = 0
	    if $CGIvar{"cluster$the_cluster"} < 0;
        break;
    }
}


# Right from here on in we know we've got a submission to either be echoed
# back to the user or added to a database.

# Check if the user wants to save the contents of the form to a file.  If
# so, try to open it.  We'll open a temporary file for templates that are
# to be returned as text to the user or emailed to the administrator.
if($CGIvar{done} eq "yes") {
    if (($CGIvar{op} eq "text") || ($CGIvar{op} eq "email")) {
        unlink("$ROADS::TmpDir/$Handle");
    }
    $Handle = $CGIvar{IAFAHandle};
    $Handle =~ s/[\x0A\x0D]*//;
    $Handle =~ s/\s*//g;
    $Handle = time . "-" . $$ if ($Handle eq "");
    $CGIvar{IAFAHandle} = $Handle;
    if(-e "$ROADS::IafaSource/$Handle" && ($CGIvar{mode} ne "edit" && 
      ($partdone != 1))) {
        &OutputHTML("mktemp", "handleexists.html",$Language,$CharSet);
        exit;
    } else {
        $FailedMandatoryTest = 0;
        @MissingMandatory = ();
        unless (open(NEWTEMP,">$ROADS::TmpDir/$Handle")) {
            &OutputHTML("mktemp", "failedcreation.html",$Language,$CharSet);
            &WriteToErrorLogAndDie("mktemp",
              "Can't create template file $ROADS::TmpDir/$Handle: $!");
        }
        print NEWTEMP "Template-Type:\t$CGIvar{templatetype}\n";
    }
}

# Open the appropriate template outline
if (!open(OUTLINE,"$OutlineDir/$tt")) {
    &OutputHTML("mktemp","notemplateoutline.html",$Language,$CharSet);
    &WriteToErrorLogAndDie("mktemp",
      "Can't open template outline $OutlineDir/$tt: $!");
}
<OUTLINE>;
while(/Template-type:/i) {
    <OUTLINE>;
}

# Do the cluster insertion(s) if necessary
if (defined(@insertcluster)) {
    my($noth,$notf,$its,$inscluster,$basename,$variantnumber,$this,$that);

    %ALLTEMPS = &readalltemps;
    foreach $inscluster (@insertcluster) {
	$its = $CGIvar{"ROADSAdd$inscluster"};
	if ($inscluster =~ /^([^\-]+)-(\d+)$/) {
	    $basename = $1;
	    $variantnumber = $2;
	}
	if (open(IN, "$ROADS::IafaSource/$ALLTEMPS{\"$its\"}")) {
	    while(<IN>) {
		chomp;
		next if /^(Handle|Template-Type):/i;
		next if /^Record-/i;
		if (/^([^:]+):\s+(.*)/) {
		    $this = $1;  $that = $2;
		    $CGIvar{"IAFA$basename$this$variantnumber"} = $that
			unless $CGIvar{"IAFA$basename$this$variantnumber"};
		}
	    }
	    close(IN);
	}
    }
}

$HavePlainFields = 0;
$HaveVariantFields = 0;
$HaveClusters = 0;
$MaxVariants = 1;
while(!eof(OUTLINE)) {
    $line = <OUTLINE>;
    chomp $line;
    next if(!($line =~ /:/));
    ($fieldname,$xsize,$ysize,$defaultvalue,$optional) = split(/:/,$line);
    if ($xsize eq "") {
        $xsize = 45;
    }
    if ($ysize eq "") {
        $ysize = 1;
    }
    &DoField($fieldname,"");
}
close(OUTLINE);

#
# Read in the permitted options to display to this trusted information
# providers from the config file.  The config file looks a bit like a
# Windows INI file and will (hopefullly) be generated by a web based 
# TIPS permissions editor (though of course being an ASCII file you can
# edit it by hand if you want to).
#
$user = $ENV{REMOTE_USER};
$user = $ENV{REMOTE_IDENT} if($user eq "");
$user = "unknown" if($user eq "");
$useremail = "$user\@$ENV{REMOTE_HOST}";

if(open(TIPSPERMS,"$ROADS::Config/mktemp.cfg")) {
  local($ApplyToThisUser,$userentry,$GenerateListing);
  local($GenerateWhatsNew,$ReturnTemplate,$EmailTemplate,$EnterTemplate);

  while(<TIPSPERMS>) {
    chomp;
    next if!(/^\[tipsperms\]/i);

    $ApplyToThisUser = 0;
    $GenerateListing = 0;
    $GenerateWhatsNew = 0;
    $ReturnTemplate = 0;
    $EmailTemplate = 0;
    $EnterTemplate = 0;
    $OfflineMode = 0;

    while(<TIPSPERMS>) {
      next if(/^#/);
      last if($_ eq "\n");
      chomp;
      if(/\s*UserList\s*=\s*(.*)/) {
        foreach $userentry (split(/[\s+,]/,$1)) {
          if($userentry =~ /(.*)\@(.*)/) {
            if($useremail eq $userentry) {
              $ApplyToThisUser = 1;
              last;
            }
          } else {
            if(($user eq $userentry) || ($userentry eq "*")) {
              $ApplyToThisUser = 1;
              last;
            }
          }
        }
      }
      if(/GenerateListing/i) {
        $GenerateListing = 1;
      }
      if(/GenerateWhatsNew/i) {
        $GenerateWhatsNew = 1;
      }
      if(/ReturnTemplate/i) {
        $ReturnTemplate = 1;
      }
      if(/EmailTemplate/i) {
        $EmailTemplate = 1;
      }
      if(/EnterTemplate/i) {
        $EnterTemplate = 1;
      }
      if(/OfflineMode/i) {
        $OfflineMode = 1;
      }
    }
    if($ApplyToThisUser) {
      undef(%Permitted);
      $Permitted{"GenerateListing"} = $GenerateListing;
      $Permitted{"GenerateWhatsNew"} = $GenerateWhatsNew;
      $Permitted{"ReturnTemplate"} = $ReturnTemplate;
      $Permitted{"EmailTemplate"} = $EmailTemplate;
      $Permitted{"EnterTemplate"} = $EnterTemplate;
      $Permitted{"OfflineMode"} = $OfflineMode;
    }
  }
}

#
# Output the header of the template editing FORM if we're not done.
#
if (($CGIvar{done} ne "yes") || ($addvariant eq "yes")
    || ($delvariant eq "yes") || ($addcluster eq "yes")
    || ($delcluster eq "yes")) {
    &editform;
} else {
    # Do the cluster lookup if necessary
    if($lookupcluster ne "") {
        unlink("$ROADS::TmpDir/$Handle");
        &LookupCluster($lookupcluster);
        exit;
    }

    # Do the authority lookup if necessary
    if($authoritylookup ne "") {
        unlink("$ROADS::TmpDir/$Handle");
        &AuthorityLookup($authoritylookup);
        exit;
    }

    # Check if any of the mandatory fields weren't filled in and generate
    # an error report if necessary.
    if($FailedMandatoryTest == 1) {
        &OutputHTML("mktemp","missingmandatory.html",$Language,$CharSet);
        close(NEWTEMP);
        unlink("$ROADS::TmpDir/$Handle");
        exit;
    }

    # We're writing out the end of a template so stick in the maintenance
    # attributes.
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdat) = gmtime();
    $day = (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];
    $year += 1900;
    $month = (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mon];
    $entrydate = sprintf ("%s, %2.2d %s %4.4d %2.2d:%2.2d:%2.2d +0000",
        ($day,$mday,$month,$year,$hour,$min,$sec));

    # For the creation email address, try the authenticated username first,
    # then an IDENTD lookup username and finally use a default.
    $user = $ENV{REMOTE_USER};
    $user = $ENV{REMOTE_IDENT} if($user eq "");
    $user = "unknown" if($user eq "");
    $useremail = "$user\@$ENV{REMOTE_HOST}";
    print NEWTEMP "Record-Last-Modified-Date: $entrydate\n";
    print NEWTEMP "Record-Last-Modified-Email: $useremail\n";
    if($CGIvar{mode} eq "edit") {
        print NEWTEMP "Record-Created-Date: $CGIvar{IAFARecordCreatedDate}\n";
        print NEWTEMP
	    "Record-Created-Email: $CGIvar{IAFARecordCreatedEmail}\n";
    } else {
        print NEWTEMP "Record-Created-Date: $entrydate\n";
        print NEWTEMP "Record-Created-Email: $useremail\n";
    }
    close NEWTEMP;

    # Template now saved in $ROADS::TmpDir/$Handle, hopefully :-)

    # Display the template on the user's browser as plaintext.
    if ($CGIvar{op} eq "text") {
	print STDOUT <<"EndOfHTML";
<HTML>
<HEAD>
<TITLE>Text Version of Template</TITLE>
</HEAD>
</BODY>
<H1>Text Version of Template</H1>
<PRE>
EndOfHTML
        open(NEWTEMP,"$ROADS::TmpDir/$Handle")
            || &WriteToErrorLogAndDie("mktemp",
                 "Can't read $ROADS::TmpDir/$Handle: $!");
        while (<NEWTEMP>) {
            print STDOUT;
        }
        close NEWTEMP;
        unlink("$ROADS:TmpDir/$Handle");
        print STDOUT "<\PRE>\n";
	exit;
    }

    # Send the template to the database administrator via email.
    if ($CGIvar{op} eq "email") {
        if (!open (MAIL, "| $ROADS::MailerPath $ROADS::DBAdminEmail")) {
            &OutputHTML("mktemp", "mailererror.html",$Language,$CharSet);
	    &WriteToErrorLog("mktemp", "Can't open a pipe to $MailerPath");
            exit 1;
	}
        print MAIL <<EOF;
Subject: Added new template $Handle

 =============================================================
 This Template was submitted through the IAFA Template Editor
 =============================================================
 REMOTE HOST:        $ENV{'REMOTE_HOST'}
 REMOTE ADDRESS:     $ENV{'REMOTE_ADDR'}
 HTTP_USER_AGENT:    $ENV{'HTTP_USER_AGENT'}
 =============================================================

EOF
	open(NEWTEMP,"$ROADS::TmpDir/$Handle");
        while (<NEWTEMP>) {
            print MAIL;
        }
        close NEWTEMP;
	unlink("$ROADS::TmpDir/$Handle");
	close MAIL;
        &OutputHTML("mktemp", "mailok.html",$Language,$CharSet);
	exit;
    }

    if ($CGIvar{op} eq "offline") {
	unless (-d "$ROADS::Guts/pending") {
	    mkdir("$ROADS::Guts/pending", 0755)
		|| &WriteToErrorLogAndDie("mktemp",
		     "Can't mkdir $ROADS::Guts/pending for offline edit: $!");
	    chmod 0755, "$ROADS::Guts/pending";
	}
	open(NEWTEMP,"$ROADS::TmpDir/$Handle")
	    || &WriteToErrorLogAndDie("mktemp",
                 "Can't read from $ROADS::TmpDir/$Handle: $!");
        open(PENDING,">$ROADS::Guts/pending/$Handle")
            || &WriteToErrorLogAndDie("mktemp",
                 "Can't write to $ROADS::Guts/pending/$Handle: $!");
        while (<NEWTEMP>) {
            print PENDING;
        }
        close PENDING;
	close NEWTEMP;
	unlink("$ROADS::TmpDir/$Handle");

	# Add a line to the end of the change log detailing the operation
	# performed and the date and user that performed it.
	open(CHANGELOG,">>$ROADS::Logs/ChangeLog");
	flock(CHANGELOG,2);
	if ($CGIvar{mode} eq "edit") {
	    print CHANGELOG
		"[$entrydate] UPDATED $Handle by $user (offline)\n";
	    &OutputHTML("mktemp", "offlineeditedok.html",$Language,$CharSet);
	} else {
	    print CHANGELOG
		"[$entrydate] NEW $Handle by $user (offline)\n";
	    &OutputHTML("mktemp", "offlineaddedok.html",$Language,$CharSet);
	}
	flock(CHANGELOG,8);
	close(CHANGELOG);

	exit;
    }

    # If we get this far, it's a live session...

    # Start up a lock to stop other mktemp.pl's sniffing about (and to
    # keep us out if there's already someone doing something).
    open(MKTEMPLOCK,">>$ROADS::Guts/mktemp.lock");
    flock(MKTEMPLOCK,2);

    # If this was a new template just being created, add it to the list
    # of template/filename mappings.
    if ($CGIvar{mode} eq "edit") {
	if ($ROADS::ExtDBDel ne "") {
	    $ENV{"HANDLE"} = $Handle;
	    $ENV{"IAFAFILE"} = "$IafaSource/$Handle";
	    $res=system("$ROADS::ExtDBDel");
	} else {
	    $res=system("$ROADS::Bin/deindex.pl", "-s", $IafaSource,
			"-i", $IndexDir, $Handle);
	}
	if ($res != 0) {
	    &OutputHTML("mktemp", "cannotdeindex.html",$Language,$CharSet);
	    flock(MKTEMPLOCK,8);
	    close(MKTEMPLOCK);
	    unlink("$ROADS::Guts/mktemp.lock");
	    &WriteToErrorLog("mktemp", "Cannot deindex $Handle");
	    exit 1;
	}
    }
    
    $Handle =~ s/[\r\n]*$//;
    $res=system("$ROADS::MvPath", "$ROADS::TmpDir/$Handle",
		"$IafaSource/$Handle");
    if ($res != 0) {
	&OutputHTML("mktemp", "cannotreplace.html",$Language,$CharSet);
	flock(MKTEMPLOCK,8);
	close(MKTEMPLOCK);
	unlink("$ROADS::Guts/mktemp.lock");
	&WriteToErrorLog("mktemp", "Cannot replace $Handle");
	exit 1;
    }
    
    if ($ROADS::ExtDBAdd ne "") {
	$ENV{"HANDLE"} = $Handle;
	$ENV{"IAFAFILE"} = "$IafaSource/$Handle";
	$res=system("$ROADS::ExtDBAdd");
    } else {
	$res=system("$ROADS::Bin/mkinv.pl", "$Handle");
    }
    if ($res != 0) {
	&OutputHTML("mktemp", "cannotindex.html",$Language,$CharSet);
	flock(MKTEMPLOCK,8);
	close(MKTEMPLOCK);
	unlink("$ROADS::Guts/mktemp.lock");
	&WriteToErrorLog("mktemp", "Cannot index $Handle");    
	exit 1;    
    }
    
    # Add the template to subject lists if required
    if ($CGIvar{slinsert} eq "yes") {
	$res=system("$ROADS::Bin/addsl.pl", "-s", $IafaSource,
		    "-n", $ROADS::ServiceName, "-l", $CGIvar{slview},
		    $Handle);
    }
    
    # Add the template to the what's new list if required
    if ($CGIvar{wninsert} eq "yes") {
	$res=system("$ROADS::Bin/addwn.pl", "-s", $IafaSource,
		    "-n", $ROADS::ServiceName, ,"-w", $CGIvar{wnview},
		    "-r", $Handle);
    }
    
    # Add the user to the user list if appropriate
    if ($CGIvar{AddAuth} ne "") {
	$res = system("$ROADS::Bin/templateadmin.pl", "-h", $Handle,
		      "-o", "ADD", "-u", $CGIvar{AddAuth});
    }
    
    # Add a line to the end of the change log detailing the operation
    # performed and the date and user that performed it.
    open(CHANGELOG,">>$ROADS::Logs/ChangeLog");
    flock(CHANGELOG,2);
    if ($CGIvar{mode} eq "edit") {
	print CHANGELOG "[$entrydate] UPDATED $Handle by $user\n";
    } else {
	print CHANGELOG "[$entrydate] NEW $Handle by $user\n";
    }
    flock(CHANGELOG,8);
    close(CHANGELOG);
    
    # Close the lock on other mktemp.pl's
    flock(MKTEMPLOCK,8);
    close(MKTEMPLOCK);
    
    # Tell the user that the template was added to the database ok.
    if ($CGIvar{mode} eq "edit") {
	&OutputHTML("mktemp", "editedok.html",$Language,$CharSet);
    } else {
	&OutputHTML("mktemp", "addedok.html",$Language,$CharSet);
    }
}
exit;

#
# Subroutine to write out an IAFA template field correctly
#
sub WriteField {
    local($Fieldname,$Fieldvalue) = @_;

    $Fieldvalue =~ s/\n/ /g;
    $Fieldname = "$Fieldname:\t";
    write(NEWTEMP);
}

format NEWTEMP=
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<^<<<<<<<<<<
$Fieldname,                                                    $Fieldvalue
~~^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
 $Fieldvalue
.

exit;
__END__


=head1 NAME

B<admin-cgi/mktemp.pl> - WWW based template editor

=head1 SYNOPSIS

  admin-cgi/mktemp.pl [-C charset] [-L language]
    [-m views_dir] [-o outline_dir] [-s source_dir]
    [-t index_dir] [-u url] [-v subject_view]
    [-w whats_new_view]

=head1 DESCRIPTION

The B<mktemp.pl> program is a Common Gateway Interface (CGI) compliant
program run from an HTTP daemon.  It allows a user sitting at a forms
capable World Wide Web (WWW) browser to generate an Internet Anonymous
FTP Archive (IAFA) template and then either have a text version of the
template returned to the browser, have a text version emailed to a
database administrator, actually enter the template into a database,
or have the template saved in a holding area pending later processing.

In the case that the template is entered directly into the ROADS
database it will be immediately available for searching via the
B<search.pl> program.  The user will also be given the option of
adding it to a subject listing and whats new file.

To allow the indexing and addition to the subject lists and whats new
files to take place, the B<mktemp.pl> program must have access to the
B<deindex.pl>, B<mkinv.pl>, B<addsl.pl>, B<addwn.pl> scripts in the
ROADS B<bin> directory.

=head1 USAGE

You can either create resource description templates by hand using your
favourite text editor (e.g. GNU Emacs), or via the World-Wide Web
based template editor distributed with the ROADS software.  Note that
in order to use this feature your browser must support HTML forms.

If your server's Internet domain name was I<bork.swedish-chef.org>,
your World-Wide Web server was running on port 80 (the default)
and you installed ROADS using the default paths, the
template editor would be found at:

  http://bork.swedish-chef.org/ROADS/admin-cgi/mktemp.pl

Most of the ROADS tools which manipulate templates will let you
specify the directory in which the templates are held.  The template
editor is a notable exception, and we will probably remedy this in a
later version of the software.

We suggest that you use the IAFA template schema shipped with the ROADS
software as a starting point.  If you find that you need to change the
templates, e.g. to add a new attribute or describe a new type of
resource, we suggest that you discuss the changes you have in mind with
other ROADS users on the I<open-roads@net.lut.ac.uk> mailing list.  By
doing this we may be able to avoid ending up with different attributes
(or templates!) which describe the same things.

If you use the WWW interface to create your templates, you will be
given the option of specifying your own I<handle> for each
template you create, or letting the editor come up with a handle on
your behalf.  The handle is the name of the template as used
internally by the ROADS software - it corresponds to the field in each
template which begins with:

  Handle:

If you let the software generate a handle for you automatically, this
will be based on the time the template was created.  As a result, the
handle can be quite long, and has no semantics associated with it.
For example:

  814010256-14355

The automatically generated handles are almost certain to be unique,
which is very important.  If you choose to use your own handles rather
than the ones produced by the software, you should be careful to check
that there is only one template with a given handle.  It's generally
a good idea to make the value of the I<Handle> attribute the same as
the filename which the template is saved as.

Within the WWW template editor, you may be asked what I<view>
of the template you wish to see.  This is discussed in detail below.
In the first instance at least you are likely to only have one view of
each template - all the fields it contains and their values (if any),
in which case you will not be queried as to your preferred view.  If
you often find yourself editing large templates, it will probably be
desirable to construct views containing just those attributes which
you supply values for on a regular basis.

Many templates allow you to specify multiple instances of particular
attributes which are I<clustered> together, e.g. the information
about the author of a document may be repeated if the document has
multiple authors.  In addition to clusters of attributes, some
individual attributes may be repeated more than once - these are
referred to as I<variants>.  If you have elected to create a
template which contains clusters or variants, you will be asked to
choose how many of these should be present.  Hopefully this will be
self-evident - e.g. a document with two authors should have two
I<Author> clusters.

If you make a mistake, such as not asking for two author clusters, you
can easily rectify this later on by editing the template.

The template to be created is rendered as a page of HTML with a
type-in box for each attribute in the template - or in the view of it
which you have chosen.  For the default templates distributed with the
ROADS software, each attribute's name will be a hyperlink to on-line
help.  You may find that the type-in boxes are the wrong size, or want
to constrain the possible choices for a particular attribute to a
controlled vocabulary - if so, read the sections below on customising
the editor.

Having entered values in the type-in boxes for all the attributes you
would like to appear in the template, you should choose whether the
template should simply be formed and returned as a Web document, sent
via email to the ROADS server administrator, or entered into the ROADS
server's database.  You can also opt to have it entered into a list of
resource descriptors broken down by subject category, and/or a 
B<What's New> list of recent additions to the server.  See below for
more information on these.

The HTML documents which constitute each of these lists may be
customized by the ROADS server administrator.  Consequently, you will
be asked which customised I<view> you would like to use in
constructing or reconstructing the lists.  This is discussed in detail
below.

If you do decide to create your templates by hand, note that each
template must include the B<Template-Type> and B<Handle>
attributes, and that the type of the template should correspond to one
of the outline templates - see below.  Note that in order to use many
of the ROADS tools with your templates, it will be neccessary for the
attributes in the template to match the template outline definitions
discussed below.

You can edit an existing template either by hand, or via a World-Wide
Web form.  If you know the template's I<handle> already, you can
edit it directly using the WWW based template editor - just type the
template's handle into the text entry box at the bottom of the
starting page.

If you don't know the template's handle already, there is a variant of
the ROADS search tool which is intended for administrative use.
Following the example above, the URL for this would be:

  http://bork.swedish-chef.org/ROADS/admin-cgi/admin.pl

I<admin.pl> is documented separately in its own manual page.

Alternatively, if you just want to see the template rendered into
HTML, or make a hyperlink to it from somewhere else, the
I<tempbyhand.pl> tool may be used to do this.

=head1 SCHEMA DEFINITIONS

The ROADS software attaches virtually no semantics to the contents of
the templates - doing so would require it to know (for instance) that
a B<Description> box should be larger than a B<title>
box, since it usually contains more text, and so on.  We have tried to
avoid this wherever possible, instead leaving these decisions up to
the ROADS server administrator.

The mechanism we have chosen to use for this is what we call an
I<outline> file.  Outline files specify important information
about each type of template the software knows about, and an outline
file must be present for any new types of template, i.e. any templates
which were introduced locally and not provided with the ROADS software
distribution.

Outline files for the following template types are distributed with
the ROADS software.  Hopefully the titles are self-descriptive:

=over 4

=item DESCRIPTOR

for cataloguing information such as UDC, MeSH or LC SH.  Not used in its
own right, but included in templates of other types

=item DOCUMENT

e.g. a book or technical report

=item FAQ

a Frequently Asked Questions document

=item IMAGE

e.g. a GIF or JPEG image

=item MAILARCHIVE

the location of a mailing list archive

=item ORGANIZATION

information about an organization

=item PROJECT

information about a project

=item SERVICE

information about an on-line service

=item SOFTWARE

information about a software package, e.g. ROADS

=item SOUND

e.g. an AIFF or WAV object

=item TRAINMAT

information about training materials

=item USENET

information about a Usenet News conference

=item USER

information about a person

=item VIDEO

e.g. an MPEG or QuickTime object

=back

These can be found in the I<config/outlines> subdirectory of
whatever directory you unpacked the ROADS software distribution in.

An individual outline file contains, for the template it describes:

=over 4

=item *

What attributes, or clusters of attributes, it contains.  All the
attributes in another type of template may be I<imported> by
putting its name in brackets after a disambiguating attribute, e.g.

  Author-(USER*):

says to import the attributes in the B<USER> template, and
prefix them with B<Author->.  The star sign (B<*>)
indicates that the cluster may appear more than once.  Each instance
of the incorporated cluster should be tagged with a B<-v> and a
sequence number, e.g.

  Author-Name-v1: Martin Hamilton
  Author-Name-v2: Jon Knight

The reasoning behind this is discussed further in the IAFA template
specification.

=item *

What variant attributes it contains.  These are attributes which
may occur more than once, but are not part of another cluster, e.g.

  ISBN-v*::::o:

This indicates that the B<ISBN> attribute may appear a number
of times.  Each instance of it should be tagged with a sequence
number, e.g.

  Language-v1: English
  Language-v2: Swedish

=item *

How big the editor's type-in boxes should be for each attribute.
If not specified for a particular attribute, the default is for each
type-in box to be a single line, 25 characters long.  For example,

  Description:25:5:

indicates that a type-in box 25 characters wide and 5 lines deep
should be used for the I<Description> attribute.

=item *

A set of default values for the attribute.  If these are present,
they will be presented to the user in the form of a list of choices,
and the user will not be able to enter arbitrary text for the value of
this attribute.  This can be used to enforce a rudimentary controlled
vocabulary, e.g.

  Format-v*:::Plain text|PostScript|HTML|DVI:o:

Indicates that the editor should render the value of the variant
attribute B<Format-> in the form of a list:

=over 4

=item Plain text

=item PostScript

=item HTML

=item DVI

=back

=item *

Whether or not the attribute is mandatory.  Mandatory attributes
must be supplied, or the editor will refuse to create the template!
For example,

  Alternative-Title::::o:

indicates that the B<Alternative-Title> attribute is optional,
and may be omitted from the template.  it will be assumed that the
attribute is optional if no I<m> (for mandatory) appears in the
outline.

=back

The B<DOCUMENT> template distributed with the ROADS software
has some sample settings for these outline options, to illustrate the
sort of thing which may be accomplished.

=head1 AUTHORITY FILES

A more powerful mechanism for using authority lists is additionally
available.  This lets you conveniently include long lists of
alternative values for an attribute in a particular type of template,
which would be painful to do in the template outline.

To create an authority list for a particular attribute of a particular
template type, e.g. the B<Keywords> attribute of the 
B<DOCUMENT> template, simply place the words in the authority list
in the file I<config/authority/document/Keywords>.  Note that we
supply this example with the sample configuration that comes with the
ROADS software - you may need to create additional directories under
I<config/authority> for other types of template.

The authority file is formatted on a line by line basis, with each
line a separate authority term or terms, e.g.

  Glastonbury
  Phoenix
  Reading

=head1 ACCESS CONTROL LISTS

If you use HTTP user authentication to control access to your
administrative programs, which we strongly recommend, the
authenticated user name is available to the ROADS tools for access
control purposes.  This makes it possible for us to determine whether
a particular user should be allowed to modify a particular template.

Access control on an individual template may be enabled by checking
the box labelled ``Add me to the user authentication list for this
template'' (in the default English message set for the template
editor) whilst editing the template.  We also provide an additional
tool I<templateadmin.pl> for editing the access control list for a
given template.

=head1 TEMPLATE VIEWS

It is important to note that the template editor can be configured to
display only those attributes of the templates which you are interested
in seeing.  This can be a very useful feature when the template you are
editing has a large number of attributes.

In fact, you can specify multiple I<views> of a template.  This
is intended to make life easier for people who look after templates,
by letting them have ``quick views'' which just display those attributes
which are used most often, and ``detailed views'' which display most or
all of the attributes in a template.

ROADS is shipped with a I<Common Elements> view for each template type,
to demonstrate how this feature works in practice.  When editing an
existing template or creating a new one, you will be prompted as to
whether you want the I<Common Elements> view, or would prefer to see all
the fields in the template.  The full view of the template is always
available, and any information which is in the full view will continue to
appear in the template after you have edited it using another view such
as I<Common Elements>.

The views which are available for a particular type of template can
be found in the directory I<config/mktemp-views>, in the
place where you unpacked the ROADS software.  There will be a file
for each type of template which has multiple views defined.  Any
template which does not have multiple views defined will only be
available as a full view.  In a future version of the software we will
probably provide a facility to create and maintain editor views via a
WWW form, but in the meantime you will need to use a text editor.

To create a view of the I<SERVICE> template called
I<Highlights>, one would first copy its I<outline> from
the the directory I<config/outlines>, e.g.

  % cp config/outlines/service config/mktemp-views

Having done this, for each line in the B<copy> of the outline
file in the I<config/mktemp-views> directory, you should replace
everything after the colon (B<:>) with the names of the views
in which you would like it to appear, e.g.

Before:

  Requirements:

After:

  Requirements:Highlights:

You can specify multiple views, separated by colons, if you would like
an attribute to appear in multiple views.  By default it will always
appear in the B<ALL> view, which is generated automatically by
the ROADS software itself.

=head1 ALTERNATE BACKENDS

We have tried to keep the template editor design sufficiently open
that it can be used as a front end to other databases.  This has been
done by giving it the capability to run an external program instead
of the normal database update process.

The I<mktemp.pl> manual page describes the template editor's back
end interface in detail, but it is important to note that your
replacement back end code must be able to process the IAFA template
format, as generated by the template editor.  This is because IAFA is
used as an interchange format between the template editor and any
external code you may develop as a template editor back end.

=head1 OPTIONS

=over 4

=item B<-C> I<charset>

The character set to use.

=item B<-L> I<language>

The language to use.

=item B<-m> I<views_dir>

The directory to look in for alternative template editor views of the
data being edited.

=item B<-o> I<outline_dir>

The directory to look in for template outlines, i.e. schema
definitions.

=item B<-s> I<source_dir>

The directory to look in for templates themselves.

=item B<-t> I<index_dir>

The directory to look in for the ROADS index.

=item B<-u> I<url>

The URL of the template editor program itself.

=item B<-v> I<subject_view>

The directory to look in for alternative subject listing views for the
B<addsl.pl> program.

=item B<-w> I<whats_new_view>

The directory to look in for alternative "What's New" listing views
for the B<addwn.pl> program.

=back

=head1 CGI VARIABLES

=over 4

=item B<asksize>

Set to "done" once the user has been asked if they want to change the
number of clusters and variants displayed in the main template editing
form.  Setting this variable before calling the template editor will
cause this stage to be skipped.

=item B<charset>

The character set to use.

=item B<cluster>I<clustername>

The number of clusters of type I<clustername> included in the
template.

=item B<done>

Boolean variable set when the template editing is complete.

=item B<IAFA>I<fieldname>

A field from the template - e.g. the I<Handle> field would be
represented as I<IAFAHandle>.

=item B<language>

The language to use.

=item B<mode>

The editing mode for the template editor - normally either I<create>
(when creating a new template from scratch) or I<edit> (when editing
an existing template).

=item B<originalhandle>

When editing an existing template, the handle of the template.

=item B<op>

The operation to carry out when the template editing form is
submitted.  Normally this is set to one of :-

  email - email template to ROADS database administrator
  enter - enter template into ROADS database and update any
    subject/what's new listings
  offline - store template for later indexing
  text - return text of template on screen

=item B<slinsert>

Boolean variable indicating whether or not to include this template in
a subject listing.

=item B<templatetype>

The template type being edited, e.g. I<DOCUMENT>.

=item B<variantsize>

The number of variant records in the template being edited.

=item B<view>

The template editor view to use - this governs which template
attributes are shown to the end user by the template editor on its
main screen.  If this variable is set when the template editor is
called, the WWW form requesting the user to select a view will be
skipped.

=item B<wninsert>

Boolean variable indicating whether or not to include this template in
a "What's New" view.

=back

=head1 FILES

I<config/mktemp.cfg> - template editor config, see
L<mktemp-config-editor.pl>.

I<config/mktemp-views> - template editor views directory.

I<config/multilingual/*/mktemp/authlookupform.html>
- end of authority file lookup form.

I<config/multilingual/*/mktemp/authlookuphead.html>
- beginning of authority file lookup form.

I<config/multilingual/*/mktemp/editformtail.html>
- end of main editing form.

I<config/multilingual/*/mktemp/editformhead.html>
- beginning of main editing form.

I<config/multilingual/*/mktemp/cannotdeindex.html>
- HTML returned when existing template being edited
couldn't be deindexed.

I<config/multilingual/*/mktemp/cannotindex.html>
- HTML returned when template cannot be indexed.

I<config/multilingual/*/mktemp/cannotreplace.html>
- HTML returned when an existing template cannot be
replaced with a new version.

I<config/multilingual/*/mktemp/clusterhead.html>
- beginning of the add cluster/variant form displayed
when editing an existing template.

I<config/multilingual/*/mktemp/clusteronlybottom.html>
- end of the add cluster/variant form returned when
the template has no variants.

I<config/multilingual/*/mktemp/clustervariantsize.html>
- end of the add cluster/variant form returned when
the template has both clusters and variants.

I<config/multilingual/*/mktemp/failedcreation.html>
- HTML returned when the temporary copy of an existing
template being edited could not be created.

I<config/multilingual/*/mktemp/handleexists.html>
- HTML returned when an attempt has been made to create
a new template with the same handle as an existing one.

I<config/multilingual/*/mktemp/introform.html>
- initial HTML form returned when starting up B<mktemp.pl>
for the first time without specifying any of its CGI
parameters.

I<config/multilingual/*/mktemp/lookupclusterform.html>
- end of form returned when doing a cluster search.

I<config/multilingual/*/mktemp/lookupclusterhead.html>
- beginning of form returned when doing a cluster search.

I<config/multilingual/*/mktemp/mailererror.html>
- HTML returned when B<mktemp.pl> could not email the
template to the ROADS database admin contact.

I<config/multilingual/*/mktemp/missingmandatory.html>
- HTML returned when mandatory fields are missing from
the submitted template.

I<config/multilingual/*/mktemp/nonexistant.html>
- HTML returned when the user tried to edit a template
which didn't exist in the ROADS database.

I<config/multilingual/*/mktemp/notemplateoutline.html>
- HTML returned when the template type being edited has
no outline (schema).

I<config/multilingual/*/mktemp/notemplates.html>
- HTML returned when B<mktemp.pl> couldn't find its
list of the template types supported on the installation.

I<config/multilingual/*/mktemp/offlineaddedok.html>
- HTML returned when an offline template creation was
successful.

I<config/multilingual/*/mktemp/offlineeditedok.html>
- HTML returned when an offline template update was
successful.

I<config/multilingual/*/mktemp/selectview.html>
- form used to select from available template editor
views.

I<config/multilingual/*/mktemp/variantsizeonly.html>
- form returned when editing an existing template which
has variants but no clusters.

I<config/outlines> - outline (schema) definitions for the
supported template types.

I<guts/alltemps> - list of template handle to filename
mappings.

I<source> - directory where the templates may be found.

=head1 FILE FORMATS

=head2 EDITING VIEWS

A template editor view consists of a file named after the template,
e.g. I<user> for the B<USER> template.  The first line of this file
must consist of the string "Template-Type: " followed by the template
type itself.  The other lines of this file list attributes and the
views which are available of them, separated by colons, e.g.

  Template-Type: USER
  Handle:
  Name:Quick Edit:Martin
  Work-Phone:
  Work-Fax:
  Work-Postal:
  Job-Title:Quick Edit:Martin
  Department:Martin
  Email:Quick Edit:Martin
  Home-Phone:
  Home-Postal:
  Home-Fax:

This configuration defines two views - I<Quick Edit> and
I<Martin> of the the B<USER> template, in addition to the built-in
default view I<ALL>, which shows all fields.  Note that the
I<Department> attribute only appears in the I<Martin> view.

If the attribute is a cluster (such as a B<USER> or B<ORGANIZATION>
cluster embedded in a DOCUMENT template) there are two options for
specifying views.  The first is to use an attribute name of the form:

  AttributeName-(ClusterName*):

where B<AttributeName> is the base part of the cluster attribute name
and B<ClusterName> is the template type of the cluster.  For example:

  Author-(USER*):

In this case the views for all the elements in the cluster are inherited
from the view of the cluster's template type.  This allows you to set up
standard views for clusters that can appear in all templates and also
means that only the cluster's template type's views need to be changed
to affect the views of all template types that include that cluster.

The second way of defining views for elements of a cluster is to do so
on an attribute by attribute basis.  To do this specify just the
attribute name (without the trailing "-v*") in the view file for the
template type that the cluster appears in.  For example consider the
B<Author-(USER*)> cluster in the B<DOCUMENT> template type.  To specify that
Name attribute of the B<USER> cluster should appear in the "Quick Edit"
view, use the line:

  Author-Name:Quick Edit:

in the B<DOCUMENT> template type's view.  This permits different
templates to include different views of the same clusters.

=head2 OUTLINE FILES

Each outline file consists of a first line of the form

  Template-Type: DOCUMENT

which describes the template type being represented in the outline.
There then follows a list of the allowable attributes, one per line,
in the following format:

  Attribute-Name:x-size:y-size:default:status:

The B<Attribute-Name> is the name of the field in the template and
also specifies the field type (either plain, variant or clustered).
For plain fields, this is just the field name.  For a variant field,
the field name has B<-v*> appended to it.  For a cluster, it has
B<(CLUSTER_TYPE*)> appended, where B<CLUSTER_TYPE> is the template
type of the embedded cluster.  The B<x-size> and B<y-size> are
optional and if present specify the size of the text editing area used
for that attribute in the HTML editing form.  The default size is 40
characters long by one character high.

The B<defaults> field is text automatically placed loaded into the
editing form.  If the B<defaults> does not contain any vertical bar
("|") characters, it is loaded into the text edit box of new templates
by the B<mktemp.pl> script.  The vertical bar characters can be used
to separate a number of options which will be presented as drop down
selections in the editor form.  This latter form allows a small
controlled vocabulary to be used in some fields in the template.

The B<status> field tells the B<mktemp.pl> program whether or not it
is mandatory that the field contains some text once the filled in
template is submitted.  If the character B<m> appears in this field,
it is considered to be mandatory and any templates submitted without
such fields completed will generate an error.

=head2 DATABASES

The ROADS software can split templates in the same installation up
into "virtual" databases, using their B<Destination> attribute.  You
may wish to use the defaults feature in the template editor outlines
to restrict the available choices for later processing.

The B<mktemp.pl> program can make use of backend database technologies
other than the simple file system based index supplied in the ROADS
distribution.  It does this by making use of two external database
Application Programming Interfaces (APIs).  The first of these is used
to add a template to an external database and the other deletes a
template from an external database.  The API for both of these
operations are basically the same; two environment variables are used
to pass the handle of the template and the location of the source IAFA
template to an external program.  These environment variables are
called B<HANDLE> and B<IAFAFILE> respectively.  The external programs
for adding and deleting templates from a third party external database
should return zero on a successful completion and a non-zero value if
they failed for some reason.

The names of the two external programs are held in the Perl variables
B<\$ROADS::ExtDBAdd> and B<\$ROADS::ExtDBDel>.  The values for these can
be placed in the B<ROADS.pm> file in the B<lib> directory of the ROADS
installation.

=head1 SEE ALSO

L<bin/addsl.pl>, L<bin/addwn.pl>, L<admin-cgi/admin.pl>, L<search.pl>
L<bin/deindex.pl>, L<admin-cgi/deindex.pl>, L<bin/mkinv.pl>,
L<admin-cgi/mkinv.pl>

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


