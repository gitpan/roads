#!/usr/bin/perl
use lib "/home/roads2/lib";

# bg_exterminate.pl - background reindexing to remove stale templates
# 
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: bg_exterminate.pl,v 3.8 1998/08/18 19:31:28 martin Exp $

require ROADS;
use ROADS::ErrorLogging;

system("$ROADS::Bin/exterminate.pl");

open(OUT, "|$ROADS::MailerPath -s 'background reindexing finished' $ROADS::DBAdminEmail $ROADS::SysAdminEmail")
  || &WriteToErrorLogAndDie("bg_exterminate",
       "couldn't open pipe to $ROADS::MailerPath: $!");
print OUT "Run ended!\n";
close(OUT);

exit 0;
__END__


=head1 NAME

B<bin/bg_exterminate.pl> - background reindexing to remove stale templates

=head1 SYNOPSIS

  bin/bg_exterminate.pl
  
=head1 DESCRIPTION

This Perl program launches a process to remove stale templates from
a ROADS server database.  On completion it sends email to the server's
system admin and database admin contacts.

It is intended for invocation from a World-Wide Web CGI program, a
cron job, or an at job.

=head1 OPTIONS

None.

=head1 OUTPUT

Mail to server maintainers.

=head1 SEE ALSO

L<bin/exterminate.pl>

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

