#!/usr/bin/perl
use lib "/home/roads2/lib";

# deindex.pl - WWW front end to the deindex.pl program
#
# Authors: Jon Knight <jon@net.lut.ac.uk>
#          Martin Hamilton <martinh@gnu.org>
# $Id: deindex.pl,v 3.14 1998/08/18 19:24:45 martin Exp $

# Fix for stupid Netscape server bug/misfeature
close(STDERR) if $ENV{"SERVER_NAME"} =~ /netscape/i;

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;

use Getopt::Std;
getopts('du:');

# The URL of this program
$myurl = $opt_u || "/$ROADS::WWWAdminCgi/deindex.pl";

# Print out the HTTP Content-type header and then cleave the CGI URL into
# an associative array ready for use.
print "Content-type: text/html\n\n";
&cleaveargs;
# Debugging
$debug = $CGIvar{debug} || $opt_d;

unless ($ENV{QUERY_STRING}) {
    print <<"EndOfHTML";
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Deindex selected templates</TITLE>
</HEAD>
<BODY>
<H1>Deindex selected templates</H1>

<P>
This form allows you to remove index entries for templates which are
deemed to be <EM>stale</EM> or otherwise incorrect.  In fact, the
templates are not physically removed, but archived under the template
directory as <EM>.archive/&lt;handle&gt;</EM> - just in case you need
them back again.
</P>

<P>
If you have the GNU Revision Control System (RCS) installed, the
templates will be checked in to RCS.  This provides a finer grain of
control over versioning, since the <EM>.archive</EM> directory will
only contain the last instance of each template with the handles in
question.
</P>

<P>
Note that the process may not complete immediately, because the ROADS
database index has to be reconstructed.  If this is taking a long
time, use the template editor's offline update mode and run a (say)
nightly database reindex from <EM>cron</EM>.
</P>
<HR>
<FORM ACTION="$myurl" METHOD="GET">
Template handles:<BR>
<TEXTAREA NAME="handles" ROWS="6" COLS="40">$CGIvar{handletobedeleted}</TEXTAREA><BR>
<INPUT TYPE="submit" VALUE="Deindex">
</FORM>
<HR>
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EndOfHTML
    exit;
}

# Deindex the templates with the handles specified.
($handles = $CGIvar{handles}) =~ tr/a-zA-Z0-9\-/ /c;
# Check authorisation (if possible)
if($ENV{AUTH_TYPE} ne "") {
  # Pickup the remote user name and authentication type.
  $remoteuser = $ENV{REMOTE_USER};
 
  # Open the DBM database.
  dbmopen(TempAuth,"$ROADS::Config/template_users", 0644);

  # Check each handle.  Only bother with authentication if there is actually
  # an entry in the DBM file for this template.
  foreach $handle (split(/\s+/,$handles)){
    if(defined($TempAuth{$handle})) {
      $matched = 0;
      foreach $user (split(" ",$TempAuth{$handle})) {
        $matched = 1 if($user eq $remoteuser);
        break if($matched == 1);
      }
      if($matched == 0) {
        $notdeindex = $notdeindex ? "$notdeindex $handle" : $handle;
      } else {
        $deindexlist = $deindexlist ? "$deindexlist $handle" : $handle;
      }
    } else {
      $deindexlist = $deindexlist ? "$deindexlist $handle" : $handle;
    }
    dbmclose(TempAuth);
  }
 
  $handles = $deindexlist;
}

$ENV{PATH} .= "$ENV{PATH}:${ROADS::Bin}";
$cmd = "$ROADS::Bin/deindex.pl " . ($debug ? "-d" : "") . " $handles";
system($cmd);
$status = $?;

print <<"EndOfHTML";
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
<HEAD>
<TITLE>Deindexing specified templates</TITLE>
</HEAD>
<BODY>
<H1>Deindexing specified templates</H1>
<P>
The requested templates <EM>$handles</EM> have
EndOfHTML

if ($status eq 0) {
    print STDOUT "been removed from the inverted index.\n";
} else {
    print STDOUT "<STRONG>NOT</STRONG> been removed from the inverted index.\n";
    print STDOUT "Consult the error log to find out why.\n";
}

if($notdeindex ne "") {
  print STDOUT "<P>The templates with handles <em>$notdeindex</em> have ".
    "<strong>NOT</strong> been removed from the inverted index as you ".
    "are not authorised to deindex them.</P>"
}

print <<"EndOfHTML";
</P>
<HR> 
[<A HREF="/$ROADS::WWWAdminCgi/admincentre.pl">ROADS Admin Centre</A>]
</BODY>
</HTML>
EndOfHTML

exit;
__END__


=head1 NAME

B<admin-cgi/deindex.pl> - WWW front end to ROADS template deindexing

=head1 SYNOPSIS

  admin-cgi/deindex.pl [-d] [-u url]
 
=head1 DESCRIPTION

This Perl program runs B<bin/deindex.pl> in the background to remove
nominated templates from the ROADS database index.  It is intended for
use when templates are deemed to be "stale" and should be removed from
public view.

An HTML form is generated, and the user is asked to indicate which
records should be deindexed.

=head1 OPTIONS

These options are intended only for debugging use.

=over 4

=item B<-d>

Generate debugging information

=item B<-u> I<myurl>

The URL of this program, default is I</admin-cgi/deindex.pl>.

=back

=head1 CGI VARIABLES

These variables are created by the HTML form built in to the
B<deindex.pl> program.  They could also be supplied if the program was
called from somewhere else, bypassing the form.  The built-in form
will only be returned if the CGI query string is empty.

=over 4

=item B<debug>

Boolean variable to turn on debugging output.

=item B<handles>

List of handles to be deleted.

=item B<handletobedeleted>

Name of handle to be deleted.

=back

=head1 SEE ALSO

L<bin/deindex.pl>

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

