#!/usr/bin/perl
use lib "/home/roads2/lib";

# bogus.pl - flag errors in ROADS installation

# Author: Martin Hamilton martinh@gnu.org
# $Id: bogus.pl,v 3.9 1998/09/05 14:00:05 martin Exp $

require ROADS;

use File::Find;
use Getopt::Std;
getopts("h");

@components = (ROADS::Version, ROADS::Dir, ROADS::MyHostname, 
  ROADS::MyPortNumber, ROADS::TmpDir, ROADS::Bin, ROADS::Lib,
  ROADS::Guts, ROADS::Config, ROADS::AdminCgi, ROADS::CgiBin, ROADS::Logs,
  ROADS::HtDocs, ROADS::IafaSource, ROADS::ServiceName, 
  ROADS::SysAdminEmail, ROADS::DBAdminEmail, ROADS::MailerPath, 
  ROADS::SortPath, ROADS::RCSCiPath, ROADS::Bullet, ROADS::PerlPath);

@directories = (ROADS::AdminCgi, ROADS::Bin, ROADS::Lib, ROADS::Guts, 
  ROADS::Config, ROADS::CgiBin, ROADS::Logs, ROADS::HtDocs, 
  ROADS::IafaSource);

@programs = (ROADS::MailerPath, ROADS::SortPath, ROADS::RCSCiPath,
  ROADS::PerlPath);

@writeable = (ROADS::Logs, ROADS::Guts, ROADS::IafaSource, ROADS::TmpDir);

$phase1 = $phase2 = $phase3 = $phase4 = $total_errors = 0;

if ($opt_h) {
  print <<EOF;
<h1>ROADS sanity check:</h1>

<h2>Phase 1</h2>

Check global variables are present and correct<p>

<pre>
EOF
} else {
  print <<EOF;
ROADS sanity check!

Phase 1 - check global variables are present and correct

EOF
}
 
foreach (@components) {
  unless (defined(${$_})) {
    print "$_: not defined\n";
    $phase1++;
    $total_errors++;
  }
}

print "OK!\n" if $phase1 == 0;

if ($opt_h) {
  print <<EOF;
</pre>
<h2>Phase 2</h2>

Check for existence of directories<p>

<pre>
EOF
} else {
  print <<EOF;

Phase 2 - check for existence of directories

EOF
}

foreach (@directories) {
  unless (-d "${$_}") {
    print "$_ (${$_}): can't find directory\n";
    $phase2++;
    $total_errors++;
  }
  unless (-x "${$_}") {
    print "$_ (${$_}): can't read directory\n";
    $phase2++;
    $total_errors++;
  }
}

print "OK!\n" if $phase2 == 0;

if ($opt_h) {
  print <<EOF;
</pre>
<h2>Phase 3</h2>

Check for existence of external programs<p>

<pre>
EOF
} else {
  print <<EOF;

Phase 3 - check for existence of external programs

EOF
}

foreach (@programs) {
  unless (-f "${$_}") {
    print "$_ (${$_}): can't find\n";
    $phase3++;
    $total_errors++;
  }
  unless (-x "${$_}") {
    print "$_ (${$_}): can't execute\n";
    $phase3++;
    $total_errors++;
  }
}

print "OK!\n" if $phase3 == 0;

if ($opt_h) {
  print <<EOF;
</pre>
<h2>Phase 4</h2>

Check for writeable directories<p>

<pre>
EOF
} else {
  print <<EOF;

Phase 4 - check for writeable directories

EOF
}

foreach (@writeable) {
  unless (-w "${$_}") {
    print "$_ (${$_}): can't write to\n";
    $phase4++;
    $total_errors++;
  }
  find(\&wanted_dir, "${$_}") unless $_ eq $ROADS::TmpDir;
}

print "OK!\n" if $phase4 == 0;

if ($opt_h) {
  print <<EOF;

</pre>
<h2>Done!</h2>
<pre>
EOF
}

if ($total_errors == 0) {
  print "\nDone!\n\n";
} else { 
  print "Totalling errors...\n\n";

  print "Phase 1: $phase1\n" if $phase1 > 0;
  print "Phase 2: $phase2\n" if $phase2 > 0;
  print "Phase 3: $phase3\n" if $phase3 > 0;
  print "Phase 4: $phase4\n" if $phase4 > 0;

  print "Total:   $total_errors\n\n";
}

print "</pre>\n" if $opt_h;
exit;


# used by File::Find
sub wanted { !-w && do {
  print "can't write to $File::Find::name\n";
  $phase4++;
  $total_errors++;
  }
}

__END__


=head1 NAME

B<bin/bogus.pl> - flag possible errors in ROADS installation

=head1 SYNOPSIS

  bin/bogus.pl [-h]
 
=head1 DESCRIPTION

This Perl program tests the following aspects of the ROADS
installation:

=over 4

=item 1.

expected global variables are present and correct

=item 2.

directories which are needed are present

=item 3.

external programs which are needed can be found

=item 4.

directories which should be writeable actually are

=back

Note that the tests may generate different results depending on the
Unix user and group which the program is run under.  If in doubt,
it should be tested with the identity of any admin users who will be
running components of the ROADS package from the command line, and
as with the identities used to run any WWW servers which will have
access to the ROADS server and database.

=head1 OPTIONS

=over 4

=item B<-h>

Generate output in HTML format

=back

=head1 OUTPUT

List of phases, and problem information if any problems found.

=head1 SEE ALSO

L<admin-cgi/bogus.pl>

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

Martin Hamilton E<lt>martinh@gnu.orgE<gt>

