#!/bin/sh

# wgiecho.sh - simple sample back end to demo WHOIS++ Gateway Interface

# Author: martin hamilton <m.t.hamilton@lut.ac.uk>
# $Id: wgiecho.sh,v 2.2 1996/05/17 15:51:17 martin Exp $

SERVERHANDLE=me
[ "$SERVER_NAME" ] && SERVERHANDLE=$SERVER_NAME
RENDER=`echo $SERVERHANDLE|sed -e 's/\.//'`

cat <<EOF
# FULL WGIDEMO $RENDER WGIDEMO1
 Query: $QUERY_STRING
 Gateway: $GATEWAY_INTERFACE
 Client-address: $REMOTE_ADDR
 Client-hostname: $REMOTE_HOST
 Server-name: $SERVER_NAME
 Server-port: $SERVER_PORT
 Server-protocol: $SERVER_PROTOCOL
 Server-software: $SERVER_SOFTWARE
# END
EOF

exit 0


=head1 NAME

B<wgiecho.sh> - simple sample back end to demo WHOIS++ Gateway Interface

=head1 SYNOPSIS

B<wgiecho.sh> 
  
=head1 DESCRIPTION

This shell script simply returns the WHOIS++ Gateway Interface arguments
which it was supplied with.  The intention behind it is to demonstrate
the features offered by WGI, rather than to offer a functional backend.

=head1 OPTIONS

None

=head1 OUTPUT

WHOIS++ response in the (made-up!) I<WGIDEMO> format

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

It was developed by the Department of Computer Studies at Loughborough
University of Technology, as part of the ROADS project.  ROADS is funded
under the UK Electronic Libraries Programme (eLib), and the European
Commission Telematics for Research Programme.

=head1 AUTHOR

  Martin Hamilton <m.t.hamilton@lut.ac.uk>

