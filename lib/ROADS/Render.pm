#
# ROADS::Render - render WHOIS++ template into HTML
# 
# Authors: Jon Knight <jon@net.lut.ac.uk>
#          Martin Hamilton <martinh@gnu.org>
#
# $Id: Render.pm,v 3.31 1999/07/29 14:40:39 martin Exp $

package ROADS::Render;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(methodcheck render %TEMPLATE);

use ROADS::CGIvars;
use ROADS::ErrorLogging;
use ROADS::HTMLOut;
use ROADS::Index;
use ROADS::ReadTemplate;

#
# Subroutine to check whether we have a correct URL method in the match
#
sub methodcheck {
    my ($check) = @_;

    if ($CGIvar{method} eq "any") {
        return 1;
    } else {
        if (index($CGIvar{method},$check) != -1 ) {
            return 1;
        }
    }
    return 0;
}


#
# Subroutine to render WHOIS++ responses into HTML
#
sub render {
    my ($query,$view,@ranked_results) = @_;
    my (@SUBS,%URI,$rule,$fullhandle,$attrib,$sub,$default,$line,$check);
    my (@terms,$term,$protocol,$write,$wrote,$rhs,$for_each,$this_attrib);
    my ($message_dir,%this_temp,$this_key);

    $debug = $::debug;

    # XXX - should have more flexibility, e.g. in the case of an
    # indexed server which is temporarily unavailable when doing
    # referral followup
    if (grep(/^noconnect$/, @ranked_results)) {
	&OutputHTML("$::scriptname", "noconnect.html",
		    $::Language, $::CharSet);
	return;
    }

    if ($::referraltotal == 0 && $::localtotal == 0) {
        $::matches = $#ranked_results + 1;
        print "[<EM>No totals in search results - using no. records "
	    . "returned</EM>]<BR>\n" if $debug;
    } else {
        $::matches = 0;
        foreach $fullhandle (@ranked_results) {
           next if $fullhandle =~ /:HITS$/;
           next if $fullhandle =~ /^localcount/;
           next if $fullhandle =~ /^referralcount/;
           next if $fullhandle =~ /:referral/;
           $::matches++;
        }
        print "[<EM>Using totals in search results</EM>]\n" if $debug;
    }

    if ($::matches == 0) {
      my $message_dir = &GetMessageDir("$::scriptname-views", "$view", $::Language, $::CharSet);
      if (-f "$message_dir/nohits"){
	&OutputHTML("$::scriptname-views", "$view/nohits", $::Language, $::CharSet);
      } else {
	&OutputHTML("$::scriptname", "nohits.html", $::Language, $::CharSet);
      }
      return;
    }

    print "[<EM>render called with by '$::scriptname' with query '$query', "
	. "view '$view' and #ranked_results: $#ranked_results</EM>]\n"
	    if $debug;

    # split query into its consituent bits
    my($q) = split /:/,$::query,2;
    foreach $term (split(/\s/,$q)) {
	next if $term =~ /^(and|or|not)$/i;
        $term =~ s/[\(\)]//g; # strip stuff
#	$term =~ s/^([^=])+=(.*)/$1/;
	push (@terms,$term);
    }

    # dump out first bit of HTML using normal HTML rendering code
    &OutputHTML("$::scriptname-views", "$view/header",
		$::Language, $::CharSet);

    # need for figure out which directory the message files for this
    # particular lang/charset combination live in, so that we know
    # where to look for the per-template info
    $message_dir = &GetMessageDir("$::scriptname-views", "$view",
				$::Language, $::Charset);

    print "[<EM>got message_dir: $message_dir</EM>]<BR>\n" if $debug;

    unless (opendir(MESSAGE_DIR, "$message_dir")) {
	print "<HR>Can't open HTML messages directory '$message_dir'.\n";
        print "Consult tech support!<HR>\n";
	&OutputHTML("$::scriptname-views", "$view/trailer",
		    $::Language, $::CharSet);
	exit;
    }

    @SUBS = ();
    while(($rulefile = readdir MESSAGE_DIR)) {
	next if $rulefile =~ /^\./;
	next if $rulefile =~ /^header$/;
	next if $rulefile =~ /^trailer$/;
	next if $rulefile =~ /~$/;
	print "[<EM>adding rule $rulefile</EM>]<BR>\n" if $debug;

	unless (open (RULES, "$message_dir/$rulefile")) {
	    &WriteToErrorLog("render",
              "couldn't open rule file $message_dir/$rulefile: $!");
	    next;
	}

	@these_rules = ();
	while(<RULES>) {
	    chomp;
	    push (@these_rules, "$_");
	    @{ $SUBS{"$rulefile"} } = @these_rules;
	}
	close(RULES);
    }

    # now apply these rules to the actual results
    foreach $fullhandle (@ranked_results) {
        next if $fullhandle =~ /:HITS$/;
        next if $fullhandle =~ /^localcount/;
        next if $fullhandle =~ /^referralcount/;
        next if $fullhandle =~ /:referral/;

	# blech!  we have to peek into each template to find out what
	# type it is, so we know which set of rules to use in
	# rendering it :-(
	$t_format = $t_shandle = $t_ttype = $t_handle = $t_spec = "";

	if (!defined($::TEMPLATE{"$fullhandle"})) {
	    # we need to read this in ourselves - it's not the
	    # result of a WHOIS++ search
	    print "[<EM>reading in template $fullhandle</EM>]<BR>\n"
		if $debug;

	    $t_format = "full";
            $t_shandle = "$ROADS::Serverhandle";
	    $t_handle = "$fullhandle";

	    %this_temp = &readtemplate("$fullhandle");
	    $::TEMPLATE{"$fullhandle"} = "";
	    foreach $this_key (sort keys %this_temp) {
	      $this_key_fixed = $this_key;
	      $this_key_fixed =~ s/-v\d+//;
	      $this_key_fixed =~ tr [a-z] [A-Z];

  	      if (length($::TEMPLATE{"$fullhandle"}) > 0) {
  	        $::TEMPLATE{"$fullhandle"} .=
		    "\n $this_key_fixed: $this_temp{\"$this_key\"}";
              } else {
  	        $::TEMPLATE{"$fullhandle"} =
		    " $this_key_fixed: $this_temp{\"$this_key\"}";
	      }

    	      if ($this_key =~ /^Template-Type$/i) {
		  $t_ttype = $this_temp{"$this_key"};
	      }
	    }
	} else {
	    print "[<EM>using cached template $fullhandle</EM>]<BR>\n"
		if $debug;

	    if ($::TEMPLATE{"$fullhandle"} =~ /^#\s+SERVER-TO-ASK\s+(.*)/i) {
		$t_format = "referral";
		$t_shandle = $1;
	    } elsif ($::TEMPLATE{"$fullhandle"} =~ /^#\s+SUMMARY\s+(.*)/i) {
		     $t_format = "summary";
		     $t_shandle = $1;
	    } elsif ($::TEMPLATE{"$fullhandle"} =~ /^#\s+COUNT\s+(.*)/i) {
		     $t_format = "count";
		     $t_shandle = $1;
	    } elsif ($::TEMPLATE{"$fullhandle"} =~
		     /^#\s+FULL\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)/i) {
		     $t_format = "full";
		     $t_ttype = $1;
		     $t_shandle = $2;
		     $t_handle = $3;
	    } elsif ($::TEMPLATE{"$fullhandle"} =~
		     /^#\s+HANDLE\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)/i) {
		     $t_format = "handle";
		     $t_ttype = $1;
		     $t_shandle = $2;
		     $t_handle = $3;
	    } elsif ($::TEMPLATE{"$fullhandle"} =~
		     /^#\s+ABRIDGED\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)/i) {
		     $t_format = "abridged";
		     $t_ttype = $1;
		     $t_shandle = $2;
		     $t_handle = $3;
		 }
	}

        #print "its... $fullhandle -- $::TEMPLATE{\"$fullhandle\"} " .
        #  " --\n" if $debug;

	if ($debug) {
	    print "<BR>[<EM>t_format: $t_format, t_ttype: $t_ttype, "
		. "t_shandle: $t_shandle, t_handle: $t_handle</EM>]<BR>\n";
	}

	# fall back to "default" template view if we don't recognise this
        # - of course we can't guarantee it exists!
	#
	# we're getting pretty funky now in terms of the options that
	# are available :- different rules for rendering on a per
	# template, serverhandle, template-type and format basis.
	#
        $t_spec = "default";
	if ($SUBS{"$t_format-$t_ttype-$t_shandle-$t_handle"}) {
	    $t_spec = "$t_format-$t_ttype-$t_shandle-$t_handle";
	} elsif ($SUBS{"$t_format-$t_ttype-$t_shandle"}) {
	    $t_spec = "$t_format-$t_ttype-$t_shandle";
	} elsif ($SUBS{"$t_format-$t_ttype"}) {
	    $t_spec = "$t_format-$t_ttype";
	} elsif ($SUBS{"$t_format-$t_shandle"}) {
	    $t_spec = "$t_format-$t_shandle";
	} elsif ($SUBS{"$t_handle"}) {
	    $t_spec = "$t_handle";
	} elsif ($SUBS{"$t_shandle"}) {
	    $t_spec = "$t_shandle";
	} elsif ($SUBS{"$t_format"}) {
	    $t_spec = "$t_format";
	}

	print "[<EM>using t_spec: $t_spec</EM>]\n" if $debug;

	foreach $rule (@{ $SUBS{"$t_spec"} }) {
 	    my($render_this) = $rule;
	    $render_this = &GenericSubs($render_this);

	    # special cases for template type, handle, ... which don't
	    # get returned as regular attributes
            $render_this =~ s/<SERVTITLE>/<\@TITLE>/gi;
            $render_this =~ s/<DATABASE>/$::EscapedDatabaseName/gi;
            $render_this =~ s/<HANDLE>/$t_handle/gi;
	    $render_this =~ s/<\@RESULT-FORMAT>/$t_format/gi;
	    $render_this =~ s/<\@TEMPLATE-TYPE>/$t_ttype/gi;
	    $render_this =~ s/<\@SERVERHANDLE>/$t_shandle/gi;
	    $render_this =~ s/<\@HANDLE>/$t_handle/gi;

	    # NB - parent/children processing code is only useful
	    # for locally available templates!

	    $children_label = $do_children = "";
	    if ($render_this =~ /<\@?CHILDREN/i) { # show children
  		$do_children = "yes";
  		if ($render_this =~ /<\@?CHILDREN\s+"([^"]+)">/i) {
                    $do_children_label = $1;
  		    $render_this =~ s/<\@?CHILDREN\s+"[^"]+">//i;
		} else {
  		    $render_this =~ s/<\@?CHILDREN>//i;
                }
  	    }

	    $parents_label = $do_parents = "";
	    if ($render_this =~ /<\@?PARENTS/i) { # show parents
  		$do_parents = "yes";
  		if ($render_this =~ /<\@?PARENTS\s+"([^"]+)">/i) {
                    $do_parents_label = $1;
		    $render_this =~ s/<\@?PARENTS\s+"[^"]+">]+>//i;
		} else {
		    $render_this =~ s/<\@?PARENTS>//i;
		}
  	    }

	    # we want to show parents and/or children of this record
	    $Children = $Parents = "";
	    if ($do_children eq "yes" || $do_parents eq "yes") {
 		($Children,$Parents) = &GetRelations("$fullhandle");

		if ($do_children eq "yes") {
		    if ($Children ne "") {
			print "$do_children_label" if $do_children_label;
			print "$Children\n";
		    }
		}

 		if ($do_parents eq "yes") {
		    if ($Parents ne "") {
			print "$do_parents_label" if $do_parents_label;
			print "$Parents\n";
		    }
		    next;
		}
 	    }

	    # NB - added/modified time procesing code is only useful
	    # for locally available templates!

	    if ($render_this =~ /<ADDEDTIME>/i) { # show time added
		$oldaddedtime = "" unless defined($oldaddedtime);

 		if ($::ADDED_TIME{"$fullhandle"} ne $oldaddedtime) {
 		    $oldaddedtime = $::ADDED_TIME{"$fullhandle"};
 		    $render_this =~ s/<ADDEDTIME>/$oldaddedtime/gi;
 		} else {
 		    # several items added in one shot
 		    $render_this = "";
 		}

 		print "$render_this\n";
		next;
 	    }

	    if ($render_this =~ /<MODIFIEDTIME>/i) { # show time added
 		$render_this =~
		    s/<MODIFIEDTIME>/$::MODIFIED_TIME{"$fullhandle"}/gi;

 		print "$render_this\n";
		next;
 	    }

	    unless ($render_this =~ m!\<\@!) { # no subs needed at all
		print "$render_this\n";
		next;
	    }

            $first = $check = $attrib = $default = $international = $last = "";

	    # special processing for loop construct
            $for_each_default = $for_each = "";
 	    if ($render_this =~ /^<FOREACH/i) { # record loop info
 		$for_each = "yes";
 		if ($render_this =~ /^<FOREACH\s+"([^"]+)">/i) {
                     $for_each_default = $1;
                     $render_this =~ s/^<FOREACH\s+"([^"]+)">\s+//i;
                }
 		$render_this =~ s/^<FOREACH>\s+//i;
 	    }

	    if ($render_this =~
		            /(.*)<\@([^\s]+)\s+"([^"]+)"\s*(INT)*>(.*)/) {
                $first = $1;
    		$attrib = $2;
                $default = $3;
                $international = $4;
                $last = $5;

                if ($attrib =~ /=/) {
                    ($attrib,$check_this) = split(/=/, $attrib);
                }
    	    } elsif ($render_this =~ /(.*)<\@([^>]+)>(.*)/) {
                $first = $1;
		$attrib = $2;
                $default = "";
                $last = $3;

                if ($attrib =~ /=/) {
                    ($attrib,$check_this) = split(/=/, $attrib);
                }
	    } else {
                next;
            }
            $wrote = "no";

            # special processing for URIs, URLs, ...
            if ($attrib =~ /UR[IL]/i) { # required to sort these.  blech!
                undef (%URI); undef (%SEENIT);
                foreach $line (split(/\n/, $::TEMPLATE{"$fullhandle"})) {
                    next unless $line =~ /^ $attrib:\s+(.*)/i;
                    $rhs = $1 || $default;

                    $write = $first . $rhs . $last;
                    $write =~ s/<\@$attrib>/$rhs/g;
                    if ($rhs =~ /^(http|gopher|ftp|telnet|wais|mailto):/) {
                        $protocol = $1;
                        $protocol =~ tr/[A-Z]/[a-z]/;
                    } else {
                        $protocol = "other";
                    }

		    next if $SEENIT{"$rhs"};
		    $SEENIT{"$rhs"} = 1;

                    if ($URI{"$protocol"}) {
                        $URI{"$protocol"} .= "\n$write";
                    } else {
                        $URI{"$protocol"} = "$write";
                    }
                }

                foreach $protocol ("http", "gopher", "ftp", "telnet",
                                   "wais", "mailto", "other") {
                    if ($URI{"$protocol"}) {
                        if ($::override{"$protocol"}) {
                            $URI{"$protocol"} =~ 
                                s/HREF="/HREF="$::waylay?url=/gim;
                        }
                        if ($for_each eq "yes") {
                            print "$URI{\"$protocol\"}\n";
                        } else {
                            last if ($wrote eq "yes");
                            $URI{$protocol} =~ s/\n.*//s;
                            print "$URI{\"$protocol\"}\n";
                        }
                        $wrote = "yes";
                        last unless $for_each eq "yes";
                    }
                }

                print "$default\n" if $wrote eq "no";
                next;
            }

            # hooray!  finally we get to the bit where we actually
            # render the template into HTML.  at last...
            foreach $line (split(/\n/, $::TEMPLATE{"$fullhandle"})) {
	        next unless $line =~ /^ $attrib:\s+(.*)/i;

                # further check for <@attrib=value> test
                if (defined($check)) {
                    next unless $line =~ /^ $attrib:\s+$check/i;
                }

                $rhs = $1 || $default;
                $internationalversion = "";
                if($international ne "") {
                  undef %IntContent;
                  undef %IntLanguage;
                  undef %IntCharSet;
                  $version = 0;
                  foreach $intline (split(/\n/, $::TEMPLATE{"$fullhandle"})) {
                    if($intline =~ /^ $attrib-content:\s+(.*)/i) {
                      $version++;
                      $IntContent{$version}=$1;
                    }
                    if($intline =~ /^ $attrib-language:\s+(.*)/i) {
                      $IntLanguage{$version}=lc($1);
                    }
                    if($intline =~ /^ $attrib-charset:\s+(.*)/i) {
                      $IntCharSet{$version}=lc($1);
                    }
                  }
                  $version = 1;
                  while($IntContent{$version}) {
                    $i18nmatch = 0;
                    foreach $lang (split(/[,\s]+/,lc($::Language))) {
                      if($language eq "*") {
                        $i18nmatch = 1;
                      } elsif(grep(/$lang/,
                                      split(",",$IntLanguage{$version}))){
                        $i18nmatch = 1;
                      }
                    }
                    if($i18nmatch == 0) {
                      $version++;
                      next;
                    }
                    $i18nmatch = 0;
                    foreach $charset (split(/[,\s]+/,lc($::CharSet))) {
                      if($charset eq "*") {
                        $i18nmatch = 1;
                      } elsif(grep(/$charset/,
                                      split(",",$IntCharSet{$version}))) {
                        $i18nmatch = 1;
                      }
                    }
                    if($i18nmatch == 1) {
                      $internationalversion=$IntContent{$version};
                      last;
                    }
                    $version++;
                  }
                }
                $rhs = $internationalversion if($internationalversion ne "");
		foreach $trm (@terms) {
		    my($att,$term);
		    if($trm =~ /\=/){
		      ($att,$term) = split /\=/,$trm;
		    } else {
		      $term = $trm;
		    }
                    next if $term =~ /^(and|or|not)$/i;
                    next if grep(/^$term$/i, @STOPLIST);
		    unless ((defined $att) && (uc($att) ne $attrib)){
		      if($caseful) {
                        if($::CGIvar{stemming} eq "sub") {
                          $rhs =~ s/($term)/<B>$1<\/B>/g;
                        } else {
                          $rhs =~ s/([( >]|^)($term)/$1<B>$2<\/B>/g;
			}	   
		      } else {
			if($::CGIvar{stemming} eq "sub") {
			  $rhs =~ s/($term)/<B>$1<\/B>/gi;
			} else {
			  $rhs =~ s/([( >]|^)($term)/$1<B>$2<\/B>/gi;
		        }
		      }
		    }
		}

                $write = $first . $rhs . $last;
                $write =~ s/<\@$attrib>/$rhs/g;
		print "$write\n";
		$wrote = "yes";
	        last unless $for_each eq "yes";
            }
            if($wrote eq "no" && $default) {
                print "$default\n" if $wrote eq "no";
            } elsif($for_each eq "yes" && $wrote eq "no" 
              && $for_each_default) {
                print "$for_each_default\n";
	    }
	}

        # If this is the admin script, add in a link to the template to
        # edit.
        if($::scriptname eq "admin") {
            local($templatetype);
            ($templatetype, $junk) = split(/\n/, $::TEMPLATE{"$fullhandle"},2);
            $templatetype =~ s/^#\s+\w+\s+(\w+).*/$1/;
            $handle = $fullhandle;
            $handle =~ s/(.*:)//;
            print <<"EditButton";
<CENTER>
<TABLE WIDTH="25%"><TR><TD ALIGN="CENTER">
<FORM ACTION="/$ROADS::WWWAdminCgi/mktemp.pl" METHOD="POST">
<INPUT TYPE="hidden" NAME="templatetype" VALUE="$templatetype">
<INPUT TYPE="hidden" NAME="op" VALUE="text">  
<INPUT TYPE="hidden" NAME="mode" VALUE="edit">
<INPUT TYPE="hidden" NAME="debug" VALUE="$debug">
<INPUT TYPE="hidden" NAME="originalhandle" VALUE="$handle">
<INPUT TYPE="hidden" NAME="view" VALUE="Quick Edit">
<INPUT TYPE="hidden" NAME="asksize" VALUE="sizes">
<INPUT TYPE="hidden" NAME="partdone" VALUE="yes">
<INPUT TYPE="hidden" NAME="clusterSubject" VALUE="0">
<INPUT TYPE="hidden" NAME="clusterPublisher" VALUE="0">
<INPUT TYPE="hidden" NAME="clusterAdmin" VALUE="0">
<INPUT TYPE="hidden" NAME="clusterAuthor" VALUE="0">
<INPUT TYPE="hidden" NAME="variantsize" VALUE="0">
<INPUT TYPE="submit" VALUE="Edit">
</FORM>
</TD><TD ALIGN="CENTER">
<FORM ACTION="/$ROADS::WWWAdminCgi/deindex.pl" METHOD="POST">
<INPUT TYPE="hidden" NAME="handletobedeleted" VALUE="$handle">
<INPUT TYPE="submit" VALUE="Del.">
</FORM><PRE>
</PRE>
</TD></TR></TABLE></CENTER>
EditButton
        }  
    }

    &OutputHTML("$::scriptname-views", "$view/trailer",
                $::Language, $::CharSet);
}


#
# Given a handle, return its parents and children
#
sub GetRelations {
  my($handle) = @_;
  my($ChildrenOut,$ParentsOut);
  my($attr,$type,$OutputHandle,$OutputDatabaseName,$OutputTitle);
  my(%RELTEMP);

  $::TEMPLATE=&readtemplate("$handle") unless defined $::TEMPLATE{"$handle"};
  return() unless defined(%TEMPLATE);

  foreach $attr (keys %TEMPLATE) {
    $_ = $attr;
    if (/^Relation-Type(-v[0-9]+)/i) {
      $TargetHandles = $TEMPLATE{"relation-target$1"};
      $type = $TEMPLATE{"$attr"};
      warn "Found a Relation-Type of $type\n" if $debug;

      if ($type =~ /ParentOf/i) {
        foreach $OutputHandle (split(/[,\s]/,$TargetHandles)) {
          undef(%RELTEMP);
          %RELTEMP = &readtemplate("$OutputHandle");
          next unless defined(%RELTEMP);

          ($OutputDatabaseName,$junk) = split(/[,\s]/,$RELTEMP{destination});
          $OutputDatabaseName =~ s/\s/%20/g;
          $OutputDatabaseName = $EscapedDatabaseName
            if ($OutputDatabaseName eq "");

          $OutputTitle = $RELTEMP{title};
          $ChildrenOut = "<UL>\n" if ($ChildrenOut eq "");
          $ChildrenOut .= "<LI><A HREF=\"/$ROADS::WWWCgiBin/tempbyhand.pl"
            . "?query=$OutputHandle&database=$OutputDatabaseName\">"
            . "$OutputTitle</A></LI>\n";
        }
      } elsif ($type =~ /ChildOf/i) {
        foreach $OutputHandle (split(/[,\s]/,$TargetHandles)) {
          undef(%RELTEMP);
          %RELTEMP = &readtemplate("$OutputHandle");
          next unless defined(%RELTEMP);

          ($OutputDatabaseName,$junk) = split(/[,\s]/,$RELTEMP{destination});
          $OutputDatabaseName =~ s/\s/%20/g;
          $OutputDatabaseName = $EscapedDatabaseName
            if ($OutputDatabaseName eq "");

          $OutputTitle = $RELTEMP{title};
          $ParentsOut = "<UL>\n" if ($ParentsOut eq "");
          $ParentsOut .= "<LI><A HREF=\"/$ROADS::WWWCgiBin/tempbyhand.pl"
            . "?query=$OutputHandle&database=$OutputDatabaseName\">"
            . "$OutputTitle</A></LI>\n";
        }
      }
    }
  }
  $ChildrenOut .= "</UL>\n" if $ChildrenOut ne "";
  $ParentsOut .= "</UL>\n" if $ParentsOut ne "";
  return($ChildrenOut,$ParentsOut);
}

1;
__END__


=head1 NAME

ROADS::Render - A class to render HTML outlines + variable substitutions

=head1 SYNOPSIS

  use ROADS::Render;
  # Do a WHOIS++ search or three...
  render($query, $view, @results);

=head1 DESCRIPTION

This class defines a mechanism for rendering WHOIS++ templates as HTML
- or other formats, though HTML is the primary goal.

=head1 METHODS

=head2 render( query, view, @results );

=over 4

=item I<query>

The WHOIS++ query which generated these results

=item I<view>

The view to use when rendering the results - many of the ROADS tools
which generate HTML support multiple versions or 'views' of the same
data using different HTML rendering rules.

=item I<results>

This is a list of results in the format produced by the B<wppd> code
in the B<ROADS::WPPC> class.

=back

=head1 FILES

I<config/multilingual/*/>B<scriptname>I</noconnect.html> -
HTML returned when connection to server couldn't be established.

I<config/multilingual/*/>B<scriptname>I</nohits.html> -
HTML returned when there were no hits for a given query.

I<config/multilingual/*/>B<scriptname>I<-views> -
directory containing alternative views of rendering.


=head1 RENDERING VIEWS

Each view is actually a directory.  Views typically consist of

=over 4

=item B<header>

HTML (or whatever...) to return for beginning of page.

=item B<tailer>

HTML (or whatever...) to return for end of page.

=item B<full>

Default rendering rules

=back


=head1 USAGE

The following additional custom rendering outlines are available :-

=over 4

=item I<format>

where I<format> is the name of the WHOIS++ response format.  This lets
you treat, for example, referrals to other servers differently from
regular records.  You could include a special logo for referrals, for
instance.

=item I<serverhandle>

where I<serverhandle> is the server handle of one of the servers you
expect to get results back from.  This lets you give all results which
come from this particular server their own custom HTML.

=item I<handle>

where I<handle> is the handle of a resource which you would to have
rendered differenly from all the other resources.  If you have a few
'stand out' resources this could be a good way of drawing attention to
them.

=item I<format-serverhandle>

where I<serverhandle> and I<format> are as before.  This lets you
treat (for example) referrals from this server differently to regular
records.

=item I<format-template_type>

where I<template_type> is the template type of the record.  This lets
you render different types of records in different way - e.g. to
display a picture icon beside an image.

=item I<format-template_type-serverhandle>

This lets you customize down to the level of particular types of
template from particular servers.

=item I<format-template_type-serverhandle-handle>

Phew!  This lets you customize down to the level of an individual
template handle, from a particular server, of a particular type and
response format :-)

=back

You probably won't need to tangle with this stuff early on (if ever?)
but we've tried to build plenty of flexibility in so that if you do
want to use it you can get some quite dramatic results with a minimum
of effort.  Check out the technical guide for more information about
customizing HTML rendering.


=head1 PSEUDO-HTML TAGS

=over 4

=item B<FOREACH>

This specifies a substitution pattern (see below) which is to be
executed B<for each> instance of the attribute specified in its
right hand side.  The format is

  <FOREACH "[default value]"> [substitution pattern]

where the text marked B<[default value]> is used if there are no
instances of the attribute specified in the substitution pattern.

=item B<MYURL>

Replaced with the URL of the WWW server, formed from
B<\$ROADS::MyHostname> and B<\$ROADS::MyPortNumber>.

=item B<QUERY>

Replaced with B<\$query>, the WHOIS++ query.

=item B<ROADSSERVICENAME>

Replaced with B<\$ROADS::ServiceName>.

=back

Attributes from the template being rendered may be referred to by placing
an B<@> sign in front of the attribute name, e.g.  B<@KEYWORDS> refers to
the B<Keywords> attribute.  If this does not occur within a B<FOREACH>
tag, only the first occurrence of the attribute's value will used.

The format of these references is

  <@[attributename] "[default value]">

e.g.

  <em>Keywords:</em><br> <@KEYWORDS "no keywords supplied">

Outline HTML files are found in I<config/search-views>.  Note that
you can only effect substitution for a single attribute per line of
your HTML outline file at the moment.


=head1 BUGS

The integration of hard coded HTML for the template editor and some
aspects of the subject/what's new listings is sub-optimal - to say the
least!

=head1 SEE ALSO

I<admin-cgi> and I<cgi-bin> programs, L<bin/addsl.pl>, L<bin/addwn.pl>,
L<bin/cullsl.pl>, L<bin/cullwn.pl>.

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
