#!/usr/bin/perl
use lib "/home/roads2/lib";

# dup_urls.pl - check IAFA templates for duplicate URLs

# Martin Hamilton <martinh@gnu.org>
# $Id: dup_urls.pl,v 3.11 1998/08/18 19:31:28 martin Exp $

use Getopt::Std;
getopts('ads:');

require ROADS;
use ROADS::ErrorLogging;

$debug = $opt_d || 0;
$SOURCEDIR = $opt_s || "$ROADS::IafaSource";

$debug && print STDERR ">> SOURCEDIR: $SOURCEDIR\n";

if ($opt_a) {
  opendir(ALLFILES, "$SOURCEDIR")
    || &WriteToErrorLogAndDie("dup_urls",
         "Can't open $SOURCEDIR directory: $!");
  @FILES = readdir(ALLFILES);
  closedir(ALLFILES);
  -d "$SOURCEDIR" && chdir "$SOURCEDIR";
} else {
  @FILES = @ARGV;
}

foreach $template (@FILES) {
  next if $template =~ /^\./;

  $debug && print STDERR ">> inspecting ... $template\n";

  unless (open(IN, "$template")) {
    print "Can't open template $template: $!";
    next;
  }

  while(<IN>) {
    chomp;
  
    s/\t/ /g;
    s/\s+/ /g;

    /^handle:\s+(.*)/i && ($handle=$1); 

    next if /:(\s+|)$/;
    next unless (/^ur[il]:\s+(.*)/i || /^ur[il]-v\d+:\s+(.*)/i);

    $url = $1;

    next if $SEEN{"$url"}{"$handle"};

    $SEEN{"$url"}{"$handle"} = "y";

    if ($COUNT{"$url"}) {
      $COUNT{"$url"} += 1;
    } else {
      $COUNT{"$url"} = 1;
    }
  }
  close (IN);
}

foreach $url (keys %COUNT) {
  if ($COUNT{"$url"} > 1) {
    print "$url: ", join(" ", keys %{ $SEEN{"$url"} }), "\n";
  }
}

exit;
__END__


=head1 NAME

B<bin/dup_urls.pl> - check for duplicate URLs in a collection of IAFA templates

=head1 SYNOPSIS

  bin/dup_urls.pl [-ad] [-s sourcedir] [file1 file2 ... fileN]

=head1 DESCRIPTION

This program looks for duplicate URLs in IAFA templates, such as may
be found on a ROADS server.

B<dup_urls.pl> produces a report listing any duplicate URLs it comes
across, and the handle names of the templates in which they are found.

=head1 OPTIONS

B<dup_urls.pl> takes the following arguments:

=over 4 

=item B<-a>

This argument indicates that all of the templates in the given source
directory should be processed.

=item B<-d>

If this argument is given, debugging information will be dumped to
the standard error output stream

=item B<-s> I<sourcedir>

This argument can be used to override the default template source
directory, which is where B<dup_urls.pl> looks for IAFA templates to
check.

=back

=head1 SEE ALSO

L<admin-cgi/dup_urls.pl>

=head1 COPYRIGHT

Copyright (c) 1988, Martin Hamilton E<lt>martinh@gnu.orgE<gt> and Jon
Knight E<lt>jon@net.lut.ac.ukE<gt>.  All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

It was developed by the Department of Computer Studies at Loughborough
University of Technology, as part of the ROADS project.  ROADS is funded
under the UK Electronic Libraries Programme (eLib), the European
Commission Telematics for Research Programme, and the TERENA
development programme.

=head1 AUTHOR

Martin Hamilton E<lt>martinh@gnu.orgE<gt>

