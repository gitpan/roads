#
# porter.pl - An implementation of the Porter stemming algorithm
#   lifted from freeWAIS-0.3 and converted to Perl.
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: Porter.pm,v 3.11 1998/09/05 14:10:16 martin Exp $
#

package ROADS::Porter;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(stem);

@stemmed = ();

@step1a_rules = (
             101,  "sses",      "ss",    3,  1, -1,  True,
             102,  "ies",       "",     2,  0, -1,  True,
             103,  "ss",        "ss",    1,  1, -1,  True,
             104,  "s",         "",  0, -1, -1,  True,
             000,  "NULL",        "NULL",    0,  0,  0,  "NULL"
  );
@step1b_rules = (
             105,  "eed",       "ee",    2,  1,  0,  True,
             106,  "ed",        "",  1, -1, -1,  ContainsVowel,
             107,  "ing",       "",  2, -1, -1,  ContainsVowel,
             000,  "NULL",        "NULL",    0,  0,  0,  "NULL"
  );
@step1b1_rules = (
             108,  "at",        "ate",   1,  2, -1,  True,
             109,  "bl",        "ble",   1,  2, -1,  True,
             110,  "iz",        "ize",   1,  2, -1,  True,
             111,  "bb",        "b",     1,  0, -1,  True,
             112,  "dd",        "d",     1,  0, -1,  True,
             113,  "ff",        "f",     1,  0, -1,  True,
             114,  "gg",        "g",     1,  0, -1,  True,
             115,  "mm",        "m",     1,  0, -1,  True,
             116,  "nn",        "n",     1,  0, -1,  True,
             117,  "pp",        "p",     1,  0, -1,  True,
             118,  "rr",        "r",     1,  0, -1,  True,
             119,  "tt",        "t",     1,  0, -1,  True,
             120,  "ww",        "w",     1,  0, -1,  True,
             121,  "xx",        "x",     1,  0, -1,  True,
             122,  "",      "e",    -1,  0, -1,  AddAnE,
             000,  "NULL",        "NULL",    0,  0,  0,  "NULL"
  );
@step1c_rules = (
             100,  "ly"  ,      "",      1,  0, 0,  True,
             101,  "ally"  ,    "",      3,  0, 0,  True,
             102,  "ily"  ,     "y",     2,  0, 0,  True,
             123,  "y",         "i",     0,  0, -1,  ContainsVowel,
             123,  "y",         "",     1,  0, -1,  ContainsVowel,
             000,  "NULL",        "NULL",    0,  0,  0,  "NULL"
  );
@step2_rules = (
             203,  "ational",   "ate",   6,  2,  0,  True,
             204,  "tional",    "tion",  5,  3,  0,  True,
             205,  "enci",      "ence",  3,  3,  0,  True,
             206,  "anci",      "ance",  3,  3,  0,  True,
             207,  "izer",      "ize",   3,  2,  0,  True,
             208,  "abli",      "able",  3,  3,  0,  True,
             209,  "alli",      "al",    3,  1,  0,  True,
             210,  "entli",     "ent",   4,  2,  0,  True,
             211,  "eli",       "e",     2,  0,  0,  True,
             213,  "ousli",     "ous",   4,  2,  0,  True,
             214,  "ization",   "ize",   6,  2,  0,  True,
             215,  "ation",     "ate",   4,  2,  0,  True,
             216,  "ator",      "ate",   3,  2,  0,  True,
             217,  "alism",     "al",    4,  1,  0,  True,
             218,  "iveness",   "ive",   6,  2,  0,  True,
             219,  "fulnes",    "ful",   5,  2,  0,  True,
             220,  "ousness",   "ous",   6,  2,  0,  True,
             221,  "aliti",     "al",    4,  1,  0,  True,
             222,  "iviti",     "ive",   4,  2,  0,  True,
             223,  "biliti",    "ble",   5,  2,  0,  True,
             224,  "ation",     "e",   4,  2,  0,  True,
             225,  "el",        "ellous",   1,  2,  0,  True,
             226,  "dren",        "d",   3,  2,  0,  True,
             000,  "NULL",        "NULL",    0,  0,  0,  "NULL"
  );
@step3_rules = (
             301,  "icate",     "ic",    4,  1,  0,  True,
             302,  "ative",     "",  4, -1,  0,  True,
             303,  "alize",     "al",    4,  1,  0,  True,
             304,  "iciti",     "ic",    4,  1,  0,  True,
             305,  "ical",      "ic",    3,  1,  0,  True,
             308,  "ful",       "",  2, -1,  0,  True,
             309,  "ness",      "",  3, -1,  0,  True,
             000,  "NULL",        "NULL",    0,  0,  0,  "NULL"
  );
@step4_rules = (
             400,  "tial",      "",  3, -1,  1,  True,
             401,  "al",        "",  1, -1,  1,  True,
             402,  "ance",      "",  3, -1,  1,  True,
             403,  "ence",      "",  3, -1,  1,  True,
             405,  "er",        "",  1, -1,  1,  True,
             406,  "ic",        "",  1, -1,  1,  True,
             407,  "able",      "",  3, -1,  1,  True,
             408,  "ible",      "",  3, -1,  1,  True,
             409,  "ant",       "",  2, -1,  1,  True,
             410,  "ement",     "",  4, -1,  1,  True,
             411,  "ment",      "",  3, -1,  1,  True,
             412,  "ent",       "",  2, -1,  1,  True,
             413,  "lent",      "",  3, -1,  1,  True,
             423,  "sion",      "s",     3,  0,  1,  True,
             424,  "tion",      "t",     3,  0,  1,  True,
             415,  "ou",        "",  1, -1,  1,  True,
             416,  "ism",       "",  2, -1,  1,  True,
             417,  "ate",       "",  2, -1,  1,  True,
             418,  "iti",       "",  2, -1,  1,  True,
             419,  "ous",       "",  2, -1,  1,  True,
             420,  "ive",       "",  2, -1,  1,  True,
             421,  "ize",       "",  2, -1,  1,  True,
             422,  "lous",      "",  3, -1,  1,  True,
             000,  "NULL",        "NULL",    0,  0,  0,  "NULL"
  );
@step5a_rules = (
             501,  "e",         "",  0, -1,  1,  True,
             502,  "e",         "",  0, -1, -1,  RemoveAnE,
             000,  "NULL",        "NULL",    0,  0,  0,  "NULL"
  );
@step5b_rules = (
             503,  "ll",        "l",     1,  0,  1,  True,
             000,  "NULL",        "NULL",    0,  0,  0,  "NULL"
  );

#
# Subroutine that is the entry point for the Porter Stemming algorithm
#
sub stem {
    local($word) = @_;
    local($rule) = 0;

    @stemmed = ($word);
    return(@stemmed) if($word =~ /[^a-zA-Z]/);
    $word =~ tr/A-Z/a-z/;

    &ReplaceEnd($word,@step1a_rules);
    ($word) = @stemmed;
    $rule = &ReplaceEnd($word,@step1b_rules);
    ($word) = @stemmed;
    if(($rule == 106) || ($rule == 107)) {
        &ReplaceEnd($word,@step1b1_rules );
        ($word) = @stemmed;
    }
    &ReplaceEnd($word,@step1c_rules );
    ($word) = @stemmed;

    &ReplaceEnd($word,@step2_rules );
    ($word) = @stemmed;

    &ReplaceEnd($word,@step3_rules );
    ($word) = @stemmed;

    &ReplaceEnd($word,@step4_rules );
    ($word) = @stemmed;

    &ReplaceEnd($word,@step5a_rules );
    ($word) = @stemmed;

    &ReplaceEnd($word,@step5b_rules );
    ($word) = @stemmed;

    return(@stemmed);
}

sub True {
    return(1);
}

sub WordSize {
    local($word) = @_;
    local($result,$state)=0;
    
    foreach $char (split(/ */,$word)) {
        if($state == 0) {
            $state = &IsVowel($char) ? 1 : 2;
        } elsif ($state == 1) {
            $state = &IsVowel($char) ? 1 : 2;
            $result++ if(2==$state);
        } else {
            $state = (&IsVowel($char) || $char eq "y" ) ? 1 : 2;
        }
    }
    return($result);
}

sub IsVowel {
    local($char) = @_;

    return(1) if($char eq "a" || $char eq "e" || $char eq "i" || 
      $char eq "o" || $char eq "u");
    return(0);
}

sub ContainsVowel {
    local($word) = @_;

    return(0) if($word eq "");
    return(1) if($word =~ /^[aeiou]/);
    return(1) if($word =~ /^.+[aeiouy]/);
    return(0);
}

sub EndsWithCVC {
    local($word) = @_;

    return(0) if(length($word) < 2);
    return(1) if($word =~ /[^aeiou][aeiou][^aeiouwxy]/);
    return(0);
}

sub AddAnE {
    local($word) = @_;

    return((1 == &WordSize($word)) && &EndsWithCVC($word));
}

sub RemoveAnE {
    local($word) = @_;

    return((1 == &WordSize($word)) && !(&EndsWithCVC($word)));
}    

sub ReplaceEnd {
    local($word,@rule) = @_;
    local($ending,$tmpch);

    $id = shift(@rule);
    $old_end = shift(@rule);
    $new_end = shift(@rule);
    $old_offset = shift(@rule);
    $new_offset = shift(@rule);
    $min_root_size = shift(@rule);
    $condition = shift(@rule);
    while($id != 0) {
        $thisword=$word;
warn "Doing rule $id with word $word and condition $condition\n" if($debug);
        $ending = length($thisword) - $old_offset;
warn "ending = $ending\n" if($debug);
        if($ending > 0) {
warn "old_end = \"$old_end\"\n" if($debug);
warn "matching with \"" . substr($thisword,$ending-1) . "\"\n" if($debug);
            if($old_end eq substr($thisword,$ending-1)) {
warn "Found a match...\n" if($debug);
warn "min_root_size = $min_root_size\n" if($debug);
warn "WordSize = " . &WordSize($thisword) . "\n" if($debug);
                if($min_root_size < &WordSize($thisword) ) {
                    if($condition ne "NULL") {
warn print "Evaluation: ".eval("&$condition" . "($thisword)")."\n" if($debug);
                        if(eval("&$condition" . "($thisword)")) {
                            $thisword = substr($thisword,0,$ending-1) . $new_end;
warn "<BR><STRONG>Stemmed to $thisword</STRONG><BR>\n" if($debug);
                            @stemmed = (@stemmed,$thisword);
                            last;
                        }
                    }
                }
            }
        }
        $id = shift(@rule);
        $old_end = shift(@rule);
        $new_end = shift(@rule);
        $old_offset = shift(@rule);
        $new_offset = shift(@rule);
        $min_root_size = shift(@rule);
        $condition = shift(@rule);
    }
    return($id);    
}

# @test = &stem("sequence");
# print @test;

1;
__END__


=head1 NAME

ROADS::Porter - A class to perform stemming using the Porter algorithm.

=head1 SYNOPSIS

  use ROADS::Porter;
  print join(" ", stem("wubbleyou")),  "\n";

=head1 DESCRIPTION

This class defines an implementation of the Porter stemming algorithm.

=head1 METHODS

=head2 @stemmed_terms = stem( term );

The I<stem> method operates on a single term I<term> at a time, and so
must be wrappered by any code which is aiming to stem multiple search
terms.  It returns a scalar array of terms found through the stemming
algorithm, including itself.

=head1 BUGS

It's not clear that the Porter algorithm is a very useful for this
sort of thing!  Some of the results look very silly.

=head1 SEE ALSO

L<bin/wppd.pl>, L<ROADS::Index>

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

