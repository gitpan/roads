#!/usr/bin/perl
use lib "/home/roads2/lib";

# mktemp-config-editor.pl
#
# Author: Jon Knight <jon@net.lut.ac.uk>
# $Id: mktemp-config-editor.pl,v 1.10 1998/08/18 19:24:45 martin Exp $

require ROADS;
use ROADS::Auth;
use ROADS::CGIvars;
use ROADS::ErrorLogging;
use ROADS::HTMLOut;

use Getopt::Std;
getopts("C:L:");

# What language to return
$Language = $opt_L || "en-uk";

# What character set to use.
$CharSet = $opt_C || "ISO-8859-1";

# Set what my URL is.
$myurl = "/$ROADS::WWWAdminCgi/mktemp-config-editor.pl";

# Print out the HTTP Content-type header and then cleave the CGI URL into
# an associative array ready for use.
&CheckUserAuth("admin_users");
print STDOUT "Content-type: text/html\n\n";
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

# If the templatetype CGI attribute isn't present then we must squirt out
# the introductory FORM for the user and then exit.
if (length($ENV{"QUERY_STRING"}) == 0) {
    if(!open(CONFIG,"$ROADS::Config/mktemp.cfg")) {
      &OutputHTML("mktemp-config-editor","openconfigerror.html",
        $Language,$CharSet);
      &WriteToErrorLogAndDie("mktemp-config-editor",
        "Can't open '$ROADS::Config/mktemp.cfg' file: $!");
    }
    &OutputHTML("mktemp-config-editor","introhead.html",$Language,$CharSet);
    $usercount = 0;
    while(<CONFIG>) {
      chomp;
      next if!(/^\[tipsperms\]/i);
      $UserList = "";
      $GenerateListing = "";
      $GenerateWhatsNew = "";
      $ReturnTemplate = "";
      $EmailTemplate = "";
      $EnterTemplate = "";
      $Offlinemode  = "";
      while(<CONFIG>) {
        next if(/^#/);
        last if($_ eq "\n");
        chomp;
        if(/\s*UserList\s*=\s*(.*)/) {
          $UserList .= $1;
        }
        if(/GenerateListing/i) {
          $GenerateListing = "checked";
        }
        if(/GenerateWhatsNew/i) {
          $GenerateWhatsNew = "checked";
        }
        if(/OfflineMode/i) {
          $OfflineMode = "checked";
        }
        if(/ReturnTemplate/i) {
          $ReturnTemplate = "checked";
        }
        if(/EmailTemplate/i) {
          $EmailTemplate = "checked";
        }
        if(/EnterTemplate/i) {
          $EnterTemplate = "checked";
        }
      }
      print STDOUT <<"EndOfHTML";
<HR>
Include: <INPUT TYPE="checkbox" NAME="include$usercount" VALUE="yes" CHECKED><BR>
User List:
<INPUT TYPE="text" NAME="UserList$usercount" VALUE="$UserList"><BR>
Allow generation of Subject Listing:
<INPUT TYPE="checkbox" NAME="GenerateListing$usercount" VALUE="yes" $GenerateListing><BR>
Allow generation of Whats New:
<INPUT TYPE="checkbox" NAME="GenerateWhatsNew$usercount" VALUE="yes" $GenerateWhatsNew><BR>
Allow offline entry of templates:
<INPUT TYPE="checkbox" NAME="OfflineMode$usercount" VALUE="yes" $OfflineMode><BR>
Allow returning of templates to user:
<INPUT TYPE="checkbox" NAME="ReturnTemplate$usercount" VALUE="yes" $ReturnTemplate><BR>
Allow emailing of templates to admin:
<INPUT TYPE="checkbox" NAME="EmailTemplate$usercount" VALUE="yes" $EmailTemplate><BR>
Allow entering of templates into database:
<INPUT TYPE="checkbox" NAME="EnterTemplate$usercount" VALUE="yes" $EnterTemplate><BR>
EndOfHTML
       $usercount++;
    }
    print STDOUT <<"EndOfHTML";
<HR>
Include: <INPUT TYPE="checkbox" NAME="include$usercount" VALUE="yes" ><BR>
User List:
<INPUT TYPE="text" NAME="UserList$usercount" VALUE=""><BR>
Allow generation of Subject Listing:
<INPUT TYPE="checkbox" NAME="GenerateListing$usercount" VALUE="yes"><BR>
Allow generation of Whats New:
<INPUT TYPE="checkbox" NAME="GenerateWhatsNew$usercount" VALUE="yes"><BR>
Allow offline entry of templates:
<INPUT TYPE="checkbox" NAME="OfflineMode$usercount" VALUE="yes"><BR>
Allow returning of templates to user:
<INPUT TYPE="checkbox" NAME="ReturnTemplate$usercount" VALUE="yes"><BR>
Allow emailing of templates to admin:
<INPUT TYPE="checkbox" NAME="EmailTemplate$usercount" VALUE="yes"><BR>
Allow entering of templates into database:
<INPUT TYPE="checkbox" NAME="EnterTemplate$usercount" VALUE="yes"><BR>
EndOfHTML
    $usercount++;
    print STDOUT <<"EndOfHTML";
<INPUT TYPE="hidden" NAME="tipscount" VALUE=$usercount">
EndOfHTML
    &OutputHTML("mktemp-config-editor","introtail.html",$Language,$CharSet);
    exit;
}

# Grab the maximum possible number of users
$usercount = $CGIvar{tipscount};

if(!open(CONFIG,"$ROADS::Config/mktemp.cfg")) {
  &OutputHTML("mktemp-config-editor","openconfigerror.html",
    $Language,$CharSet);
  &WriteToErrorLogAndDie("mktemp-config-editor",
    "Can't open '$ROADS::Config/mktemp.cfg' file: $!");
}

$tmpfile = "$ROADS::TmpDir/mktemp.cfg.$$";
if(!open(NEWCFG,">$tmpfile")) {
  &OutputHTML("mktemp-config-editor","opentmpfileerror.html",
    $Language,$CharSet);
  &WriteToErrorLogAndDie("mktemp-config-editor",
    "Can't write to tmp file '$tmpfile': $!");
}

$OutputTIPSperms = 0;
while(<CONFIG>) {
  chomp;
  if(/^\[tipsperms\]/i) {
    $UserList = "";
    $GenerateListing = "";
    $GenerateWhatsNew = "";
    $OfflineMode = "";
    $ReturnTemplate = "";
    $EmailTemplate = "";
    $EnterTemplate = "";
    while(<CONFIG>) {
      if(/^#/) {
        print NEWCFG "$_";
        next;
      }
      last if($_ eq "\n");
    }
    next if($OutputTIPSperms);
    $total = $CGIvar{tipscount};
    for($iteration = 0; $iteration < $total; $iteration++){
      next if($CGIvar{"include$iteration"} ne "yes");
      print NEWCFG "[tipsperms]\n";
      print NEWCFG "UserList = " . $CGIvar{"UserList$iteration"} . "\n";
      print NEWCFG "GenerateListing = "
        . $CGIvar{"GenerateListing$iteration"} . "\n"
        if($CGIvar{"GenerateListing$iteration"} eq "yes");
      print NEWCFG "GenerateWhatsNew = "
        . $CGIvar{"GenerateWhatsNew$iteration"} . "\n"
        if($CGIvar{"GenerateWhatsNew$iteration"} eq "yes");
      print NEWCFG "OfflineMode = "
        . $CGIvar{"OfflineMode$iteration"} . "\n"
        if($CGIvar{"OfflineMode$iteration"} eq "yes");
      print NEWCFG "ReturnTemplate = "
        . $CGIvar{"ReturnTemplate$iteration"} . "\n"
        if($CGIvar{"ReturnTemplate$iteration"} eq "yes");
      print NEWCFG "EmailTemplate = "
        . $CGIvar{"EmailTemplate$iteration"} . "\n"
        if($CGIvar{"EmailTemplate$iteration"} eq "yes");
      print NEWCFG "EnterTemplate = "
        . $CGIvar{"EnterTemplate$iteration"} . "\n"
        if($CGIvar{"EnterTemplate$iteration"} eq "yes");
      print NEWCFG "\n";
    }
    $OutputTIPSperms=1;
  } else {
    print NEWCFG "$_\n";
  }
}
close(CONFIG);
close(NEWCFG);
rename("$ROADS::Config/mktemp.cfg", "$ROADS::Config/mktemp.cfg.FCS");
system($ROADS::CpPath, $tmpfile, "$ROADS::Config/mktemp.cfg");
unlink("$tmpfile") unless($debug);
&OutputHTML("mktemp-config-editor","updated.html",$Language,$CharSet);

exit;
__END__


=head1 NAME

B<admin-cgi/mktemp-config-editor.pl> - ROADS template editor configurator

=head1 SYNOPSIS

  admin-cgi/mktmep-config-editor.pl [-C charset] [-L language]
 
=head1 DESCRIPTION

This Perl program provides a WWW based mechanism for controlling the
ROADS template editor (B<mktemp.pl>) features which are available to a
particular user.

=head1 OPTIONS

These are intended for debugging purposes only.

=over 4

=item B<-C> I<charset>

Character set to use.

=item B<-L> I<language>

Language to use.

=back

=head1 CGI VARIABLES

Where there is an instance number I<N>, this applies to a particular
instance of the template editor configuration, in other words, the
permissions which are allowed for a particular user.

=over 4

=item B<charset>

The character set to use.

=item B<EmailTemplate>I<N>

Whether the user is allowed to email the completed template to the
ROADS database administrator.

=item B<EnterTemplate>I<N>

Whether the user is allowed to enter the completed template into the
ROADS database.

=item B<GenerateListing>I<N>

Whether the user is allowed to generate subject breakdowns using the
B<addsl.pl> program.

=item B<GenerateWhatsNew>I<N>

Whether the user is allowed to generate "What's New" listings using
the B<addwn.pl> program.

=item B<include>I<N>

Whether to include this user's details.

=item B<language>

The language to use.

=item B<tipscount>

Number of users in template editor config.

=item B<ReturnTemplate>I<N>

Whether the user is allowed to select the "return template" option,
which causes the template to be returned as a WWW page.

=item B<UserList>I<N>

Which users this rule applies to, e.g. I<*> applies to all users,
whereas I<martin@multics.lut.ac.uk> applies to the user I<martin> on
the machine I<multics.lut.ac.uk>.

=back

=head1 FILES

I<config/mktemp.cfg> - template editor configuration file

I<config/multilingual/*/mktemp-config-editor/introhead.html>
- head of HTML form returned to end user

I<config/multilingual/*/mktemp-config-editor/introtail.html>
- tail of HTML form returned to end user

I<config/multilingual/*/mktemp-config-editor/openconfigerror.html>
- HTML returned if config file couldn't be opened

I<config/multilingual/*/mktemp-config-editor/updated.html>
- HTML returned if template editor config was updated OK.

=head1 SEE ALSO

L<admin-cgi/mktemp.pl>

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

