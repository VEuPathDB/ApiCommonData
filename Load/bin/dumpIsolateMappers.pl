#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use DBI;
use DBD::Oracle;
use Getopt::Long;
use CBIL::Util::PropertySet;

my ($help, $instances, $gusConfigFile, $inputMapFile, $category, $outputFile, $instanceRegex);
&GetOptions('help|h' => \$help,
            'gusConfigFile=s' => \$gusConfigFile,
            'instance=s@' => \$instances,
            'inputMapFile=s' => \$inputMapFile,
            'category=s' => \$category,
            'outputFile=s' => \$outputFile,
            'instanceRegex=s' => \$instanceRegex,
    );

##Create db handle
if(!$gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
}

&usage("Config file $gusConfigFile does not exist.") unless -e $gusConfigFile;

my @properties;
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $dbiUser = $gusconfig->{props}->{databaseLogin};
my $dbiPswd = $gusconfig->{props}->{databasePassword};

unless($category eq 'host' || $category eq 'country' || $category eq 'isolation_source') {
  &usage("Category must be one of [host|country|isolation_source");
}

unless(-e $inputMapFile) {
  &usage("inputMapFile $inputMapFile dies not exist");
}


unless($instances) {
  my $tnsSummaryResult = `apiTnsSummary |grep -P '$instanceRegex'|cut -f 1 -d '.'`;
  my @tnsInstances = split("\n", $tnsSummaryResult);
  $instances = \@tnsInstances;
}


unless(scalar @$instances > 0) {
  &usage("missing instance param");
}

my $sql = "select distinct c.value
from study.characteristic c
   , sres.ontologyterm o
where c.ontology_term_id = o.ontology_term_id
and o.name = ?";

my %seen;

open(IN, $inputMapFile) or die "Cannot open existing map file $inputMapFile for reading: $!";
open(OUT, "> $outputFile")  or die "Cannot open output file $outputFile for writing: $!";

while(<IN>) {
  chomp;
  my @a = split(/\t/, $_);
  $seen{$a[0]} = 1; # first column of the map file is the string to be mapped

  print OUT join("\t", @a) . "\n";
}
close IN;

print OUT "##### NEW TERMS START##### \n";

foreach my $instance (@$instances) {

  my $systemResult = system("tnsping $instance");
  unless($systemResult / 256 == 0) {
    print STDERR "WARNING:  tnsping $instance failed to resolve name... SKIPPING instance";
    next;
  }

  my $dbh = DBI->connect("dbi:Oracle:$instance", $dbiUser, $dbiPswd) or die DBI->errstr;
  $dbh->{RaiseError} = 1;
  $dbh->{AutoCommit} = 0;

  my $sh = $dbh->prepare($sql);
  $sh->execute($category);

  while(my ($value) = $sh->fetchrow_array()) {
    next if($seen{$value});

    print OUT $value . "\t\n";
    $seen{$value} = 1;
  }
  $sh->finish();
  $dbh->disconnect();
}


close OUT;

sub usage {
  my ($e) = @_;

  print STDERR "usage:  dumpIsolateMappers.pl [--help] [--gusConfigFile=s] --instance=s@ --category=s --inputMapFile=s --outputFile=s\n";
  die $e;
}
