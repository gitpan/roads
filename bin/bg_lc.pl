#!/usr/bin/perl
use lib "/home/roads2/lib";

# bg_lc.pl - background link checking run for WWW or cron
# 
# Author: Martin Hamilton <martinh@gnu.org>
# $Id: bg_lc.pl,v 3.8 1998/08/18 19:31:28 martin Exp $

require ROADS;
use ROADS::ErrorLogging;

if (defined($ROADS::ProxyServer) && $ROADS::ProxyServer ne "none") {
  system("$ROADS::Bin/lc.pl -a -p $ROADS::ProxyServer >$ROADS::Logs/lc");
} else {
  system("$ROADS::Bin/lc.pl -a >$ROADS::Logs/lc");
}

open(OUT, "|$ROADS::MailerPath -s 'link checker run completed' $ROADS::DBAdminEmail $ROADS::SysAdminEmail")
  || &WriteToErrorLogAndDie("bg_lc",
       "couldn't open pipe to $ROADS::MailerPath: $!");

print OUT "Run ended\n";
print OUT "Report left in $ROADS::Logs/lc\n";

close(OUT);

exit 0;
__END__


=head1 NAME

B<bin/bg_lc.pl> - background link checking run for WWW or cron

=head1 SYNOPSIS

  bin/bg_lc.pl
  
=head1 DESCRIPTION

This Perl program launches a process to check the validity of the links
(URLs) in a ROADS server database.  On completion it sends email to the
server's system admin and database admin contacts.

It is intended for invocation from a World-Wide Web CGI program, a cron
job, or an at job.

=head1 OPTIONS

None.

=head1 OUTPUT

Mail to server maintainers.  Link check log file left in I<logs/lc>.

=head1 SEE ALSO

L<bin/lc.pl>

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

