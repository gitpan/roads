#
# ROADS::ErrorLogging - Routines to deal with the ROADS error/admin logs
#
# Authors: Jon Knight <jon@net.lut.ac.uk>
#          Martin Hamilton <martinh@gnu.org>
# $Id: ErrorLogging.pm,v 3.12 1998/12/01 17:59:05 jon Exp $
#

package ROADS::ErrorLogging;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(WriteToErrorLog WriteToErrorLogAndDie WriteToAdminLog);

sub WriteToErrorLog {
    local($program,$message) = @_;
    local($date,$month,$day,@now);

    @now = gmtime(time);
    $month = (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$now[4]];
    $year = $now[5];
    $year += 1900;
    $day = (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$now[6]];
    $date = sprintf("%s %s %s %02d:%02d:%02d %4.4d",
      $day, $month, $now[3], $now[2], $now[1], $now[0], $year);

    open(ERRLOG,">>$ROADS::Logs/errors") || return(-1);
    flock(ERRLOG,2);
    print ERRLOG "[$date] $program: $message\n";
    flock(ERRLOG,8);
    close(ERRLOG);
    return(0);
}

sub WriteToErrorLogAndDie {
    local($program,$message) = @_;
    local($date,$month,$day,@now);

    @now = gmtime(time);
    $month = (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$now[4]];
    $year = $now[5];
    $year += 1900;
    $day = (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$now[6]];
    $date = sprintf("%s %s %s %02d:%02d:%02d %4.4d",
      $day, $month, $now[3], $now[2], $now[1], $now[0], $year);

    # don't send the error message to STDERR if we're running as a
    # CGI program, or in harness to one
    unless ($ENV{"GATEWAY_INTERFACE"}) {
        warn "$program: $message (FATAL)\n"; 
    }

    # always try to log to file
    open(ERRLOG,">>$ROADS::Logs/errors") || exit(-1);
    flock(ERRLOG,2);
    print ERRLOG "[$date] $program: $message (FATAL)\n";
    flock(ERRLOG,8);
    close(ERRLOG);

    exit(-2);
}

sub WriteToAdminLog {
    local($program,$message) = @_;
    local($date,$month,$day,@now);

    @now = gmtime(time);
    $month = (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$now[4]];
    $day = (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$now[6]];
    $year = $now[5];
    $year += 1900;
    $date = sprintf("%s %s %s %02d:%02d:%02d %4.4d",
      $day, $month, $now[3], $now[2], $now[1], $now[0], $year);

    open(ADMINLOG,">>$ROADS::Logs/admin") || return(-1);
    flock(ADMINLOG,2);
    print ADMINLOG "[$date] $program: $message\n";
    flock(ADMINLOG,8);
    close(ADMINLOG);
    return(0);
}

1;
__END__


=head1 NAME

ROADS::ErrorLogging - A class to log errors and optionally bomb out

=head1 SYNOPSIS

  use ROADS::ErrorLogging;
  WriteToAdminLog("$0", "something weird is #;:<>!%&*");
  WriteToErrorLog("$0", "Uh oh... :-(");
  WriteToErrorLogAndDie("$0", "time for tubby byebye: $!");

=head1 DESCRIPTION

This class defines three methods which may be used to log messages and
program names to log files.  Log file entries are written after the
fashion of the common HTTP error logging style, and the log files are
locked while active to avoid corruption when multiple processes
attempt to write to the same file at the same time.

=head1 METHODS

=head2 WriteToAdminLog( progname, message );

This method writes I<message> to the admin log, stamped as being from
the program I<progname>.

=head2 WriteToErrorLog( progname, message );

This method writes I<message> to the error log, stamped as being from
the program I<progname>.

=head2 WriteToErrorLogAndDie( progname, message );

This method writes I<message> to the error log, stamped as being from
the program I<progname>, and then kills itself off.  It adds the tag
'(FATAL)' to the message, and if the environmental variable
GATEWAY_INTERFACE isn't set, also sends the program name and message
to STDERR.

=head1 FILES

I<logs/admin> - where admin logs are written to.

I<logs/errors> - where error logs are written to.

=head1 FILE FORMAT

Both the admin and error log files are structured as follows :-

=over 4

=item the date, prettyprinted in UTC (GMT)

=item the name of the program which is sending the message

=item the message itself

=back

=head1 BUGS

We should make it possible to specify alternative log files.  The code
actually understands the ROADS::Logs variable, but the actual log file
name is hard coded in at the moment.  It probably ought also to be
configurable whether we bomb out - which would potentially leave us
with just a single logging routine instead of three almost identical
ones!

=head1 SEE ALSO

Most of the ROADS tools!

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

