#
# ROADS::Index - Perl package for accessing and creating ROADS
#   indexes
#
# Authors: Jon Knight <jon@net.lut.ac.uk>
#          Martin Hamilton <martinh@gnu.org>
# $Id: Index.pm,v 3.23 1998/09/05 13:58:57 martin Exp $
#

require ROADS::Porter;

package ROADS::Index;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(index_search
  initStoplist initExpansions initRestrictions initIndexCache
  ExpansionsInit FieldRestrictionInit StoplistInit
  %RestrictFields %STOPLIST %TEMPLATE %INDEX %INDEXATTR);

use ROADS::ErrorLogging;
use ROADS::Porter;
use ROADS::ReadTemplate;

# Package scope variable marking whether we've initialised the restrictions
# on fields that can be searched.
$FieldRestrictionInit = 0;

#
# entry point for the search of the index.
# Arguments are a textual query string and a boolean flag to indicate
# whether to do a caseful query or not.
#
sub index_search {
    ($restrictionfile,$expansionfile,$stopfile,
      $iquery,$caseful,$stemming,$indexfile) = @_;
    my(%results);

    $debug = $main::debug if defined($main::debug);
    &initRestrictions($restrictionfile) unless $FieldRestrictionInit;
    &initExpansions($expansionfile) unless $ExpansionsInit;
    &initStoplist($stopfile) unless $StoplistInit;
    undef(%alltemps);
    print "% 204 *** before applying stoplist, '$iquery'\r\n" if $debug;
    foreach $stopper (@STOPLIST) {
      $iquery =~ s/^$stopper[\&\+\|\!]//;            # at start
      $iquery =~ s/[\&\+\|\!]$stopper$//;            # at end
      $iquery =~ s/[\&\+\|\!]$stopper\)/\)/;            # at end of bracket
      $iquery =~ s/\($stopper[\&\+\|\!]/\(/;            # at start of bracket
      $iquery =~ s/[\&\+\|\!]$stopper([\&\+\|\!])/$1/;   # in middle
    }
    print "% 204 *** after applying stoplist, '$iquery'\r\n" if $debug;
    $_= $iquery;
    %result=&expr;
    return(%result);
}


# read in stoplist
#
# a smarter version of this would/will cache the stoplist when
# the server first starts up and re-read it IFF the stoplist
# file has been modified since the list was loaded!
sub initStoplist {
    my($filename) = @_;
    if (-f "$filename") {
      if (open(STOPLIST, "$filename")) {
        undef(@STOPLIST);
        while(<STOPLIST>) { chomp; push(@STOPLIST, "$_"); }
        close(STOPLIST);
        print "% 204 *** read stoplist from $filename\r\n" if $debug;
      } else {
        print "% 204 *** couldn't read stoplist from $filename\r\n" if $debug;
      }
    }
    $StoplistInit = 1;
}

#
# read in list of expansions for search terms
#
sub initExpansions {
    my($filename) = @_;
    my($term,$expansions);

    undef(%QueryExpansions);
    unless (open(EXPAND, "$filename")) {
        $ExpansionsInit = 1;
        return;
    }
    $current_type = "";
    while (<EXPAND>) {
        chomp;
        $_=lc($_);
        s/\t+/\t/;
        ($term,$expansions) = split(/\t/);
        $QueryExpansions{"$term"} = "$expansions";
    }
    close(EXPAND);
    $ExpansionsInit = 1;
}

#
# read in restrictions on fields that can be searched
#
sub initRestrictions {
    my($filename) = @_;
    my($current_type);

    undef(%RestrictFields);
    unless (open(RESTRICT, "$filename")) {
        $FieldRestrictionInit = 1;
        return;
    }
    $current_type = "";
    while (<RESTRICT>) {
        chomp;
        $_=lc($_);
        last if /^\s+/;
        if (/^Template-Type:/i) {
            s/^Template-Type:\s*//i;
            $current_type = $_;
            next;
        }
        next if ($current_type eq "" || $_ eq "");
        s/:.*//;
        $RestrictFields{"$current_type"}{"$_"} = "y";
    }
    close(RESTRICT);
    $FieldRestrictionInit = 1;
}

#
# read in restrictions on fields that can be searched
#
sub initIndexCache {
    my($filename) = @_;

    if (defined(%main::INDEX)) {
      dbmclose(%main::INDEX);
      close(INDEX);
    }
    open(INDEX, "$filename") ||
      &main::WriteToErrorLogAndDie("$0", "couldn't open index $filename: $!");
    dbmopen(%main::INDEX, "$ROADS::Guts/index.dbm", undef) ||
      &main::WriteToErrorLogAndDie("$0",
        "Couldn't open DBM index cache: '$ROADS::Guts/index.dbm' : $!");
    $IndexCacheInit = 1;
}

#
# initialise a search
#
sub expr {
    my(%left,$op,%right);

    print "% 204 *** expr entered with query = '$iquery'\r\n" if $debug;
    %left = &term;
    print "% 204 *** expr after first term = '$iquery'\r\n" if $debug;

    while($op = &boolop) {
    print "% 204 expr got a boolop of '$op'\r\n" if $debug;
	%right = &term;
    print "% 204 expr after second term = '$iquery'\r\n" if $debug;
        if (($op eq "&") || ($op eq "and") || ($op eq "+")) {
	    print "% 204 Doing an AND...\r\n" if $debug;
	    foreach $key (keys %left) {
print "% 204 looking at key: $key, right: $right{$key}\r\n" if $debug;
		unless ($right{$key}) {
print "% 204 deleting handle which is unique to lhs: $key\n" if $debug;
		    delete $left{$key};
		}
	    }
	} else {
	    print "% 204 Doing an OR...\r\n" if $debug;
	    foreach $key (keys %right) {
print "% 204 looking at key: $key, right: $right{$key}, left: $left{$key}\r\n"
  if $debug;
		$left{$key} = $right{$key};
	    }
	}
    }
    %left;
}

#
# decide whether to do an AND or an OR in the search.
#
sub boolop {
    my($op);
    $_ = $iquery;
    if(s/^\s*([\&\|\+\,\/]|(and)|(or))\s*//i) {
        $op = lc($1);
    } else {
        $op = 0;
    }
    $iquery = $_;
    return $op;
}

#
# process a term from the search expression.
#
sub term {
    my(%val,$search,$line);

    print "% 204 In term with a query of '$iquery'\r\n" if $debug;

    # Grab some handy global variables from outside the package

    $_=$iquery;
    if (s/^((([\w\-]+=)*[\w\.\-\'\x80-\xff]+)\s*)+//) {
        my($searchterm,%match,$pass,$newsearch,$space,$bit,$subbit);
        $line = $_;
        $search = $1;
        $pass = 0;
	$search =~ s/\s*$//;
        $newsearch = "";
        $space = "";
        foreach $searchterm (split(" ",$search)) {
          if($searchterm=~/^([\w\-]+)=([\w\.\-\'\200-\377]+)/) {
            $attr = $1;
            $bit = $2;
            foreach $subbit (split(/[\.\-\']/,$bit)) {
              $newsearch .= "$space$attr=$subbit";
              $space = " ";
            }
          } else {
            $newsearch .= "$space$searchterm";
          }
          $space = " ";
        }
        print "% 204 newsearch = '$newsearch'\r\n" if $debug;
        $search = $newsearch;
        $search =~ s/\s*$//;
        foreach $searchterm (split(" ",$search)) {
          print "% 204 searchterm = '$searchterm'\r\n" if $debug;
          undef %match;
          %match = &lookup($searchterm);
          if($pass > 0) {
            foreach $key (keys %match) {
	      if ($val{$key} eq '') {
                delete $match{$key};
              }
            }
          }
          %val = %match;
          $pass++;
        }
	$_=$line;
    } elsif (s/^\(//) {
        $iquery = $_;
	%val = &expr;
	print "% 204 In middle of term with '$iquery' as the runt end\r\n"
	    if $debug;
#        $_ = $iquery;
	if(!(s/^\)//)) {
	    print "% 500 Syntax error in boolean expression\r\n";
	    exit(0);
        }
    } elsif (s/^!\(?([\!\&\|\sA-Za-z\200-\377="]+)\)?//) {
        local(@hits);
        $line=$_;
        $search=$iquery;
        $iquery=$1;
        %val = &expr; #new
        $iquery=$search;
        @hits=keys(%val);
        if(!defined(%alltemps)) {
            local($noth,$notf);
            if(!open(NOTS, "$ROADS::Guts/alltemps")) {
		print "% 501 Internal error\r\n";
                &WriteToErrorLogAndDie("$0", 
                  "Can't read alltemps file: $ROADS::Guts/alltemps: $!");
            }
            while(<NOTS>) {
                s/\s+/ /g; s/^\s//; s/\s$//;
                ($noth,$notf) = (split(" ",$_));
                $alltemps{$noth} = $notf;
            }
        }
        @allhandles = keys(%alltemps);
        local(%mark);
        grep($mark{$_}++,@hits);
        @nothandles = grep(!$mark{$_},@allhandles);
        undef(%val);
        foreach $handle (@nothandles) {
            $val{$handle} = $alltemps{$handle};
        }
        $_=$line;
    } else {
	print "% 500 Error parsing Boolean expression\r\n";
        exit(0);
    }
    $iquery = $_;
    print "% 204 returning... ", join(" ", keys %val), " \n" if $debug;
    %val;
}

#
# lookup a single word in the inverted index
#
sub lookup {
    my($input) = @_;
    my($hold,$line,$lquery,$attribute,%SEEN,$expansion,@searchwords);
    my(@CANDIDATES);
    undef(%SEEN);

    # Grab some handy global variables from outside the package
    $iafa_source = $main::iafa_source;
    $target_index = $main::target_index;
    $wgithesaurus = $main::wgithesaurus;
    $clientname = $main::clientname;
    $clientaddr = $main::clientaddr;
    $port_number = $main::port_number;

    # Determine the attribute that we should be looking for the search
    # word in (if none, then looking in all attributes, subject to field
    # restrictions imposed by the ROADS administrator).
    $hold = $input;
    if ($input =~ /=/) {
        ($attribute, $lquery) = split(/=/, $input);
    } else {
        $attribute = "any";
        $lquery = $input;
    }
    $attribute =~ tr/[A-Z]/[a-z]/;
    $attribute = "template-type" if ($attribute eq "template");

    print "% 204 In lookup with a query of '$attribute=$lquery'\r\n"
	if $debug;

    # See if the "word" is actually a phrase search.
    if($lquery =~ /\_/) {
        @word = split(/\_/, $lquery);
        $phrasing = 1;
        $phrase = $lquery;
        #$phrase =~ s/\_+/\s\+/g;
        $phrase =~ s/\_/ /g;
        $lquery=$word[0];
    } else {
        $phrasing = 0;
    }

    $lquery = lc($lquery) unless $caseful;

    my(%matched);
    undef %matched;

    print "% 204 using cached index\r\n" if ($debug && defined(%INDEX));

    # Set up the words to search on if we're doing stemming.
    if(($stemming) && (length($lquery) > 2) && (!$phrasing)) {
      print "% 204 doing stemming on '$lquery'\r\n" if $debug;
      # OK folks, time to break out Mr Thesaurus if asked for...
      if ($ROADS::WGIThesaurus ne "" && -x $ROADS::WGIThesaurus) {
        print "% 204 Attempting WGI thesaurus expansion...\r\n" if $debug;
        $ENV{"GATEWAY_INTERFACE"} = "WGI/1.0";
        $ENV{"QUERY_STRING"} = $lquery;
        $ENV{"REMOTE_ADDR"} = &inet_ntoa($clientaddr);
        $ENV{"REMOTE_HOST"} = $clientname if $clientname;
        $ENV{"SERVER_NAME"} = $ROADS::MyHostname if $ROADS::MyHostname;
        $ENV{"SERVER_PROTOCOL"} = "WHOIS++/1.0";
        $ENV{"SERVER_PORT"} = "$port_number";
        $ENV{"SERVER_SOFTWARE"} = "LUT-WHOIS++/$ROADS::Version";
        $ENV{"OPERATION"} = "ThesaurusExpand";
    
        if(!open(THESAURUS,"$ROADS::WGIThesaurus |")) {
          print "% 112 No thesaurus module available.\r\n";
        } else {
          @expansion = ();
          local($orig) = $lquery;
          while(<THESAURUS>) {
            chomp;
            foreach $expansion (split(/ /,$_)) {
              @searchwords = &stem($expansion);
              $lquery .= "|" . join('|', @searchwords);
            }
          }
          close(THESAURUS);
          print "% 204 Thesaurus expanded '$orig' to '$lquery'.\r\n" if $debug;
        }
      } else {
        print "% 204 No WGI thesaurus module available.\r\n" if $debug;
        print "% 204 wgithesaurus = '$ROADS::WGIThesaurus'\r\n" if $debug;
        @searchwords = &stem($lquery);
        $lquery = join('|', @searchwords);
        @origsearchwords = @searchwords;
        foreach $word (@origsearchwords) {
          if ($QueryExpansions{"$lquery"}) {
            foreach $expansion (split(/ /, $QueryExpansions{"$lquery"})) {
              print "% 204 expanding to '$expansion'\r\n" if $debug;
              @searchwords = &stem($expansion);
              $lquery .= "|" . join('|', @searchwords);
            }
          }
        }
      }
      @searchwords = split(/\|/,$lquery);
    } else {
      @searchwords = ($lquery);
    }
  
  print STDOUT "% 204 got to main loop...\r\n" if $debug;
  
  foreach $index_key (@searchwords) {

    print "% 204 Index key = $index_key\n" if $debug;
    $caseless_index_key = lc($index_key);
     
    $indr_file_offset = "";
    if(!$stemming) {
      next if(!defined($main::INDEX{$caseless_index_key})); # no match
      $indr_file_offset = $main::INDEX{$caseless_index_key};
      print "% 204 indr_file_offset = $indr_file_offset\n" if $debug;

      # look up entry in indirection index.
      open(IX, "$target_index.idr");
      open(IY, "$target_index");
      foreach $this_offset (split(",",$indr_file_offset)) {
        seek(IX, $this_offset, 0);
        chomp($this_indr_entry = <IX>);

        ($term,$indrpos)=split(":",$this_indr_entry);
  
        foreach $curpos (split(" ",$indrpos)) {

          # look up each entry in main index
          seek(IY, $curpos, 0);
          chomp($this_entry = <IY>);
          print STDOUT "% 204 got this_entry: $this_entry\r\n" if $debug;

          ($index_tt, $index_attrib, $index_term, $index_handles) = 
            split(/:/, $this_entry);

          # toss out any other attributes if constrained by attribute
          print STDOUT "% 204 index_attrib = '$index_attrib'\r\n" if $debug;
          print STDOUT "% 204 attribute = '$attribute'\r\n" if $debug;
          next if (($attribute ne "any") && ($index_attrib ne $attribute));
          print STDOUT "% 204 attributes matched\r\n" if $debug;


          if($caseful) {
            next if ($index_term ne $index_key);
          }

          # toss out if restricted attribute
          if($attribute ne "template-type") {
            next unless $RestrictFields{"$index_tt"}{"$index_attrib"} eq "y";
          }

          print STDOUT "% 204 got index_handles: $index_handles\r\n" if $debug;

          foreach $handle (split(" ", $index_handles)) {
            print STDOUT "% 204 Found possible match with '$handle'\r\n" if $debug;
            $SEEN{"$handle"} = "y";
          }
        }
      }
    } else {
      # look up entry in indirection index.
#      open(IX, "grep -i $caseless_index_key $ROADS::IndexDir/index.idr |");
      open(IX, "$target_index.idr");
      open(IY, "$target_index");
      $indrpos = "";
      while(<IX>) {
        if($stemming == 1) {
          next if!(/^$caseless_index_key.*:/i); # lstring
        } else {
          next if!(/$caseless_index_key.*:/i); # substring
        } 
        chomp;
        print STDOUT "% 204 $_\r\n" if($debug);
        s/^.+://;
        $indrpos = ($indrpos eq "") ? $_ : "$indrpos $_";
      }            
      print STDOUT "% 204 indrpos = $indrpos\r\n" if($debug);
      foreach $curpos (split(" ",$indrpos)) {
                     
        # look up each entry in main index
        seek(IY, $curpos, 0);
        chomp($this_entry = <IY>);
        print STDOUT "% 204 got this_entry: $this_entry\r\n" if $debug;
         
        ($index_tt, $index_attrib, $index_term, $index_handles) =
          split(/:/, $this_entry);

        # toss out any other attributes if constrained by attribute
        print STDOUT "% 204 We have attribute '$attribute'\r\n";
        print STDOUT "% 204 We found attribute '$index_attrib'\r\n";
        next if $attribute ne "any" && $index_attrib !~ /^$attribute$/i;
       
        if($caseful) {
          next if ($index_term ne $index_key);
        }
        
        # toss out if restricted attribute
        if($attribute ne "template-type") {
          next unless $RestrictFields{"$index_tt"}{"$index_attrib"} eq "y";
        }
      
        print STDOUT "% 204 got index_handles: $index_handles\r\n" if $debug;
    
        foreach $handle (split(" ", $index_handles)) {
          print STDOUT "% 204 Found possible match with '$handle'\r\n" if $debug;
          $SEEN{"$handle"} = "y";
        }
      }
    }
    close(IY);
    close(IX);
  }
#  close(INDEX) unless defined(%::INDEX);

  #### now iterate through potential matches

    foreach $handle (keys %SEEN) {
  	last if $matched{"$handle"};

        if ($phrasing) {
            &readtemplate($handle, "$iafa_source/$handle"); #### bad practice!
            ($tt = $::TEMPLATE{"Template-Type"}) =~ tr [A-Z] [a-z];

print "% 204 handle: $handle, phrase: $phrase, attribute: $attribute\r\n" 
  if $debug;
            foreach $resattr (keys %{ $RestrictFields{"$tt"} }) {
                $resattr =~ tr/A-Z/a-z/;
                foreach $tryattr (grep(/^$resattr/i, keys(%::TEMPLATE))) {
print "% 204 resattr: $resattr, tryattr: $tryattr\r\n" if $debug;
                    next if ($attribute ne "any" && $attribute ne $tryattr);
                    $match_this = $phrase;
                    $match_this =~ s/\s/\\s+/g;
print "% 204 trying to match '$match_this' against $::TEMPLATE{\"$tryattr\"}\n"
  if $debug;
		    if ($caseful) {
                        if ($::TEMPLATE{"$tryattr"} =~ /$match_this/) {
print "% 204 Matched casefully with attribute $tryattr.\r\n" if $debug;
                            $matched{"$handle"} = "$handle";
                            last;
			}
                    } else {
                        if ($::TEMPLATE{"$tryattr"} =~ /$match_this/i) {
print "% 204 Matched caselessly with attribute $tryattr.\r\n" if $debug;
                            $matched{"$handle"} = "$handle";
                            last;
			}
                    }
                }
            }
        } else {
            # already done search restrictions!
print "% 204 Matched template $handle.\r\n" if $debug;
            $matched{"$handle"} = "$handle";
        }
    }

    if(!$phrasing) {
        @::allwords = (@::allwords, @searchwords);
    } else {
        @::allwords = (@::allwords, $phrase);
    }
    $_ = $hold;
    print "% 204 Leaving query after searching for $lquery\r\n" if $debug;
    %matched;
}

# End of index package.
1;
__END__


=head1 NAME

ROADS::Index - A class to support searching of ROADS database indexes

=head1 SYNOPSIS

  use ROADS::Index;
  %results = index_search($restrictfile, $expansionfile, $stopfile,
			  $iquery, $caseful, $stemming);
  initExpansions($expansionfile);
  initIndexCache($targetindex);
  initRestrictions($restrictionfile);
  initStoplist($stopfile);
  
  # private
  if ($op = boolop) { ... }
  %results = expr;
  lookup;
  term;

=head1 DESCRIPTION

This class defines a series of methods for working with the ROADS
database index.  The main method which is called by outside code is
I<index_search>.  This calls the other methods in turn to initialise
the working environment, then carry out the search and process the
results.

=head1 METHODS

=over 4

=item %results = index_search($restrictfile, $expansionfile, $stopfile,
			  $iquery, $caseful, $stemming);

This method takes the query I<iquery>, together with a list of search
options, and results the search results as a list of record handles
for later processing with other tools.  The search options are :-

=over 4

=item I<restrictfile>

This parameter specifies a file listing the templates and template
attributes which should be made visible to end users.

=item I<expansionfile>

This parameter specifies a file listing simple query expansions which
should be carried out e.g. "color" as a synonym of "colour".

=item I<stopfile>

This parameter specifies a file listing the terms which it should not
be possible to search for, such as "a", "the" and so on.

=item I<caseful>

This Boolean variable controls whether the search terms will be
matched in a case sensitive or case insensitive way.

=item I<stemming>

This Boolean variable controls whether stemming will be active for
this search.  When stemming is turned on, query expansion will be
performed on the search terms to increase the number of matches.

=back

=item initExpansions( expansionfile );

This method initialises the list of expansions which will be used
during query expansion.

=item initIndexCache( targetindex );

This method opens the DB(M) based indirection index used to speed up
searching of ROADS databases.  This is nomally created by I<mkinv.pl>
when a database is indexed.

=item initRestrictions( restrictionfile );

This method intialises the search restrictions will be in force.

=item initStoplist( stopfile );

This method initialises the stoplist which will be in force.
  
=item boolop;

This method examines the string variable I<iquery> in the main
namespace, and searches for the presence of a Boolean AND or OR
operator.  If one of these is found it will be returned as the result
of the method, otherwise a zero (0) will be returned.

=item %results = expr;

This method also operates on I<iquery>, splitting it recurisvely into
left and right sub-expressions and intervening operators, until there
are no more sub-expressions left, and passing each sub-exprssion on to
the I<term> method.

=item %match = lookup( term );

This method tries to find ROADS database entries which match the
search term, and returns the resulting handles.

=item term;

This method examines a search term, and potentially calls I<expr> or
I<lookup> to further process it.

=back

=head1 FILES

I<config/admin-restrict> - default search restrictions for admin
users.

I<config/expansions> - default query expansions

I<config/search-restrict> - default search restrictions for end
users.

I<config/stoplist> - terms which have been stop-listed and should be
excluded from searches.

I<guts/index*> - the actual ROADS database index.

I<guts/alltemps> - list of template handles to filenam mappings.

=head1 BUGS

Some of this code is very messy, there is a fair bit of duplication of
effort, and too much reliance on global variables - often making it
hard to tell what's actually going on!

=head1 SEE ALSO

L<bin/wppd.pl>

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

