#!/usr/bin/perl
use lib "/home/roads2/lib";

# exterminate.pl - removes templates with persistently unreachable
# URLs from the externally visible database
# 
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: exterminate.pl,v 3.10 1998/08/18 19:31:28 martin Exp $

require ROADS;

chomp(@bad_uns = `$ROADS::Bin/dodgy.pl`);

foreach $bad_un (@bad_uns) {
  $bad_un = "$ROADS::IafaSource/$bad_un" unless $bad_un =~ /\//;

  open(OLDTEMPLATE, "$bad_un")
    || print "$0: couldn't open path to template $bad_un: $!", next;
  
  open(NEWTEMPLATE, ">$bad_un.new")
    || print "$0: couldn't open path to template $bad_un: $!", next;
  
  $seenit = "n";
  while(<OLDTEMPLATE>) {
    chomp;
    next if /^$/;
    next if /^\s+$/;

    if (/^Status:/i) {
      print NEWTEMPLATE "Status: stale\n";
      $seenit = "y";
    } else {
      print NEWTEMPLATE "$_\n";
    }
  }
  if ($seenit eq "n") {  
    print NEWTEMPLATE "Status: stale\n";
  }
  close(OLDTEMPLATE);
  close(NEWTEMPLATE);

  rename "$bad_un.new", "$bad_un";
}

system("$ROADS::Bin/mkinv.pl -a"); # rebuild index
# should also regenerate subject listings et al?
# but - how to know what those are ??

exit 0;
__END__


=head1 NAME

B<bin/exterminate.pl> - remove templates with persistently unreachable URLs

=head1 SYNOPSIS

  bin/exterminate.pl
 
=head1 DESCRIPTION

This Perl program runs another tool in order to discover which
templates have been persistently unreachable.  Each of the resulting
templates is modified so that any existing I<Status> attribute is
stripped out, and a new one introduced:

  Status: stale

Finally, the ROADS server resource description database is reindexed.

The program is intended for invocation from a World-Wide Web CGI
program, a cron job, or an at job.

=head1 OPTIONS

None.

=head1 BUGS

It is assumed that there is only one template per file.

=head1 SEE ALSO

L<admin-cgi/exterminate.pl>

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

