#
# mktemp-size.pl
#
# Author: Jon Knight <jon@net.lut.ac.uk>
#
# Description: Routine to work out the size of each of the clusters and all
#   of the variants currently in a template.
#
# $Id: mktemp-size.pl,v 1.7 1998/09/05 13:59:29 martin Exp $
#

sub WorkOutSize {
    $current_type = "";
    $done = 0;
    undef(%TEMPLATE);
    @allvars = keys %CGIvar;
    @allclusters = grep(/^cluster/,@allvars);
    do {
    	$line = <ORIGTEMP>;
        $_ = $line;
        if (/^Template-Type:\s+(\w+)/) {
            undef %TEMPLATE;
            $CGIvar{templatetype}=$1;
            $tt = $CGIvar{templatetype};
            $tt =~ y/A-Z/a-z/;
            $current_type = $1;
        } else {
            if (/^([\w-]+)\:\s*(.*)/) {
                $oca = $1;
                $line = $2;
                $TEMPLATE{$current_attr} =~ s/\r//g;
                $TEMPLATE{$current_attr} =~ s/^\n//;
                $TEMPLATE{$current_attr} =~ s/\n\n/\n/g;
                $TEMPLATE{$current_attr} =~ s/\n  /\n/g;
                $TEMPLATE{$current_attr} =~ s/\n+$//;
                $current_attr = $oca;
                $current_attr =~ s/\-//g;
                $current_attr =~ s/v([0-9]+)$/$1/;
            }
            if ($current_attr ne "") {
                $TEMPLATE{$current_attr} .= "\n$line";
            }
        }
        if (/^\n$/ || eof(ORIGTEMP)) {
            if(($TEMPLATE{Handle} eq $CGIvar{originalhandle})
              && $current_type ne "") {
                @allattr = keys %TEMPLATE;
                foreach $key (@allattr) {
                    $CGIvar{"IAFA$key"} = $TEMPLATE{$key};
                }
		$CGIvar{$Handle}=$CGIvar{originalhandle};
                $done = 1;
            }
        }
    } while (!$done && !eof(ORIGTEMP));
    @allclst = ();
    foreach $cluster (@allclusters) {
        $cluster =~ s/^cluster//;
        @match = grep(/^$cluster/,@allattr);
	@allclst = (@allclst, @match);
        $size = 0;
        foreach $key (@match) {
            $_ = $key;
            if(/([0-9]+)$/) {
                $size = $1 if($1 > $size);
            }
        }
        $cluster =~ s/-//g;
        $CGIvar{"cluster$cluster"}=$size+$CGIvar{"cluster$cluster"};
    }
    $size = 0;
    local(%mark);
    grep($mark{$_}++,@allclst);
    @match=grep(!$mark{$_},@allattr);

    foreach $key (@match) {
        $_ = $key;
        if(/([0-9]+)$/) {
            $size = $1 if($1 > $size);
        }
    }
    $CGIvar{"variantsize"}=$size+$CGIvar{"variantsize"};
}

1;
__END__


=head1 NAME

B<lib/mktemp-size.pl> - work out the size of clusters and variants in a template

=head1 SYNOPSIS

  require "$ROADS::Lib/mktemp-size.pl";
  &WorkOutSize;

=head1 DESCRIPTION

This package defines a function which tries to work out the number of
clusters and variants in a template being edited using the CGI
variables passed on to it by the main body of the template editor
program B<mktemp.pl>.

=head1 METHODS

=head2 WorkOutSize;

This function sets the CGI variables I<variantsize> and
I<cluster>B<clustername> (e.g. I<clusterAuthor>) with the number of
clusters of each type and variants in a template.  These are
determined by examining the original template being edited and
factoring in the existing values of these CGI variables.

=head1 BUGS

Working largely with global variables, including an open filehandle
for the original template.  It would be better if this was done in a
less dangerous way.

=head1 SEE ALSO

L<admin-cgi/mktemp.pl>

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
