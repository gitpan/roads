#!/usr/bin/perl
use lib "/home/roads2/lib";

# iafa_lint.pl - check IAFA templates for bogus constructs
# NB: will probably need more hacking over to Do The Right Thing!

# Author: Martin Hamilton <martinh@gnu.org>
# $Id: iafa_lint.pl,v 3.16 1998/09/05 14:00:05 martin Exp $

use Getopt::Std;
getopts('ado:s:');

require ROADS;
use ROADS::ErrorLogging;

$debug = $opt_d || 0;
$OUTLINEDIR= $opt_o || "$ROADS::Config/outlines";
$SOURCEDIR = $opt_s || "$ROADS::IafaSource";

$debug && print STDERR ">> SOURCEDIR: $SOURCEDIR\n>> OUTLINEDIR: $OUTLINEDIR\n";

sub relax {
  $goofs++;
  return if ($goofs > 1);
  print "Template-Type: ", $TT ? $TT : "unknown", "\n";
  print "Handle: ", $HANDLE ? $HANDLE : "unknown", "\n";
}

if ($opt_a) {
  opendir(ALLFILES, "$SOURCEDIR")
    || &WriteToErrorLogAndDie("iafa_lint",
         "Can't open $SOURCEDIR directory: $!");
  @FILES = readdir(ALLFILES);
  closedir(ALLFILES);
} else {
  @FILES = @ARGV;
}

-d "$SOURCEDIR" && chdir "$SOURCEDIR";
$debug && print STDERR ">> chdir($SOURCEDIR)\n";

MAIN:
foreach $template (@FILES) {
  undef(%AV);
  next if $template =~ /^\./;

  $debug && print STDERR ">> inspecting ... $template\n";

  unless (open(IN, "$template")) {
    print "Can't open template $template: $!";
    next;
  }

  $goofs = 0;

  while(<IN>) {
    if (/\r/) { # line contains carriage return characters
      &relax;
      print "$template: template contains carriage return characters\n";
      next MAIN;
    }

    chomp;
  
    s/\t/ /g;
    s/\s+/ /g;
  
    /^template-type:\s+(.*)/i && ($TT=$1);
    /^handle:\s+(.*)/i && ($HANDLE=$1);

    next if /:(\s+|)$/;
  
    if (/^\s/ && $value) { # continuation line
      $value .= "$_";
      next;
    }
  
    if (/^([^\s:]+)\s/ && $value) { # hmm...  blooper ?  flag!
      &relax;
      print "$HANDLE: martian attribute/value pair following $vattrib\n";
    }

    if (/^([^:]+):[^\s](.*)/) { # bogus  attrib:value (no space)
      &relax;
      print "$HANDLE: attribute:value pair with no space following $vattrib\n";
    }
 
    if (/^([^:]+):\s+(.*)/) { # easy!  attrib: value
      if ($attrib) {
        $AV{$vattrib} = "$attrib: $value";
        print STDERR "<< AV{$vattrib} = $attrib: $value\n" if $debug;
      }
  
      $vattrib = $attrib = $1; $value = $2;
      $attrib =~ s/-v\d+//;
      $vattrib =~ tr/[a-z]/[A-Z]/;
    }
  }
  close (IN);

  $TT =~ tr/[A-Z]/[a-z]/;

  print "No template type!\n", $goofs++ unless ($TT);
  print "No handle!\n", $goofs++ unless ($HANDLE);

  unless ($HANDLE =~ /^[^\s]+$/) {
    &relax;
    print "$HANDLE: whitespace in handle\n";
  }

  @avkeys = keys(%AV);
  
  unless (open(OUTLINE, "$OUTLINEDIR/$TT")) {
    &relax;
    print "No template outline $TT for template $HANDLE: $!\n\n";
    next;
  }

  while(<OUTLINE>) {
    chomp;
    next if /^template-type:/i;
    next if /^handle:/i;
    s/:.*//;
    $check = $_;
    $check =~ tr/[a-z]/[A-Z]/;
    print STDERR ">> $check\n" if $debug;

    unless (/\(/ || /-v\*/i) { # plain attrib 
      print STDERR ">> zapping $_\n" if $debug;
      delete($AV{$check}) if $AV{$check};
      next;
    }

    unless (/\(/) { # unclustered variant
      $base = $_;
      $base =~ s/-v\*//i;
      $base =~ tr/[a-z]/[A-Z]/;
      $variant=1;
      while(1) {
        print STDERR ">> looking for variant $base-V$variant\n" if $debug;
        @cluster = grep(/$base-V$variant/, @avkeys);
        last if $#cluster < 0;
        foreach (@cluster) { 
          print STDERR ">> zapping $_\n" if $debug;
          delete($AV{$_}); 
        }
        $variant++;
      }
      next;
    }

    # must be including a cluster here...
    $base=$include="";
    $_ =~ tr/[a-z]/[A-Z]/;
    /^([^\(]+)\(([^\*]+)\*\)/ && ($base = $1, $include = $2);
    $variant=1;
    while(1) {
      print STDERR ">> looking for cluster $base($include)-V$variant\n" 
        if $debug;
      @cluster = grep(/$base.+-V$variant/, @avkeys);
      last if $#cluster < 0;
      foreach (@cluster) { 
        print STDERR ">> zapping $_\n" if $debug;
        delete($AV{$_}); 
      }
      $variant++;
    }
  }
  close(OUTLINE);

  foreach (sort(keys %AV)) {
    next if /^(Record-|Template-Type|Handle)/i;
    &relax;
    print "Bad attribute: $_\n";
  }

  print "\n" if $goofs > 0;
}

exit;
__END__


=head1 NAME

B<bin/iafa_lint.pl> - perform sanity check on a collection of IAFA templates

=head1 SYNOPSIS

  bin/iafa_lint.pl [-ad] [-o outlinedir] [-s sourcedir]
    [file1 file2 ... fileN]

=head1 DESCRIPTION

This program performs some basic checks on the contents of a collection
of IAFA templates, such as may be found on a ROADS server.

The contents of each template are checked against an I<outline>
version of that template type.  Outline templates are used within the
ROADS software to indicate the fields which a template may contain,
and provide some of the configuration information used by the WWW
based template editor.

B<iafa_lint.pl> produces a report listing any of these problems which
it finds with the IAFA templates it processes.  The following checks
are performed:

=over 4

=item I<martian> attributes/value pairs

These are neither continuation lines from previous attribute/value
pairs, or the beginning of a new attribute/value pair.  They may be
caused by, for example, hand editing templates and forgetting to
indent continuation lines by a least one space.

=item no space between attribute name and value

In ROADS, records must have at least one space following the colon
after the attribute name and before the value.  This might not be the
case if the record has be hand edited or imported from another system.

=item presence of unexpected attributes

If attributes appear in a template but not in the outline
specification for this template type, attention is drawn to them.  It
also serves to flag mis-spelled attribute names, e.g. B<Handel>
instead of B<Handle>.

=item presence of templates which do not have an outline specification

This is effectively an error if you are using the ROADS software,
since the outline information is used in a number of places.  It also
serves to draw notice to mis-spelled B<Template-Type> values!

=item handle attribute contains whitespace characters

This is to draw your attention to any templates whose handles (unique
IDs within the database) contain whitespace characters such as tabs
and spaces.  Whitespace should not appear in handles because this
would confuse some of the ROADS tools.

=item template contains carriage returns

The use of older versions of the ROADS template editor tool
B<mktemp.pl>, and some external programs such as text editors and FTP
clients, may result in templates containing carriage return characters
- ASCII code 13.  We have tried to make the ROADS tools fairly
tolerant, but this may cause problems.

=back

=head1 OPTIONS

B<iafa_lint.pl> takes the following arguments:

=over 4 

=item B<-a>

This argument indicates that all of the templates in the given source
directory should be processed.

=item B<-d>

If this argument is given, debugging information will be dumped to
the standard error output stream

=item B<-o> I<outlinedir>

This argument can be used to override the default outline directory,
which is where the outline versions of each template type are stored.

=item B<-s> I<sourcedir>

This argument can be used to override the default template source
directory, which is where B<iafa_lint.pl> looks for IAFA templates to
check.

=back

=head1 OUTLINE FILE FORMAT

You may need to either modify an existing outline file or create a new
one, depending on whether you have invented a new template type or
changed the attributes in an existing one.  A set of default template
outlines are distributed with the ROADS software, and can be found in
the directory "\$ROADS::Config" on your installation.

It is necessary to have outline files for each template type which you
will be checking using B<iafa_lint.pl>

Each outline file must feature the B<Template-Type> and B<Handle>
attributes.  Attributes which only occur once should be written as
they appear in the template, e.g. B<Title>.  Attributes which may
occur multiple times should be written as I<variants>, e.g.
B<URI-v*>.  Finally, it is possible to refer to I<clusters> of
attributes drawn from another type of template by writing its name in
brackets after a disambiguating prefix, e.g. B<Admin-(USER*)>.

A sample outline specification for a very short SERVICE template would
look like this:

  Template-Type: SERVICE
  Handle:
  Title:
  URI-v*:
  Admin-(USER*):

Note that other information may appear after the ":" character.  This
is not used by B<iafa_lint.pl>.

=head1 SEE ALSO

B<admin-cgi/iafa_lint.pl>

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

