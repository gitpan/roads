#!/usr/bin/perl
use lib "/home/roads2/lib";

# Id: mail_owners.pl, Thu Dec 14 10:12:45 1995, mattias@munin.ub2.lu.se
# =====================================================================
# Takes a list of: <HTTP-RC> <file> <URL> on STDIN. Either uses a
# prepared table of maintainers for certain parts of your local webtree
# or uses stat to get the uid on files - the choice is yours.
# This collected data of 'failure-URLs' are then mailed to each of
# the file/page maintainers, iff there are bad URLs on their pages.
# Hopefully, these users will then take the appropriate actions.... :)
# =====================================================================
# Hacked over by Martin Hamilton <martinh@gnu.org> !
# $Id: mail_owners.pl,v 3.7 1998/08/18 19:31:28 martin Exp $

use HTTP::Status;
use Getopt::Std;

getopts("dm:t:");

require ROADS;

# Set to 0 if you'd rather stat files for uid.
$USE_OWNERSHIP_TABLE = $opt_t ? 1 : 0; 
$owner_table = $opt_t || "$ROADS::Config/ownership.tbl";
$mail_template = $opt_m || "$ROADS::Config/mailtemplate.txt";
$debug = $opt_d || 0;


# =====================================================================
# Main code starts here

if ($USE_OWNERSHIP_TABLE) {
    &read_ownership;
    $get_name = \&get_name_table;
} else {
    while(($name, $passwd, $uid) = getpwent) {
	$name{$uid} = $name;
    }
    $get_name = \&get_name_uid;
}

while(<>) {
    next if /^OK/;
    /(\w+)\s+([\w\/\.]+)\s([\w\/\:\.\%\-]+)/;
    $rc = $1; $file = $2; $url = $3;
    if ($rc =~ /\d+/) {
	$rc_txt = statusMessage($rc);
    } elsif ($rc =~ /BAD/) {
	$rc_txt = "Already checked (from another file)";
    } else { next; }

    $name = &$get_name($file);
    push(@mail_list, "$name\nFile: $file\nURL:  $url\n$rc, $rc_txt");
}

for (@mail_list) { print "$_\n" if $debug; }

sort(@mail_list);

$message = &new_message;
$mail_list[0] =~ /^(\w+)\n/;
$recipient = $1; $message .= "$'\n\n";

for($j = 1; $j < scalar(@mail_list); $j++) {
    $mail_list[$j] =~ /^(\w+)\n/;
    if ($1 ne $recipient) {
	&send_message($recipient, $message);
	$message = &new_message;
	$recipient = $1; 
    }
    $message .= "$'\n\n";
}
# The last mail has to fly separatly....
&send_message($recipient, $message);


# =====================================================================
# =====================================================================
# Subs

sub get_name_table {
    local($file) = @_;
    local($file_dir, $name);

    for (@ownership) {
	/([\w\/]+)\s+(\w+)/;
	$fs_part = $1; $name = $2;
	last if $file =~ /$fs_part/;
    }

    $name;
}


sub get_name_uid {
    local($file) = @_;
    local($uid, $name, @stat_data);

    @stat_data = stat($file);
    $uid = $stat_data[4];
    $name = $name{$uid};
}


sub read_ownership {
    open(FILE, "<$owner_table");
    while(<FILE>) { push(@ownership, $_) unless /^#/; }
    close(FILE);
}


sub new_message {
    local($buf, $mtemp);

    open(FILE, "<$mail_template");
    while(read(FILE, $buf, 16384)) {
	$mtemp .= $buf;
    }
    close(FILE);

    $mtemp;
}


sub send_message {
    local($to, $mtext) = @_;

    print "Mail to: $to\n" if $debug;

    open(MAIL, "| $ROADS::MailerPath $to") || die "$0: Couldn't mail to: $to";
    print MAIL "$mtext";
}

exit;
__END__


=head1 NAME

B<bin/mail_owners.pl> - send mail to people whose links have gone stale

=head1 SYNOPSIS

  bin/mail_owners.pl [-d] [-m mailtemplate] [-t ownertable]
 
=head1 DESCRIPTION

This Perl program takes the results of the link checking tool and uses
either a prepared table of maintainers for the various parts of the
filesystem or I<stat> to find out who is responsible for bad URLs.

This collected data of failed URLs is then mailed to each of these
maintainers, if and only if there are bad URLs on their pages.
Hopefully, these users will then take the appropriate actions.... :)

It is suitable for invocation from a World-Wide Web CGI program, a
cron job, or an at job.

=head1 OPTIONS

=over 4

=item B<-d>

Generate debugging information

=item B<-m> I<mailtemplate>

Form letter to be sent to all those whose links are stale

=item B<-t> I<ownertable>

This file indicates who is responsible for a given file or hierarchy
of files, and this information will be used to determine who to send
the link checker report to.  If it is not specified, the user name of
the person who owns the file will be used as the contact address
instead.

=back

=head1 INPUT FORMAT

Link checker summary report in the format

  <HTTP-RC> <file> <URL>

e.g.

  200 /home/roads/source/SOSIG106 gopher://nisp.ncl.ac.uk:70/

Where HTTP-RC is the HTTP (or equivalent) response code for the
request.  Non-HTTP response codes will have been translated into
HTTP style response codes before the link checker report is
dumped out.

=head1 OUTPUT FORMAT

Warning messages to information providers.

=head1 BUGS

This is really geared up to WWW server maintainers, rather than ROADS
server maintainers.  It should have a way of extracting the contact
address from the templates if desired.

=head1 SEE ALSO

L<bin/lc.pl>

=head1 COPYRIGHT

Copyright (c) 1988, Mattias Borrell E<lt>mattias@munin.ub2.lu.seE<gt>.
All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

It was developed by Lund University NetLab, as part of the DESIRE
project.  DESIRE is funded under the European Commission Telematics
for Research Programme.

=head1 AUTHOR

Mattias Borrell E<lt>mattias@munin.ub2.lu.seE<gt>

