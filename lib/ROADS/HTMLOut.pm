#
# ROADS::HTMLOut - Generalized HTML output routines.
#
# Authors: Jon Knight <jon@net.lut.ac.uk>
#          Martin Hamilton <>martinh@gnu.org>
# $Id: HTMLOut.pm,v 3.31 1999/07/29 14:40:39 martin Exp $
#

package ROADS::HTMLOut;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(GetMessageDir OutputHTML InitLookup InitLang
  TemplateTypeSelection EditorViewSelection SubjectListingSelection
  WhatsNewSelection ListMissingMandatory SelectDatabases LangFileExists
  GenericSubs);

use ROADS::DatabaseNames;
use ROADS::ErrorLogging;
use ROADS::CGIvars;

sub GetMessageDir {
    my($program,$view,$language,$charset) = @_;
    my($htmlfile,$quality,$lpair,$lcode,$lqual);

    $debug = $::debug || 0;

    print "[<EM>GetMessageDir called with program: $program, view: $view, "
      . "language: $language, charset: $charset</EM>]<BR>\n" if($debug);

    # Initialise the language mappings if we haven't already done so.
    &InitLang unless (defined($Language) && defined($CharSet));
    &InitLookup unless defined %LanguageLookup;

    $language = $Language unless defined($language);
    $charset = $CharSet unless defined($charset);

    $language =~ tr/[A-Z]/[a-z]/;
    $charset =~ tr/[A-Z]/[a-z]/;
    $lqual = 1.0;
    $quality = 0;
    foreach $lpair (split(",",$language)) {
        $lpair=~s/\s//g;
        ($lcode,$lqual)=split(";",$lpair);
        $lqual=~s/^q=//;
        next if($lqual < $quality);
        $quality = $lqual;
        $htmlfile = $LanguageLookup{"$lcode-$charset"} ||
            $LanguageLookup{"$::Language-$::CharSet"};
    }
    if (-d "$htmlfile/$program/$view") {
        $htmlfile .= "/$program/$view";
    } elsif (-d "${ROADS::Config}/$htmlfile/$program/$view") {
        $htmlfile = "${ROADS::Config}/$htmlfile/$program/$view";
    } elsif (-d "${ROADS::Config}/$program/$view") {
        $htmlfile = "${ROADS::Config}/$program/$view";
    } elsif (-d "${ROADS::Config}/multilingual/UK-English/$program/$view") {
        $htmlfile = "${ROADS::Config}/multilingual/UK-English/$program/$view";
    } else {
        $htmlfile = "/nada";
    }

    return $htmlfile;
}

sub OutputHTML {
    my($program,$file,$language,$charset) = @_;
    my($htmlfile,$quality,$lpair,$lcode,$lqual);

    $debug = $::debug || 0;

    print "[<EM>OutputHTML called with program: $program, file: $file, "
      . "language: $language, charset: $charset</EM>]<BR>\n" if($debug);

    # Initialise the language mappings if we haven't already done so.
    &InitLang unless (defined($Language) && defined($CharSet));
    &InitLookup unless defined %LanguageLookup;

    $language = $Language unless defined($language);
    $charset = $CharSet unless defined($charset);

    $language =~ tr/[A-Z]/[a-z]/;
    $charset =~ tr/[A-Z]/[a-z]/;
    $lqual = 1.0;
    $quality = 0;
    foreach $lpair (split(",",$language)) {
        $lpair=~s/\s//g;
        ($lcode,$lqual)=split(";",$lpair);
        $lqual=~s/^q=//;
        next if($lqual < $quality);
        $quality = $lqual;
        $htmlfile = $LanguageLookup{"$lcode-$charset"} ||
            $LanguageLookup{"$Language-$CharSet"};
    }

    if (-f "$htmlfile/$program/$file") {
        $htmlfile .= "/$program/$file";
    } elsif (-f "${ROADS::Config}/$htmlfile/$program/$file") {
        $htmlfile = "${ROADS::Config}/$htmlfile/$program/$file";
    } elsif (-f "${ROADS::Config}/$program/$file") {
        $htmlfile = "${ROADS::Config}/$program/$file";
    } elsif (-f "${ROADS::Config}/multilingual/UK-English/$program/$file") {
        $htmlfile = "${ROADS::Config}/multilingual/UK-English/$program/$file";
    } else {
        $htmlfile = "/nada";
    }

    print "[<EM>Opening HTML file '$htmlfile'.</EM>]<BR>\n" if($debug);

    if(($htmlfile eq "") || (!open(HTMLFILE,$htmlfile))) {
        print <<"EndOfHTML";
<HTML>
<HEAD>
<TITLE>Internal Error</TITLE>
</HEAD>
<BODY>
<H1>Internal Error</H1>

<P>
The <I>ROADS</I> software's multi-lingual output subsystem
encountered an error: the file "$file" for the program "$program" was
not available in the requested language ($language) and character set
($charset).  You should inform the <A
HREF="mailto:$ROADS::SysAdminEmail">technical support for this
service</A> of this problem so that they can correct it. 
</P>
</BODY>
</HTML>
EndOfHTML
        &WriteToErrorLog($program,
		       "HTML Output Error: no file for $file in $language");
        return;
    }

    #### should be returning Content-language and Content- ####
    #### charset here! ####

    local($newtext,$temp);
    while(<HTMLFILE>) {
        print &GenericSubs($_);
    }
    close(HTMLFILE);
}

sub InitLookup {
     my($code,$charset,$filename);

     open(LANGS,"$ROADS::Config/languages") || return;
     while(<LANGS>) {
         chomp;
         ($code,$charset,$filename) = split;
         $code =~ tr/A-Z/a-z/;
         $charset =~ tr/A-Z/a-z/;
         $LanguageLookup{"$code-$charset"} = $filename;
     }
     close(LANGS);
}

#
# Set global variables used in language/charset selection
#
sub InitLang {

#### the HTTP "ACCEPT" header processing is broken! ####
#### needs to take into account the quality rating  ####

    # What language to return
    $Language = $::opt_L || $ENV{"HTTP_ACCEPT_LANGUAGE"} ?
	$ENV{"HTTP_ACCEPT_LANGUAGE"} : $CGIvar{language} || "en";

    # What character set to use.
    $CharSet = $::opt_C || $ENV{"HTTP_ACCEPT_CHARSET"} ?
	$ENV{"HTTP_ACCEPT_CHARSET"} : $CGIvar{charset} || "iso-8859-1";

    print "[<EM>InitLang set language: $Language, charset: $CharSet</EM>]<BR>\n" if($debug);
}

sub TemplateTypeSelection {
    my($allowall) = @_;
    my($OutlineDir,$outline,$selected,@alloutlines,$htmloutput);

    $OutlineDir = $::OutlineDir;
    $OutlineDir = "$ROADS::Config/outlines" unless $OutlineDir;
    opendir(OUTLINE,"$OutlineDir") || return("");
    @alloutlines = sort readdir(OUTLINE);
    close(OUTLINE);

    $htmloutput = "<SELECT NAME=\"templatetype\">\n";
    if ($allowall eq 1) {
        $htmloutput .= "<OPTION SELECTED>ALL\n";
        $selected = "";
    } else {
        $selected = " SELECTED";
    }

    foreach $outline (@alloutlines) {
        next if $outline eq ".";
        next if $outline eq "..";
        $outline =~ tr/a-z/A-Z/;
        $htmloutput = "$htmloutput<OPTION$selected>$outline\n";
        $selected = "";
    }
    $htmloutput = "$htmloutput</SELECT>\n";
    return($htmloutput);
}

sub EditorViewSelection {
    my($htmloutput,$viewname);

    $htmloutput =  "<SELECT NAME=\"view\">\n<OPTION SELECTED>ALL";
    foreach $viewname (keys %main::views) {
        $htmloutput =  "$htmloutput<OPTION>$viewname\n";
    }
    $htmloutput =  "$htmloutput</SELECT>\n";
    return($htmloutput);
}

sub SubjectListingSelection {
    my($selected,$name,$htmloutput,$SubjectListingViews);

    $SubjectListingViews = $::SubjectListingViews;
    $SubjectListingViews = "$ROADS::Config/subject-listing"
	unless $SubjectListingViews;

    $htmloutput = "<SELECT NAME=\"slview\">\n";
    $selected = " SELECTED";
    opendir(VIEWS,"$SubjectListingViews");
    foreach $name (readdir(VIEWS)) {
        next if $name eq '.';
        next if $name eq '..';
        $htmloutput = "$htmloutput<OPTION$selected>$name\n";
        $selected="";
    }
    closedir(VIEWS);
    $htmloutput = "$htmloutput</SELECT>\n";
    return($htmloutput);
}

sub WhatsNewSelection {
    my($selected,$name,$htmloutput,$WhatsNewViews);
            
    $WhatsNewViews = $::WhatsNewViews;
    $WhatsNewViews = "$ROADS::Config/whats-new"
	unless $WhatsNewViews;

    $htmloutput = "<SELECT NAME=\"wnview\">\n";
    $selected = " SELECTED";
    opendir(VIEWS,"$WhatsNewViews");
    foreach $name (readdir(VIEWS)) {
        next if $name eq '.';
        next if $name eq '..';  
        $htmloutput = "$htmloutput<OPTION$selected>$name\n";
        $selected="";
    }
    closedir(VIEWS);
    $htmloutput = "$htmloutput</SELECT>\n";
    return($htmloutput);
}

sub ListMissingMandatory {
    my($attr,$htmloutput);

    $htmloutput = "<UL>\n";
    foreach $attr (@main::MissingMandatory) {
        next if($attr=~/^[\n\r]*$/);
        $htmloutput = "$htmloutput<LI>$attr\n";
    }
    $htmloutput = "$htmloutput</UL>\n";
    return($htmloutput);
}

# Subroutine to provide an HTML 2.0 SELECT menu to allow the user to choose
# the database he wishes to use.  If the argument is true then an ALL''
# entry is also generated to allow the user to select all the databases
# simultaneously (if generated, this will be the selected option).
#
sub SelectDatabases {
    my($allowall) = @_;
    my($selected,$htmloutput,$name);

    $htmloutput = "<SELECT NAME=\"database\" MULTIPLE>\n";
    if ($allowall) {
        $htmloutput .= "<OPTION SELECTED>ALL\n";
        $selected = "";
    } else {
        $selected = " SELECTED";
    }
    foreach $name (keys %database) {
        $htmloutput .= "<OPTION$selected>$name\n";
        $selected = "";
    }
    $htmloutput .= "</SELECT>\n";

    return($htmloutput);
}

#
# Subroutine to just check that a Lang/Charset file exists.
# Returns 0 if not appropriate file exists or 1 if it does.  Note that
# no error
sub LangFileExists {
    my($program,$file,$language,$charset) = @_;
    my($htmlfile,$quality,$lpair,$lcode,$lqual);

    $debug = $::debug || 0;

    # Initialise the language mappings if we haven't already done so.
    &InitLang unless (defined($::Language) && defined($::CharSet));
    &InitLookup unless defined %LanguageLookup;

    $language = $::Language unless defined($language);
    $charset = $::CharSet unless defined($charset);

    $language =~ tr/[A-Z]/[a-z]/;
    $charset =~ tr/[A-Z]/[a-z]/;
    $lqual = 1.0;
    $quality = 0;
    foreach $lpair (split(",",$language)) {
        $lpair=~s/\s//g;
        ($lcode,$lqual)=split(";",$lpair);
        $lqual=~s/^q=//;
        next if($lqual < $quality);
        $quality = $lqual;
        $htmlfile = $LanguageLookup{"$lcode-$charset"} ||
            $LanguageLookup{"$::Language-$::CharSet"};
    }

    if (-f "$htmlfile/$program/$file") {
        $htmlfile .= "/$program/$file";
    } elsif (-f "${ROADS::Config}/$htmlfile/$program/$file") {
        $htmlfile = "${ROADS::Config}/$htmlfile/$program/$file";
    } elsif (-f "${ROADS::Config}/$program/$file") {
        $htmlfile = "${ROADS::Config}/$program/$file";
    } elsif (-f "${ROADS::Config}/multilingual/UK-English/$program/$file") {
        $htmlfile = "${ROADS::Config}/multilingual/UK-English/$program/$file";
    } else {
        $htmlfile = "/nada";
    }

    return 0 if(($htmlfile eq "") || (!open(HTMLFILE,$htmlfile)));
    close(HTMLFILE);
    return 1;
     
}

# generic substitutions that could appear anywhere
sub GenericSubs {
    my($rule_to_do) = @_;
    $_ = $rule_to_do;

    if (/<ALLTEMPLATETYPES>/i) {
	$newtext = &TemplateTypeSelection(1);
	s/<ALLTEMPLATETYPES>/$newtext/ig;
    } 

    if (/<TEMPLATETYPELIST>/i) {
	$newtext = &TemplateTypeSelection;
	s/<TEMPLATETYPELIST>/$newtext/ig;
    }

    if (/<ROADSSERVICENAME>/i) {
	s/<ROADSSERVICENAME>/$ROADS::ServiceName/ig;
    }

    if (/<ROADSDBADMINEMAIL>/i) {
	s/<ROADSDBADMINEMAIL>/$ROADS::DBAdminEmail/ig;
    }

    if (/<ROADSSYSADMINEMAIL>/i) {
	s/<ROADSSYSADMINEMAIL>/$ROADS::SysAdminEmail/ig;
    }

    if (/<QUERY>/i) {
	$temp = $::query; $temp =~ s/:.*//;
	s/<QUERY>/$temp/ig;
    }

    if (/<X-HANDLE>/i) {
        $xhandle = time . "-" . $$;
        s/<X-HANDLE>/<INPUT TYPE="hidden" NAME="handle" VALUE="$xhandle">/i;
    }

    if (/<HANDLE>/i) {
	s/<HANDLE>/$::Handle/ig;
    }

    if (/<MATCHES>/i) {
	s/<MATCHES>/$::matches/ig;
    }

    if (/<LOCALMATCHES>/i) {
	s/<LOCALMATCHES>/$::localtotal/ig;
    }

    if (/<REMOTEMATCHES>/i) {
	my($burp) = $::matches-$::localtotal;
	s/<REMOTEMATCHES>/$burp/ig;
    }

    if (/<REFERRALTOTAL>/i) {
	s/<REFERRALTOTAL>/$::referraltotal/ig;
    }

    if (/<THISPOSTFORM>/i) {
	s/<THISPOSTFORM>/<FORM ACTION="$::myurl" METHOD="POST">/ig;
    }

    if (/<THISGETFORM>/i) {
	s/<THISGETFORM>/<FORM ACTION="$::myurl" METHOD="GET">/ig;
    }

    if (/<TEMPLATETYPE>/i) {
	s/<TEMPLATETYPE>/$CGIvar{templatetype}/ig;
    }

    if (/<MKTEMP-VIEW>/i) {
	s/<MKTEMP-VIEW>/$CGIvar{view}/ig;
    }

    if (/<MKTEMP-OP>/i) {
	s/<MKTEMP-OP>/$CGIvar{op}/ig;
    }

    if (/<MKTEMP-MODE>/i) {
	s/<MKTEMP-MODE>/$CGIvar{mode}/ig;
    }

    if (/<MKTEMP-AUTH>/i) {
	if (($ENV{REMOTE_USER} ne "") && ($CGIvar{mode} ne "edit")) {
	    $Username = $ENV{REMOTE_USER};
	    $string = "<INPUT TYPE=\"checkbox\" CHECKED NAME=\"AddAuth\" ".
		"VALUE=\"$Username\">";
	} else {
	    $string = "(user not authenticated)";
	}
	s/<MKTEMP-AUTH>/$string/ig;
    }

    if (/<ORIGINALHANDLE>/i) {
	s/<ORIGINALHANDLE>/$CGIvar{originalhandle}/ig;
    }

    if (/<MKTEMP-ADDITIONAL>/i) {
	s/<MKTEMP-ADDITIONAL>/$::additional/ig;
    }

    if (/<MKTEMP-DEFAULT>/i) {
	s/<MKTEMP-DEFAULT>/$::default/ig;
    }

    if (/<MYURL>/i) {
	s/<MYURL>/$::myurl/ig;
    }

    if (/<LANGUAGE>/i) {
	s/<LANGUAGE>/<INPUT TYPE="hidden" NAME="language" VALUE="$Language">/ig;
    }

    if (/<CHARSET>/i) {
	s/<CHARSET>/<INPUT TYPE="hidden" NAME="charset" VALUE="$CharSet">/ig;
    }

    if (/<SELECTVIEW>/i) {
	$newtext = &EditorViewSelection;
	s/<SELECTVIEW>/$newtext/ig;
    }

    if (/<LISTINGBLOCK>/i) {
	$block = $_;
	while(!/<\/LISTINGBLOCK>/i) {
            $_ = <HTMLFILE>;
            $block .= $_;
	}
	$_ = $block;
	if ($::Permitted{"GenerateListing"} == 1) {
            $newtext = &SubjectListingSelection;
            s/<SELECTLISTING>/$newtext/igs;
            s/<LISTINGBLOCK>(.*)<\/LISTINGBLOCK>/$1/igs;
	} else {
            s/<LISTINGBLOCK>.*<\/LISTINGBLOCK>//igs;
	}
    }

    if (/<WHATSNEWBLOCK>/i) {
	$block = $_;
	while(!/<\/WHATSNEWBLOCK>/i) {   
            $_ = <HTMLFILE>;
            $block .= $_;
	}
	$_ = $block;
	if ($::Permitted{"GenerateWhatsNew"} == 1) {
            $newtext = &WhatsNewSelection;
            s/<SELECTWHATSNEW>/$newtext/igs;
            s/<WHATSNEWBLOCK>(.*)<\/WHATSNEWBLOCK>/$1/;
	} else {
            s/<WHATSNEWBLOCK>.*<\/WHATSNEWBLOCK>//igs;
	}
    }

    if (/<RETURNTEMPLATE>/i) {   
	$block = $_;
	while(!/<\/RETURNTEMPLATE>/i) {
            $_ = <HTMLFILE>;
            $block .= $_;
	}
	$_ = $block;
	if ($::Permitted{"ReturnTemplate"} == 1) {
            s/<RETURNTEMPLATE>(.*)<\/RETURNTEMPLATE>/$1/igs;
	} else {
            s/<RETURNTEMPLATE>(.*)<\/RETURNTEMPLATE>//igs;
	}
    }

    if (/<EMAILTEMPLATE>/i) {
	$block = $_;  
	while(!/<\/EMAILTEMPLATE>/i) {  
            $_ = <HTMLFILE>;
            $block .= $_;  
	}  
	$_ = $block;  
	if ($::Permitted{"EmailTemplate"} == 1) {  
            s/<EMAILTEMPLATE>(.*)<\/EMAILTEMPLATE>/$1/igs;
	} else {  
            s/<EMAILTEMPLATE>(.*)<\/EMAILTEMPLATE>//igs;
	}  
    }

    if (/<OFFLINEMODE>/i) {
        $block = $_;
        while(!/<\/OFFLINEMODE>/i) {
            $_ = <HTMLFILE>;
            $block .= $_;
        }
        $_ = $block;
        if ($::Permitted{"OfflineMode"} == 1) {
            s/<OFFLINEMODE>(.*)<\/OFFLINEMODE>/$1/igs;
        } else {
            s/<OFFLINEMODE>(.*)<\/OFFLINEMODE>//igs;
        }
    }

    if (/<ENTERTEMPLATE>/i) {
	$block = $_;  
	while(!/<\/ENTERTEMPLATE>/i) {  
            $_ = <HTMLFILE>;
            $block .= $_;  
	}  
	$_ = $block;  
	if ($::Permitted{"EnterTemplate"} == 1) {  
            s/<ENTERTEMPLATE>(.*)<\/ENTERTEMPLATE>/$1/igs; 
	} else {  
            s/<ENTERTEMPLATE>(.*)<\/ENTERTEMPLATE>//igs;
	}  
    }

    if (/<MISSINGMANDATORY>/i) {
	$newtext = &ListMissingMandatory;
	s/<MISSINGMANDATORY>/$newtext/ig;
    }

    if (/<DATABASES>/i) {
	$newtext = &SelectDatabases;
	s/<DATABASES>/$newtext/ig;
    }

    if (/<REALDATABASES>/i) {
	$newtext = &SelectDatabases(0);
	s/<REALDATABASES>/$newtext/ig;
    }

    if (/<HTDOCS>/i) {
      if($ROADS::WWWHtDocs eq "" || $ROADS::WWWHtDocs eq "/") {
        s/\/*<HTDOCS>\/*/\//ig;
      } else {
        s/<HTDOCS>/$ROADS::WWWHtDocs/ig;
      }
    }

    if (/<CGI-BIN>/i) {
	s/<CGI-BIN>/$ROADS::WWWCgiBin/ig;
    }

    if (/<ADMIN-CGI>/i) {
	s/<ADMIN-CGI>/$ROADS::WWWAdminCgi/ig;
    }

    if (/<ADMINCGI>/i) {
	s/<ADMINCGI>/$ROADS::WWWAdminCgi/ig;
    }

    if (/<BULLET>/i) {
	s/<BULLET>/$ROADS::Bullet/ig;
    }

    if (/<SERVURL>/i) {
	s/<SERVURL>/$::url/ig;
    }

    if (/<SCHEME>/i) {
	s/<SCHEME>/$::scheme_name/ig;
    }
    
    if (/<NAME>/i) {
	s/<NAME>/$::longname/ig;
    }
    
    if (/<TREEPARENT/i) {
      if (defined $::parents) {
	my $html,$join;
	$join = (/<TREEPARENT\s*\"([^\"]+)\"\s*>/)? $1: ' | ';
	foreach $parent (split /\n/,$::parents) {
	  my ($longname, $shortname, $num) = split /:/,$parent;
	  $html .= "<a href=\"$shortname.html\">$longname</a>$join";
	}
	$html =~ s/\Q$join\E$//; # remove last join
	s/<TREEPARENT\s*\"*[\Q$join\E]*\"*\s*>/$html/ig;
      } else {
	$_ = "";  # line is blanked
      }
    }
  
    if (/<TREECHILDREN/i) {
      if (defined $::children) {
	my $html,$join;
	$join = (/<TREECHILDREN\s*\"([^\"]+)\"\s*>/)? $1: ' | ';
	foreach $child (split /\n/,$::children) {
	  my ($longname, $shortname, $num) = split /:/,$child;
	  $html .= "<a href=\"$shortname.html\">$longname</a>$join";
	}
	$html =~ s/\Q$join\E$//; # remove last join
	s/<TREECHILDREN\s*\"*[\Q$join\E]*\"*\s*>/$html/ig;
      } else {
	$_ = "";  # line is blanked
      }
    }
  
    if (/<RELATED/i) {
      if (defined $::related) {
	my $html,$join;
      $join = (/<RELATED\s*\"([^\"]+)\"\s*>/)? $1: ' | ';
	foreach $rel (split /\n/,$::related) {
	  my ($longname, $shortname, $num) = split /:/,$rel;
	  $html .= "<a href=\"$shortname.html\">$longname</a>$join";
	}
	$html =~ s/\Q$join\E$//; # remove last join
	s/<RELATED\s*\"*[\Q$join\E]*\"*\s*>/$html/ig;
      } else {
	$_ = "";  # line is blanked
      }
    }
  
    if (/<SECTION-EDITOR>/i) {
      if (defined $::sec_ed){
	s/<SECTION-EDITOR>/$::sec_ed/ig;
      } else {
	$_ = "";
      }
    }

    if (/<SECTION-EDITOR-PAGE>/i) {
      if (defined $::sec_ed_page){
	s/<SECTION-EDITOR-PAGE>/$::sec_ed_page/ig;
      } else {
	$_ = "";
      }
    }

    if (/<SEARCHHINT>/i) {
      my $message_dir = &::GetMessageDir("search-hints", "", $::Language, $::CharSet);
    
      print "[<EM>got hints_dir: $message_dir</EM>]<BR>\n" if $debug;
    
      if (open(DATA, "$message_dir/hints.data")) {
	my @hints,$in;
	while ($in = <DATA>) {
	  next if ($in =~ /^\s*\#/);
	  push @hints,$in;
	}
	s/<SEARCHHINT>/$hints[int(rand $#hints+1)]/ei;
      } else {
	s/<SEARCHHINT>//;
      }
    }

    # Lastly see if there should be any of our variables written out
    while(/<ROADSVAR([ "=a-zA-Z0-9]+)>/i) {
        my($attr,$val,$rep,$thing);

        ($attr,$val) = split("=",$1);
        $attr =~ tr/a-z/A-Z/;
        $attr =~ s/[\" ]//g;
        $val =~ s/[\" ]//g;
        if ($attr eq "SCALAR") {
            $rep = eval("\$ROADS::$val");
        } elsif ($attr eq "ARRAY") {
            foreach $thing (eval("\@ROADS::$val")) {
                $rep = $rep.$thing;
            }
        } elsif ($attr eq "HASH") {
            foreach $thing (eval("keys \%ROADS::$val")) {
                $rep = $rep.eval("\$ROADS::$val{$thing}");
            }
        }
        s/<ROADSVAR([ \"=a-zA-Z0-9])+>/$rep/i;
    }

    return $_;
}

1;
__END__


=head1 NAME

ROADS::HTMLOut - A class to dump out HTML in various forms

=head1 SYNOPSIS

  use ROADS::HTMLOut;
  EditorViewSelection
  $postprocessed_strings = GenericSubs($string);
  $dir = GetMessageDir($program, $view, $language, $charset);
  InitLookup;
  InitLang;
  if (LangFileExists($program, $file, $language, $charset)) {...}
  print ListMissingMandatory;
  OutputHTML($program, $file, $language, $charset);
  print SelectDatabases;
  print SubjectListingSelection;
  print TemplateTypeSelection;
  print WhatsNewSelection;

=head1 DESCRIPTION

This class contains a number of methods for turning text containing
ROADS specific psuedo-HTML tags into normal HTML using variable
interpolation.

=head1 METHODS

=head2 print EditorViewSelection;

This method looks at the keys of the I<views> hash array, and
generates an HTML SELECT menu with an element for each of them.

=head2 GenericSubs( string );

This method knows about a large number of generic substitutions which
may be carried out on a string, typically involving replacing a "fake"
HTML tag with the results of a variable interpolation.  These are
listed separately in the ROADS technical documentation.

=head2 GetMessageDir( program, view, language, charset );

This method tries to find the most appropriate HTML messages directory
to use for a given combination of program name, rendering view,
language and character set.

=head2 InitLookup;

This method seeds a hash array I<LanguageLookup> with the available
language details from the ROADS installation, typically
I<config/languages>.  The array is keyed on the language code and
character set, e.g. "en-gb-ISO-8859-1", and the value for a given
element is a path relative to the ROADS I<config> directory, or an
absolute path.  This path points to the outline HTML message files for
a particular language and character set combination.

=head2 InitLang;

This method initializes the I<Language> and I<CharSet> variables (used
to select outline HTML for rendering to the end user) based on the
following algorithm :-

  If the command line switch -L or -C is set, its value will
    be used
  ... otherwise if the HTTP Accept-Language or Accept-Charset
    header is set, its value will be used
  ... otherwise if the CGI variable Language or Charset is set,
    its value will be used
  ... otherwise the default values of "en" and "iso-8859-1"
    will be used

The tests for language and character set are actually independent,
though we've grouped them together here for simplicity.

=head2 LangFileExists( program, file, language, charset );

This method tests for the existence of a message file for a particular
program and language/character set combination.

=head2 print ListMissingMandatory;

This method returns a string containing an HTML list structure, each
entry of which is one of the elements in the scalar array
I<MissingMandatory>.  This is normally used by B<mktemp.pl>, the ROADS
template editor, to indicate fields which should have ben filled in
but weren't.

=head2 OutputHTML( program, file, language, charset );

This method tries to send the message file I<file> with any variable
substitutions which may be necessary for the program I<program> in the
requested I<language> and I<charset> if possible.  We try to use HTTP
content negotiation to control the directory which is searched in for
message files for a given I<language> and I<charset> combination.

Note that this method does not send the HTTP B<Content-type> header.
This is something that any code which calls it will have to do itself.

=head2 print SelectDatabases;

This method returns an HTML SELECT structure each element of which
corresponds to a database configured in the ROADS installation.

=head2 print SubjectListingSelection;

This method returns an HTML SELECT structure each element of which
corresponds to a subject listing view.

=head2 print TemplateTypeSelection;

This method returns an HTML SELECT structure each element of which
corresponds to one of the available template types.

=head2 print WhatsNewSelection;

This method returns an HTML SELECT structure with an element for each
of the avavailable "What's New" views.

=head1 FILES

I<config/languages> - specifies the directories where the HTML
messages file may be found for a particular language and character
set/encoding combination.

I<config/multilingual/*> - default location of outline HTML messages
distributed with the ROADS software.  Each program has its own sub-
directory under this.  Programs which support multiple "views" of a data
set typically have a directory I<program-views>.

HTML message files are formatted as normal, which additional
"pseudo-HTML" tags as described separately in the ROADS technical
documentation.

=head1 PSEUDO-HTML TAGS

=head2 What's New listing programs

This tag is understood by I<bin/addwn.pl> and I<bin/cullwn.pl>:

=over 4

=item B<ADDEDTIME>

Replaced by time at which template was last modified, found by doing a
I<stat(2)> of the file it lives in.

=back

=head2 Subject listing programs

These tags are understood by I<bin/addsl.pl>.

=over 4

=item B<TREECHILDREN["separator"]>

Replaced by links to the sections defined as children of the current section 
in the I<config/class-map> file. The list will be separated by " | " or the
optional separator string given in the tag.

=item B<TREEPARENT>

Replaced by a link to the section defined as the parent of the current section 
in the I<config/class-map> file.

=item B<RELATED["separator"]>

Replaced by links to the sections defined as related to the current section 
in the I<config/class-map> file. The list will be separated by " | " or the
optional separator string given in the tag.

=item B<SECTION-EDITOR>

Replaced by the name of the current section's section editor, as defined in
I<config/section-editors>.

=item B<SECTION-EDITOR-PAGE>

Replaced by the filename of the current section's section editor, as defined in
I<config/section-editors>.


=back

=head2 Survey program

This tag is understood by I<cgi-bin/survey.pl>, the user survey
program.

=over 4

=item B<X-HANDLE>

Replaced with a unique identifier generated from the current time and
the process ID of the running CGI program.

=back


=head2 Generalized mechanism

The following tags are handled by the B<OutputHTML> routine.  This
is quite flexible in terms of the directories it will look in for its
HTML outlines - mainly because of the support we are adding for
internationalisation.

B<OutputHTML> is invoked with the name of a program and an
associated message file, e.g. I<tempbyhand> and
I<nohandle.html>.  It then checks to see whether there this file is

=over 4

=item available in the preferred language(s) and charset(s).

B<NB this part is still under development!>

=item in a sub-directory of the ROADS I<config> directory,

This should be named the same as the name of the program, e.g.
I<config/tempbyhand/nohandle.html>.

=back

The tags we understand are:

=over 4

=item B<ADMINCGI>

Replaced by B<\$ROADS::WWWAdminCgi>.

=item B<ADMIN-CGI>

Replaced by B<\$ROADS::WWWAdminCgi>.

=item B<ALLTEMPLATETYPES>

Replaced by a B<SELECT> menu of all of the template types
available, found by looking at the filenames in the 
I<\$ROADS::Config/outlines> directory.  An additional item, I<ALL>
will be added, and marked selected by default.  See also 
B<TEMPLATETYPELIST>.

=item B<CHARSET>

Replaced by a hidden field setting the value of the HTML form variable
B<charset> to the value of B<\$CharSet> if present, i.e.

  <INPUT TYPE="hidden" NAME="charset" VALUE="$CharSet">

=item B<CGI-BIN>

Replaced by B<\$ROADS::WWWCgiBin>.

=item B<DATABASES>

Replaced by a B<SELECT> menu of all of the databases which are
known to the ROADS server - i.e. present in B<\$ROADS::Config/databases>.
In this context a database is essentially the combination of WHOIS++
server hostname, port number, and B<Destination> attribute to search on.
An extra entry, selected by default, will be added for I<ALL> of the
databases.  See also B<REALDATABASES>.

=item B<HANDLE>

Replaced by B<\$Handle> if present

=item B<HTDOCS>

Replaced by B<\$ROADS::WWWHtDocs>.

=item B<LANGUAGE>

Replaced by a hidden field setting the value of the HTML form variable
B<language> to the value of B<\$Language> if present, e.g.

  <INPUT TYPE="hidden" NAME="language" VALUE="$Language">

=item B<MATCHES>

Replaced by B<\$matches> if present.

=item B<MISSINGMANDATORY>

Replaced by a bullet-point list of the contents of the
B<@MissingMandatory> array - used by the template editor to signal
mandatory attributes which have not been filled in.

=item B<MKTEMP-ADDITIONAL>

Replaced by B<\$additional> if present.

=item B<MKTEMP-DEFAULT>

Replaced by B<\$default> if present.

=item B<MKTEMP-MODE>

Replaced by B<\$CGIvar{mode}> if present.

=item B<MKTEMP-OP>

Replaced by B<\$CGIvar{op}> if present.

=item B<MKTEMP-VIEW>

Replaced by B<\$CGIvar{view}> if present.

=item B<MYURL>

Replaced by B<\$myurl> if present.

=item B<NAME>

Replaced by B<\$longname>, the full name of this subject category.

=item B<ORIGINALHANDLE>

Replaced by B<\$CGIvar{originalhandle}> if present.

=item B<QUERY>

Replaced by B<\$query> if present.

=item B<SEARCHHINT>

Replaced by a randomly selected one-line string from 
B<\$ROADS::Config/multilingual/*/search-hints/hints.data>.

=item B<SELECTLISTING>

Replaced by a B<SELECT> menu of all the subject listing I<views>
which are known to the ROADS server - i.e. present in
B<\$ROADS::Config/subject-listing/views>.

=item B<SELECTVIEW>

Replaced by a B<SELECT> menu of all of the template editor
I<views> for this particular template type which are known to the ROADS
server - i.e. present in the appropriate file in
B<\$ROADS::Config/mktemp-views/>.

=item B<SELECTWHATSNEW>

Replaced by a B<SELECT> menu of all the I<What's New views>
which are known to the ROADS server - i.e. present in
B<\$ROADS::Config/whats-new/views>.

=item B<REALDATABASES>

Replaced by a B<SELECT> menu of all of the databases which are
known to the ROADS server - i.e. present in B<\$ROADS::Config/databases>.
In this context a database is essentially the combination of WHOIS++
server hostname, port number, and B<Destination> attribute to search on.
See also B<DATABASES>.

=item B<ROADSDBADMINEMAIL>

Replaced by B<\$ROADS::DBAdminEmail>.

=item B<ROADSSERVICENAME>

Replaced by B<\$ROADS::ServiceName>.

=item B<ROADSSYSADMINEMAIL>

Replaced by B<\$ROADS::SysAdminEmail>.

=item B<SCHEME>

Replaced by B<\$scheme_name>, the B<Subject-Descriptor> scheme
specified on the command line, or I<UDC> if not present.

=item B<TEMPLATETYPE>

Replaced by B<\$CGIvar{templatetype}> if present.

=item B<TEMPLATETYPELIST>

Replaced by a B<SELECT> menu of all of the template types
available, found by looking at the filenames in the
B<\$ROADS::Config/outlines> directory.  An additional item, I<ALL>
will be added, and marked selected by default.  See also
B<ALLTEMPLATETYPES>.

=item B<THISPOSTFORM>

Creates an HTML form using the POST method, with B<\$myurl> as the
action, i.e.

  <FORM ACTION="$myurl" METHOD="POST">

Note that you must supply the closing

  </FORM>

=item B<THISGETFORM>

Creates an HTML form using the GET method, with B<\$myurl> as the
action, i.e.

  <FORM ACTION="$myurl" METHOD="GET">

Note that you must supply the closing

  </FORM>

=back
 
=head1 INTERNATIONALIZATION (I18N)

The HTML output by the ROADS tools is capable of being internationalized
by allowing a different set of HTML documents to be sent back to the end
user depending upon the language and character set in use.  The language
and character set can be specified by (in order of decreasing priority)
browser HTTP headers, CGI parameters, command line options to the
scripts and built in defaults.  The CGI parameters for are called
B<language> and B<charset>, the HTTP headers are B<HTTP_ACCEPT_LANGUAGE>
and B<HTTP_ACCEPT_CHARSET> and the options are usually B<-L> and B<-C>.
Whilst older browsers rarely allowed the user to specify the HTTP headers,
many of the newest browsers do allow the headers to be easily configured
by the end user using GUI control panels (see your particular browser's
documentation for details of how to do this - there are far too many
browsers in use to permit us to detail this).

The out-of-the-box default language and charset for ROADS is for a
language of "en" (International English) and a character set of
"iso-8859-1" (ISO Latin 1 - Western European characters).  The mapping
between these parameters and the actual set of language pages is made
using the B<\$ROADS::Config/languages> file.  This file looks
something like this:

  en-uk   ISO-8859-1      multilingual/UK-English
  en-gb   ISO-8859-1      multilingual/UK-English
  en-us   ISO-8859-1      multilingual/UK-English
  en      ISO-8859-1      multilingual/UK-English
  en      iso-8859-1,*,utf-8      multilingual/UK-English
  de      ISO-8859-1      multilingual/Deutsch

Each line has a language, character set and path to a directory.  The
path can either be an absolute path to anywhere in the filesystems on
the machine or a path relative to B<\$ROADS::Config> (as shown in the
default file above).  Inside the directory, each ROADS program has its
own subdirectory and it is within these subdirectories that the actual
HTML is located.  Currently ROADS is distributed with a full set of
International English HTML files and a small demonstration subset
for the mktemp.pl introduction FORM in German.  Hopefully over time,
contributed translations of the ROADS HTML will be made available.

The use of HTML FORMs within ROADS does currently lead to some problems
for internationalisation (I18N).  Both the HTML 2.0 standard (RFC1866)
and the W3C's HTML 3.2 Recommendation both used coded character sets
based on the ISO-8859-1 Latin-1 character set.  This provides support
for most Western European characters.  The newer W3C HTML 4.0
recommendation is based upon Unicode and therefore allows a greater
range of characters to be represented in HTML documents.  It also
provides support for detailing the language in use and direction that
sections of the text should be render/read in.

Until the development of HTML 4.0, all form data being submitted from
web browsers to CGI programs had to consist of ASCII text.  Even with
HTML 4.0, CGI scripts using the GET method or scripts using the POST
method with the widely used application/x-www-form-urlencoded MIME type
can only receive ASCII text.  Only FORMs using the POST method between
HTML 4.0 compliant browsers where the enclosure type is something like
multipart/form-data can be used to pass non-ASCII characters.
Unfortunately, HTML 4.0 browsers that support these features are
currently still quite rare and the HTML 4.0 specification was only
released towards the end of the ROADS v2 development phase.  It is hoped
that ROADS v3 will be able to make use of these new features and by that
time the bulk of the web browsers in use will also support them.

In the meantime, although the ROADS indexing software is capable of
indexing characters from outside of the ASCII character set, it is very
difficult for cataloguers and end users to enter multilingual strings.
For this reason we encourage sites that do wish to provide a
multilingual service to provide at least an English version of there
data,and if possible a Romanized version of the native language form(s)
of their data, so that existing browsers can search their databases.

=head1 BUGS

Some confusion over variable scoping.  It's also unclear whether
programs should need to use the language and character set parameters
(and initialize these themselves), or whether these should
automatically be initialized to sensible values.

OutputHTML sends its output to the currently selected file descriptor.
It might make more sense to have it return its output as a string or
scalar array for further processing, e.g. by a user defined module.

=head1 SEE ALSO

I<admin-cgi> and I<cgi-bin> programs.

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

