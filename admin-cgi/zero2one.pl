#!/usr/bin/perl
use lib "/home/roads2/lib";

# zero2one.pl - convert ROADS v0 multiple databases to ROADS v1 format
#
# Author: Jon Knight <jon@net.lut.ac.uk>
# $Id: zero2one.pl,v 3.11 1998/08/18 19:24:45 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;
use ROADS::HTMLOut;

use Getopt::Std;

# Get the command line options.
getopts('C:L:s:');

# URL of this program
$myurl = "/$ROADS::WWWAdminCgi/zero2one.pl";

# What language to return
$Language = $opt_L || "en-uk";

# What character set to use.
$CharSet = $opt_C || "ISO-8859-1";

# Location IAFA templates directory (v1 templates source)
$IafaSource = $opt_s || $ROADS::IafaSource;

# Print out the HTTP Content-type header and then cleave the CGI URL into
# an associative array ready for use.
&cleaveargs;
&CheckUserAuth("zero2one_users");
print STDOUT "Content-type: text/html\n\n";

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

# Check to see if both the source of the old templates and the name of the
# new destination for the database have been specified.  If not, output a
# form asking for them.
if(($CGIvar{source} eq "") || ($CGIvar{name} eq "")) {
    &OutputHTML("zero2one", "zerotooneform.html", $Language, $CharSet);
    exit;
}

# Open the old .alltemps file, outputing an error message if we can't
if(!open(ALLTEMPS,"$CGIvar{source}/.alltemps")) {
    &OutputHTML("zero2one", "noalltemps.html", $Language, $CharSet);
    exit;
}

# For the creation email address, try the authenticated username first,
# then an IDENTD lookup username and finally use a default.
$user = $ENV{REMOTE_USER};
$user = $ENV{REMOTE_IDENT} if($user eq "");
$user = "unknown" if($user eq "");

unless($ENV{REMOTE_USER}) {
  print STDOUT <<EndOfHTML;
Content-type: text/html

<HTML>
<HEAD>
<TITLE>Can't convert ROADS version 0 templates</TITLE>
</HEAD>
<BODY>
<H1>Can't convert ROADS version 0 templates</H1>

Sorry - you can only run this as a CGI script if you're HTTP authenticated!
</BODY>
</HTML>
EndOfHTML

  exit;
}

# Read in each line of the old .alltemps file, get the handle and filename
# for the template, read it in, alter the destination field appropriately
# output it to the new v1 IAFA source directory and index it under v1.
while(<ALLTEMPS>) {
    chomp;
    next if /^$/;
    next if /^#/;
    ($handle,$filename) = split;
    &readtemplate($handle,$filename);
    $TEMPLATE{"destination"} =~ s/\n$//;
    if($TEMPLATE{"destination"} eq "") {
        $TEMPLATE{"destination"} = "$CGIvar{name}";
    } else {
        $TEMPLATE{"destination"} = "$TEMPLATE{\"destination\"}, $CGIvar{name}";
    }
    $REALATTR{"destination"}="Destination" if($REALATTR{"destination"} eq "");
    if(!open(NEWTEMP,">$IafaSource/$handle")) {
        &OutputHTML("zero2one", "newopenfailed.html", $Language, $CharSet);
        &WriteToErrorLog("zero2one",
          "Cannot open new template in $IafaSource/$handle");    
        exit;
    }
    $tt=$TEMPLATE{"Template-Type"};
    print NEWTEMP "Template-Type: $tt\n";
    print NEWTEMP "Handle: $handle\n";
    foreach $key (keys %TEMPLATE) {
        next if($key eq "Template-Type");
        next if($key eq "handle");
        $TEMPLATE{$key} =~ s/\n*$//;
        print NEWTEMP "$REALATTR{\"$key\"}: $TEMPLATE{\"$key\"}\n";
    }
    close(NEWTEMP);

    # If the user has selected index, then go and do it.  Also update the
    # ChangeLog in the guts to show that we've done it.
    if($CGIvar{index} eq "on") {
        $res=system("$ROADS::Bin/mkinv.pl", "$handle");
        if($res != 0) {
            &OutputHTML("zero2one","cannotindex.html",$Language,$CharSet);
            &WriteToErrorLog("zero2one", "Cannot index $handle");    
            exit 1;    
        }

        # Add a line to the end of the change log detailing the operation
        # performed and the date and user that performed it.
        open(CHANGELOG,">>$ROADS::Logs/ChangeLog");
        flock(CHANGELOG,2);
        print CHANGELOG "[$entrydate] CONVERTED $handle by $user\n";
        flock(CHANGELOG,8);
        close(CHANGELOG);
    }   
}
close(ALLTEMPS);

# Tell the user that its all been done.
&OutputHTML("zero2one", "alldone.html", $Language, $CharSet);
exit;

#
# Subroutine to read in a particular template from a file given the handle
# and the filename.  Returns the template in the associate array TEMPLATE.
#
sub readtemplate {
    local($handle,$filename) = @_;

    undef %TEMPLATE;
    close(MATCH);
    open(MATCH,$filename) || return %TEMPLATE;
    $current_type = "";
    while (<MATCH>) {
        $line = $_;
        if (/^\n$/ || eof(MATCH)) {
            $TEMPLATE{"handle"} =~ s/^\s*//;
            $handle =~ s/^\s*//;
            if (($current_type ne "") && ($TEMPLATE{"handle"} eq $handle)) {
                return %TEMPLATE;
            }
        }
        if (/^Template-Type:\s+(\w+)/) {
            undef %TEMPLATE;
            $TEMPLATE{"Template-Type"}=$1; 
            $current_type = $1;
        } else {
            if (/^([\w-]+)\:\s(.*)/) {
               $current_attr = $1;
               $line = $2;
               $real_attr = $current_attr;
               $current_attr =~ y/A-Z/a-z/;
               $REALATTR{"$current_attr"} = $real_attr;
            }
            $TEMPLATE{"$current_attr"} =~ s/$/$line/;
        }
    }
}

__END__


=head1 NAME

B<admin-cgi/zero2one.pl> - convert ROADS v0 multiple databases to ROADS v1
  format

=head1 SYNOPSIS

  admin-cgi/zero2one.pl [-L language] [-C charset]
    [-s sourcedir]
 
=head1 DESCRIPTION

This Perl program converts ROADS version 0 databases into ROADS
version 1 format - i.e. the I<Destination> attribute in the template
is used to indicate which collection of information the record belongs
to, instead of having separate collections of templates for each
database.  As each template is added to the v1 database, the index is
re-built to include it - if this option has been selected on the main
B<zero2one.pl> HTML form.

For security reasons, you need to be HTTP authenticated in order to
run this program.

=head1 OPTIONS

These options are intended for debugging use only.

=over 4

=item B<-L> I<language>

The language to return.

=item B<-C> I<charset>

The character set to use.

=item B<-s> I<sourcedir>

The directory where the version 1 templates should be stored

=back

=head1 CGI VARIABLES

=over 4

=item B<charset>

The character set to use.

=item B<index>

Whether or not to index the database after each template is converted.

=item B<language>

The language to use.

=item B<name>

The database name to put into the I<Destination> field in the newly
created templates.

=item B<source>

The directory in which to find the ROADS version 0 templates.

=back

=head1 FILES

I<config/multilingual/*/zero2one/zerotooneform.html>
- main HTML form returned when running zero2one

I<config/multilingual/*/zero2one/noalltemps.html>
- HTML returned when the I<alltemps> file (list of
template handle to filename mappings) from the ROADS
version 0 installation cannot be opened.

I<config/multilingual/*/zero2one/newopenfailed.html>
- HTML returned when a new template cannot be created
from the old one.

I<config/multilingual/*/zero2one/cannotindex.html>
- HTML returned when the reindexing process fails.

I<config/multilingual/*/zero2one/alldone.html>
- HTML returned when the conversion completes
successfully.

I<logs/ChangeLog> - list of templates converted.

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

