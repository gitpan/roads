#
# ROADS::CGIvars - Handy routines for processing CGI variables
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# Description: This file contains some useful subroutines for striping out
#   CGI variables and unescaping them before the are used by a ROADS Perl
#   script.
#
# $Id: CGIvars.pm,v 3.12 1998/09/05 13:58:57 martin Exp $
#

package ROADS::CGIvars;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(unescape cleaveargs %CGIvar %CGIvarcharset);

#
# Subroutine to unescape a URL.  This returns any hex escape sequences back
# into the original character.
#
sub unescape {
    my ($string) = @_;
    my ($number, $char);
 
    $string =~ s/\+/ /g;
    $_ = $string;
    while (/(%)([A-Fa-f0-9][A-Fa-f0-9])/) {
        $number = hex($2);
        $char = sprintf("%c", $number);
        $string =~ s/%$2/$char/;
        $_ = $string;
    }
    $string;
}

#
# Subroutine to convert HTML FORM arguments into global perl variables.
# This subroutine makes use of the REQUEST_METHOD, CONTENT_LENGTH and
# QUERY_STRING environment variables which should be set up by the 
# HTTP server.
#
sub cleaveargs {
    my (@varlist) = "";
    my ($arg, @arguments, $query_string, $boundary);

    if($ENV{REQUEST_METHOD} eq "GET") {
        @arguments = split('&', $ENV{QUERY_STRING});
    } elsif ($ENV{REQUEST_METHOD} eq "POST") {
        if($ENV{CONTENT_TYPE} eq "application/x-www-form-urlencoded") {
          local($numbytes) = $ENV{CONTENT_LENGTH};
          read(STDIN, $query_string, $numbytes);
          @arguments = split('&', $query_string);
        } elsif ($ENV{CONTENT_TYPE} =~ /multipart\/form-data;\s*boundary=(.*)/i) {
          $boundary = $1;
          $boundary =~ s/"//g;
          &SplitMultipartForm($query_string,$boundary);
          return; # The above function already does the split for us.
        } else {
          print "HTTP/1.0 400 Bad Request\n";
          print "Content-type: text/html\n\n";
          print "<HTML><HEAD><TITLE>400 Bad Request</TITLE></HEAD>\n";
          print "<BODY><H1>400 Bad Request</H1>\n";
          print "Your client sent a query that this server could not\n";
          print "understand.<P>\n";
          print "Reason: Invalid or unsupported FORM MIME type.<P>\n";
          print "</BODY>\n<HTML>\n";
          exit;
        }
    } else {
        print "HTTP/1.0 400 Bad Request\n";
        print "Content-type: text/html\n\n";
        print "<HTML><HEAD><TITLE>400 Bad Request</TITLE></HEAD>\n";
        print "<BODY><H1>400 Bad Request</H1>\n";
        print "Your client sent a query that this server could not\n";
        print "understand.<P>\n";
        print "Reason: Invalid or unsupported method.<P>\n";
        print "</BODY>\n<HTML>\n";
        exit;
    }
        
    foreach $arg (@arguments) { 
        local(@varpair) = split('=', $arg);
        local($varname) = $varpair[0];
        local($value) = $varpair[1];
        $value = &unescape($value);
        $varname = &unescape($varname);
        if($CGIvar{$varname} eq "") {
            $CGIvar{$varname}= $value;
        } else {
            $CGIvar{$varname}=$CGIvar{$varname}.",$value";
        }
        $CGIvarcharset{$varname} = "ascii"; 

        print STDERR "CGIvar{$varname}=$value\n" if ($debug);
    }
}

#
# Subroutine to handle POSTed FORM data that is wrapped up inside a 
# multipart/form MIME package.  This subroutine splits the enclosed
# MIME bodies straight out into the hashes so there's no need to do
# any further process after running this.
#
sub SplitMultipartForm {
  my($query_string,$boundary) = @_;
  my($line,$inbody,$inmimeheader,$varname,$varvalue,$varcharset,$contenttype);

  $inbody = 0;
  $inmimeheader = 0;
  $varname = "";
  $varvalue = "";
  $varcharset = "";
  $contenttype = "text/plain";
  while($line = <STDIN>) {
    $line =~ s/[\r\n]+$//;

    if($debug) {
      $count++;                                 # DEBUGGING
      print STDOUT "line $count = $line\n";     # DEBUGGING
    }

    if($line eq "--$boundary--") {
      if($varname ne "") {
        $CGIvar{$varname} = $varvalue;
        $varcharset = "ascii" if ($varcharset eq "");
        $CGIvarcharset{$varname} = $varcharset;
      }
      return;
    }
    if($line eq "--$boundary") {
      $inbody = 0;
      $inmimeheader = 1;
      if($varname ne "") {
        $CGIvar{$varname} = $varvalue;
        $varcharset = "ascii" if ($varcharset eq "");
        $CGIvarcharset{$varname} = $varcharset;
      }
      $varname = "";
      $varvalue = "";
      $varcharset = "";
      next;
    }
    if($inmimeheader==1 && $line eq "") {
      $inbody = 1;
      $inmimeheader = 0;
      next;
    }
    if($inmimeheader==1 
      && $line =~ /Content-Disposition: form-data; name="?(.+)"?/){
      $varname = $1;
    }
    if($inmimeheader==1
      && $line =~ /Content-Type: (.*?);*\s*(charset="?(.*?)"?)/) {
      $contenttype = $1;
      $charset = $2;
      $charset = "ascii" if($charset eq "");
    }
    if($inbody==1) {
      $varvalue .= $line;
    }
  }
}

1;
__END__


=head1 NAME

ROADS::CGIvars - A class to unpack and unescape CGI variables

=head1 SYNOPSIS

  use ROADS::CGIvars;
  print unescape("http://www.net.lut.ac.uk/%7Emartin/"), "\n";
  cleavargs;
  print $CGIvar{templatetype}, "\n";

=head1 DESCRIPTION

This class implements a method for unpacking the CGI parameters
bundled with an HTTP request, and a method for turning hex escapes
used for illegal characters back into the characters they represent,
e.g. '%7E' to the ASCII tilde character.

=head1 METHODS

=head2 cleaveargs( );

This method reads CGI parameters from the environmental variable
QUERY_STRING (if called with the environmental variable REQUEST_METHOD
set to 'GET') or from STDIN (if REQUEST_METHOD is 'POST'), and adds
them to a hash array in the main program namespace - I<CGIvars>.  If
the REQUEST_METHOD is neither GET nor POST, the method will bomb out
with an HTML error message.  If the REQUEST_METHOD is 'POST', the
number of bytes to read from STDIN will be set by reading the
CONTENT_LENGTH variable from the environment.  These environmental
variables are normally set by HTTP servers when launching CGI
programs.

Entries are added with the CGI variable name as their key, and the CGI
value as their value.  If an entry already exists, it will be appended
to, using a comma ',' as delimiter.  Note that if the I<CGIvar> hash
array already exists, these new elements will be added to the existing
entries.  There is no return value from this method.

=head2 unescape( escaped_url );

This method takes a string as its parameter and performs hex
unescaping on it.  In addition, any '+' characters in the string will
be replaced with spaces.  The result is returned.

=head1 BUGS

There is no check on the existance of the CONTENT_LENGTH variable in
the process' environment.

=head1 SEE ALSO

I<admin-cgi> and I<cgi-bin> programs.

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

