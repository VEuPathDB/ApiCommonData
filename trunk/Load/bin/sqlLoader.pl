#!/usr/bin/perl

use strict;

use CBIL::Util::PropertySet;
use Getopt::Long;
use DBI;
use DBD::Oracle;

my ($help, $fn, $gusConfigFile);

&GetOptions('help|h' => \$help,
            'file=s' => \$fn,
            'gus_config_file=s' => \$gusConfigFile,
            );

#============================================

$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless(-e $gusConfigFile && -e $fn) {
  print STDERR "usage --file continents_file [--gus_config_file]\n";
  exit;
}

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my ($dbi,$oracle,$db) = split(':', $gusconfig->{props}->{dbiDsn});

open(FILE, $fn) or die "Cannot open file $fn for reading:$!";

my $log=$fn. ".log";

my $output = `sqlldr $u/$pw\@$db control=$fn log=$log`;

my $status = $? >> 8;
 
die("Failed with status $status running") if ($status);


1;
