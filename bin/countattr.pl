#!/usr/bin/perl
use lib "/home/roads2/lib";

# countattr.pl: Count the attributes used in a template
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#         Martin Hamilton <martinh@gnu.org>
# $Id: countattr.pl,v 3.12 1998/08/18 19:31:28 martin Exp $
#
# Description: This script runs through a set of IAFA templates
#   and generates a report of which fields have been used and how
#   many times.  All of the templates must be in a single directory.

use Getopt::Std;

require ROADS;
use ROADS::ErrorLogging;

# Main section of the code

# Process the command line options
getopts('adhs:');

$debug = $opt_d || 0;
$IafaSourceDir = $opt_s || $ROADS::IafaSource;

# Get all the filenames of templates in the source directory
if($opt_a) {
    opendir(DIR,$IafaSourceDir)
      || &WriteToErrorLogAndDie("countattr",
           "Can't open directory $IafaSourceDir: $!");
    @ARGV = readdir(DIR);
    closedir(DIR);
}

# Actually process the template(s) to generate the list files
chdir($IafaSourceDir);
foreach $filename (@ARGV) {
    next if $filename =~ /^\./ || -d "$filename";
    warn "Looking at file \"$filename\"" if ($debug);
    undef %TEMPLATE;
    close(TEMPFILE);
    open(TEMPFILE,$filename) || &WriteToErrorLogAndDie("countattr",
                                  "Can't open $filename: $!");
    $current_type = "";
    while (<TEMPFILE>) {
        $line = $_;
        if (/^\n$/ || eof(TEMPFILE)) {
            $TEMPLATE{"handle"} =~ s/^\s*//;
            $handle =~ s/^\s*//;
            if ($current_type ne ""){
                &recordtemplate;
            }
            undef %TEMPLATE;
        }
        if (/^Template-Type:\s+(\w+)/i) {
            undef %TEMPLATE;
            $TEMPLATE{"Template-Type"}=$1;
            $current_type = $1;
        } else {
            if (/^([\w-]+)\:\s(.*)/) {
               $current_attr=$1;
               $line = $2;
               $current_attr =~ y/A-Z/a-z/;
            }
            $TEMPLATE{"$current_attr"} =~ s/$/$line/;
        }
    }
}

# Go and print out the results
&outputstats;

# End of the main code
exit;

#
# Subroutine to record the attributes used in this template
#
sub recordtemplate {
    local($tt, $attr, $val, $key);

    $tt = $TEMPLATE{"Template-Type"};
    $TYPE{"$tt"}++;
    $TotalTemplates++;
    foreach $attr (keys %TEMPLATE) {
        next if ($attr eq "Template-Type");
        ($val = $TEMPLATE{"$attr"}) =~ s/^\s*$//;
        $attr =~ s/-v[0-9]+$//;
        $attr =~ tr/A-Z/a-z/;
        $key = "$tt:$attr";
        next if ($val eq "");
        if ($USED{"$key"}) {
            $USED{"$key"} += 1;
        } else {
            $USED{"$key"} = 1;
        }
    }
}

#
# Subroutine to output the statistics detailing which template types
# and attributes have been seen.
#
sub outputstats {

    $= = 1000000;
    @keys = keys(%TYPE);
    $NumberTypes = $#keys + 1;
    @attrkeys = keys(%USED);

    if ($opt_h) {
        select((select(STDOUT), 
                 $^="HTML_TYPE_TEXT_TOP", $~="HTML_TYPE_TEXT")[0]);
    } else {
        select((select(STDOUT), $^="TYPE_TEXT_TOP", $~="TYPE_TEXT")[0]);
    }
    write;

    foreach $Type (sort(@keys)) {
        if ($opt_h) {
            select((select(STDOUT), 
                     $^="HTML_TYPE_TEXT_TOP", 
                     $~="HTML_TYPE_ATTR_TEXT_TOP")[0]);
        } else {
            select((select(STDOUT), 
                     $^="TYPE_TEXT_TOP", $~="TYPE_ATTR_TEXT_TOP")[0]);
        }
        $TypeCount = $TYPE{"$Type"};
        write;
        @attr = grep(/^$Type:/, @attrkeys);
        $rank = 0;
        if ($opt_h) {
            select((select(STDOUT), 
                     $^="HTML_TYPE_TEXT_TOP", $~="HTML_TYPE_ATTR_TEXT")[0]);
        } else {
            select((select(STDOUT), 
                     $^="TYPE_TEXT_TOP", $~="TYPE_ATTR_TEXT")[0]);
        }
        foreach $attr (sort { $USED{$b} <=> $USED{$a} } @attr) {
            $count=$USED{"$attr"};
            $attr =~ s/^$Type://;
            next if ($attr eq "0");
            next if ($attr =~/^\s+$/);
            $rank++;
            $pc=($count/$TypeCount)*100;
            write;
        }
    }
    
}

#
# Formats for the various reports
#
format TYPE_TEXT_TOP =
======================================================================
Template Statistics for:     @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                            $IafaSourceDir
======================================================================
Number of different template types in use:  @<<<<<<<
                                            $NumberTypes
======================================================================
Number of templates scanned:                @<<<<<<<<
                                            $TotalTemplates
======================================================================

.

format TYPE_TEXT =
.

format TYPE_ATTR_TEXT_TOP = 
======================================================================
Details for Template-Type:                 	 	@<<<<<<<<<<<<<
                                            		$Type
======================================================================
Count of templates with this Template-Type:		@<<<<<<<<<<<<<
							$TypeCount
======================================================================
Rank	Attribute name				Occurances	%-age
======================================================================
.

format TYPE_ATTR_TEXT =
@<<<<	@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<	@<<<<<<<<	@<<<<
$rank,	$attr,					$count		$pc
.

#
# And HTML versions too!
#
format HTML_TYPE_TEXT_TOP =
<h1>IAFA Template Statistics</h1>
<pre>
Template Statistics for:     @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                            $IafaSourceDir
Number of different template types in use:  @<<<<<<<
                                            $NumberTypes
Number of templates scanned:                @<<<<<<<<
                                            $TotalTemplates
.

format HTML_TYPE_TEXT =
.

format HTML_TYPE_ATTR_TEXT_TOP = 
</pre>
<h1>Details for Template-Type @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                              $Type
</h1>
<p>
Count of templates with this Template-Type: @<<<<<<<<<<<<<
                                            $TypeCount
</p>

<pre>
Rank	Attribute name				Occurances	%-age
<hr>
.

format HTML_TYPE_ATTR_TEXT =
@<<<<	@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<	@<<<<<<<<	@<<<<
$rank,	$attr,					$count		$pc
.

__END__


=head1 NAME

B<bin/countattr.pl> - count the attributes used in a template

=head1 SYNOPSIS

  bin/countattr.pl [-adh] [-s sourcedir] [file1 file2 ... fileN]
 
=head1 DESCRIPTION

This Perl program runs through a set of IAFA (or IAFA style) templates
and generates a report of which fields have been used and how many
times.

=head1 OPTIONS

=over 4

=item B<-a>

Iterate over all of the templates in the source directory

=item B<-d>

Generate debugging information.

=item B<-h>

Generate output in HTML format.

=item B<-s> I<sourcedir>

Change the source directory from the default.

=back

=head1 OUTPUT

Mail to server maintainers.

=head1 SEE ALSO

L<admin-cgi/countattr.pl>

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
Martin Hamilton E<lt>martinh@gnu.orgE<gt>

