#!/usr/bin/perl
use lib "/home/roads2/lib";

#
# rebuild.pl - rebuild database index, subject/what's new listings, ...
#              incorporating any offline template updates
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#         Martin Hamilton <martinh@gnu.org>
# $Id: rebuild.pl,v 3.4 1998/09/10 17:19:15 jon Exp $

use Getopt::Std;

require ROADS;
use ROADS::ErrorLogging;
use ROADS::ReadTemplate;

getopts('adps:t:S:W:');

$debug = $opt_d || 0;

# IAFA template source directory
$IafaSource = $opt_s || "$ROADS::IafaSource";

# Inverted index directory
$IndexDir = $opt_t || "$ROADS::IndexDir";

# Whether to make the Subject Listings
$slview = $opt_S || "";

# Whether to make the Whats New listing
$wnview = $opt_W || "";

# Start up a lock to stop mktemp.pl's sniffing about (and to
# keep us out if there's already someone doing something).
open(MKTEMPLOCK,">>$ROADS::Guts/mktemp.lock");
flock(MKTEMPLOCK,2);

%ALLTEMPS = &readalltemps;

if ($opt_p) {
    chop(@ARGV = `cd $ROADS::Guts/pending && ls`);
} 
$Handles = join ' ', @ARGV;

# Move pending templates into ROADS template area
if ($opt_p) {
    foreach $Handle (@ARGV) {
        warn "doing $Handle\n" if $debug;
        $res = system("$ROADS::MvPath", "$ROADS::Guts/pending/$Handle",
	         "$IafaSource/$Handle");

        if ($res != 0) {
            flock(MKTEMPLOCK,8);
            close(MKTEMPLOCK);
            unlink("$ROADS::Guts/mktemp.lock");
            &WriteToErrorLog("rebuild", "Cannot replace $Handle");
        }

        chmod 0644, "$IafaSource/$Handle";
    }
}

foreach $Handle (@ARGV) {
    # If this was an old template being updated
    if ($ALLTEMPS{"$Handle"}) {
        if ($ROADS::ExtDBDel ne "") {
	    $ENV{"HANDLE"} = $Handle;
	    $ENV{"IAFAFILE"} = "$IafaSource/$Handle";
	    $res=system("$ROADS::ExtDBDel");
        } else {
	    $res=system("$ROADS::Bin/deindex.pl", "-s", $IafaSource,
		        "-i", $IndexDir, $Handles);
        }
    
        if ($res != 0) {
	    flock(MKTEMPLOCK,8);
	    close(MKTEMPLOCK);
	    unlink("$ROADS::Guts/mktemp.lock");
	    &WriteToErrorLog("rebuild", "Cannot deindex $Handles");
	    exit 1;
        }
    }
}

chdir("$IafaSource");

# Rebuild database
if ($ROADS::ExtDBAdd ne "") {
    $ENV{"HANDLE"} = $Handles;
    $ENV{"IAFAFILE"} = "$IafaSource/$Handles";
    $res=system("$ROADS::ExtDBAdd");
} else {
    if ($opt_a) {
        $res=system("$ROADS::Bin/mkinv.pl -a");
    } else {
        $res=system("$ROADS::Bin/mkinv.pl $Handles");
    }

    if ($res != 0) {
        flock(MKTEMPLOCK,8);
        close(MKTEMPLOCK);
        unlink("$ROADS::Guts/mktemp.lock");
        &WriteToErrorLog("rebuild", "Cannot index $Handles");    
        exit 1;    
    }
}

# Add the template to subject lists if required
if ($slview) {
    $arg = "-s $IafaSource -n '$ROADS::ServiceName' -l $slview";
    if ($opt_a) {
        $res=system("$ROADS::Bin/addsl.pl $arg -a -i");
    } else {
        $res=system("$ROADS::Bin/addsl.pl $arg -i $Handles");
    }

    if ($res != 0) {
        flock(MKTEMPLOCK,8);
        close(MKTEMPLOCK);
        unlink("$ROADS::Guts/mktemp.lock");
        &WriteToErrorLog("rebuild",
          "Cannot build subject listing for $Handles");    
        exit 1;    
    }
}

# Add the template to the what's new list if required
if ($wnview) {
    $arg="-s $IafaSource -n '$ROADS::ServiceName' -w $wnview -r";
    if ($opt_a) {
      $res=system("$ROADS::Bin/addwn.pl -ar");
    } else {
      $res=system("$ROADS::Bin/addwn.pl -r $Handles");
    }

    if ($res != 0) {
        flock(MKTEMPLOCK,8);
        close(MKTEMPLOCK);
        unlink("$ROADS::Guts/mktemp.lock");
        &WriteToErrorLog("rebuild",
          "Cannot build what's new list for $Handles");    
        exit 1;    
    }
}    

# Close the lock on mktemp.pl's
flock(MKTEMPLOCK,8);
close(MKTEMPLOCK);
   
exit;
__END__


=head1 NAME

B<bin/rebuild.pl> - rebuild ROADS index, subject/what's new listings

=head1 SYNOPSIS

  rebuild.pl [-adp] [-s source_dir] [-t index_dir]
    [-S subject_listing_view] [-W whats_new_view]
    [handle1 handle2 ... handleN]

=head1 DESCRIPTION

To allow the indexing and addition to the subject lists and whats new
files to take place, the B<bin/rebuild.pl> program must have access to
the B<bin/deindex.pl>, B<bin/mkinv.pl>, B<bin/addsl.pl>,
B<bin/addwn.pl> scripts.

=head1 OPTIONS

=over 4

=item B<-a>

Index all templates rather than just specified handles.

=item B<-d>

Turn on debugging mode.

=item B<-p>

Incorporate templates stored in holding area, normally I<guts/pending>.

=item B<-s> I<source_dir>

Set template source directory.

=item B<-t> I<index_dir>

Set template index directory.

=item B<-S> I<subject_listing_view>

Set the subject listing view to use.

=item B<-W> I<whats_new_view>

Set the "What's New" view to use.

=back

=head1 FILES

I<config/subject-listing> - subject listing views.

I<config/whats-new> - "What's New" views.

I<guts/pending> - holding area for templates created using the
offline mode in the template editor.

I<guts/index*> - index files.

I<source> - templates themselves.

=head1 SEE ALSO

L<bin/addsl.pl>, L<bin/addwn.pl>, L<bin/deindex.pl>, L<bin/mkinv.pl>,

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
