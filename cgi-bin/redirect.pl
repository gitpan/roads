#!/usr/bin/perl
use lib "/home/roads2/lib";

#
# redirect.pl - Redirect to an embedded URL whilst logging the access
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# $Id: redirect.pl,v 3.12 1998/09/05 14:00:43 martin Exp $
#

require ROADS;

# If there is no query part to the URL, then issue an HTML error message
if($ENV{QUERY_STRING} eq "") {
  print STDOUT "HTTP/1.0 404 OK\n";
  print STDOUT "Content-type: text/html\n";
  print STDOUT "Server: $ENV{SERVER_SOFTWARE}\n\n";
  print STDOUT "<HTML><HEAD><TITLE>404 Not Found</TITLE></HEAD>\n";
  print STDOUT "<BODY><H1>Not Found</H1>No URL to redirect to.\n";
  print STDOUT "</BODY></HTML>\n";
} else {
  # Note the URL being redirected to in our log file.  The name of the log
  # file is based on the name of this script.
  $scriptname = basename($0,".pl");
  $hitlog = "$ROADS::Logs/$scriptname"."-hits";

  open(HITLOG,">>$hitlog")
      || &WriteToErrorLog("$0", "couldn't open $hitlog: $!");
  flock(HITLOG,2);
  print HITLOG "$ENV{QUERY_STRING}\n";
  flock(HITLOG,8);
  close(HITLOG);

  # Output the actual redirect to force the browser to go to the real resource
  print STDOUT "HTTP/1.0 302 Found";
  print STDOUT "Content-type: text/html\n";
  print STDOUT "Location: $ENV{QUERY_STRING}\n";
  print STDOUT "Server: $ENV{SERVER_SOFTWARE}\n\n";
  print STDOUT "<HTML><HEAD><TITLE>Redirect</TITLE></HEAD>\n";
  print STDOUT "<BODY><H1>Redirect</H1>The document has moved \n";
  print STDOUT "<A HREF=\"$ENV{QUERY_STRING}\">here</A>.\n";
  print STDOUT "</BODY></HTML>\n";
}

exit;
__END__


=head1 NAME

B<cgi-bin/redirect.pl> - CGI program to redirect client while logging access

=head1 SYNOPSIS

  cgi-bin/redirect.pl

=head1 DESCRIPTION

B<redirect.pl> is a Common Gateway Interface (CGI) program which takes
a URL as its parameter and tries to redirect its HTTP client to this
URL, whilst at the same time logging the URL which is being redirected
to.  This provides a simple way of logging the accesses to resources
which are being catalogued using the ROADS software, and can in fact
be used for this purpose with any URL.

=head1 FILES

Redirected URLs are normally logged to the file I<redirect-hits>, in
the ROADS I<logs> directory, though if the program is called using
another name, this will be reflected in the filename prefix,
e.g. I<wibble-hits> if the program is launched as B<wibble>.

=head1 FILE FORMAT

Each redirected URL is logged on a line of its own.

=head1 BUGS

Depending on the HTTP server you use, it may be necessary to run this
program as B<nph-redirect.pl> rather than B<redirect.pl>.  Some HTTP
servers (e.g. Apache versions post 1.2) automatically detect when a CGI
program creates its own HTTP headers, and others require use of the
B<nph-> naming convention to indicate a program which will do this.

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

