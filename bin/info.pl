#!/usr/bin/perl
use lib "/home/roads2/lib";

require ROADS;

print "\nConfiguration information:\n";
print `cat $ROADS::Lib/ROADS.pm`;

# let's NOT do this!
#print "\nProgram versions:\n";
#print `grep '\$Id' $ROADS::Bin/* $ROADS::AdminCgi/*.pl $ROADS::CgiBin/*.pl $ROADS::Lib/*.pl`;

print "\nMachine info:\n";
print `uname -a`;
exit;
__END__


=head1 NAME

B<bin/info.pl> - display information about the ROADS server installation

=head1 SYNOPSIS

  bin/info.pl

=head1 DESCRIPTION

This Perl program scans the ROADS installation for the following
information:

=over 4

=item 1.

Settings made during the software installation/configuration.

=item 2.

Operating system and hardware architecture information for the
computer the ROADS software is running on.

=back

It is intended for invocation from a World-Wide Web CGI program, a
I<cron> job, or an I<at> job.  Another of the ROADS tools provides an
automated server registration feature using this information, and of
course the ROADS server maintainer is free to configure their server
so as to allow access to as they see fit.

=head1 OPTIONS

None.

=head1 OUTPUT

The contents of I<ROADS.pm> from the ROADS library directory, and the
result of doing a B<uname -a>.

=head1 SEE ALSO

L<admin-cgi/info.pl>

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


