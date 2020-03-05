#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";

use Getopt::Long;
use File::Temp qw/ tempfile /;

use DBI;
use DBD::Oracle;

use CBIL::Util::PropertySet;

use File::Copy;

my ($help, $samplesDirectory, $gusConfigFile, $organismAbbrev);

&GetOptions('help|h' => \$help,
            'samples_directory=s' => \$samplesDirectory,
            'gusConfigFile=s' => \$gusConfigFile,
            'organism_abbrev=s' => \$organismAbbrev,
            );

##Create db handle
if(!$gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
}

&usage("Config file $gusConfigFile does not exist.") unless -e $gusConfigFile;
&usage("Sample directory does not exist") unless -d $samplesDirectory;
&usage("organismAbbrev not defined") unless $organismAbbrev;

my @properties;
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $dbiDsn = $gusconfig->{props}->{dbiDsn};
my $dbiUser = $gusconfig->{props}->{databaseLogin};
my $dbiPswd = $gusconfig->{props}->{databasePassword};

my $dbh = DBI->connect($dbiDsn, $dbiUser, $dbiPswd) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

my $sql = "select s.source_id, s.secondary_identifier 
from dots.externalnasequence s, apidb.organism o
where s.taxon_id = o.taxon_id
and abbrev = '$organismAbbrev'
and secondary_identifier is not null";

my $sh = $dbh->prepare($sql);
$sh->execute();

my %map;
while(my ($sequenceId, $seqRegionName) = $sh->fetchrow_array()) {
  $map{$seqRegionName} = $sequenceId;
}

$sh->finish();


foreach my $bed (glob "$samplesDirectory/*/*.bed") {
  my $oldBed = "$bed.old";

  move($bed, $oldBed);

  open(OLD, $oldBed) or die "Cannot open file $oldBed for reading: $!";
  open(BED, ">$bed") or die "Cannot open file $bed for writing: $!";

  while(<OLD>) {
    chomp;
    my @a = split(/\t/, $_);
    if($map{$a[0]}) {
      $a[0] = $map{$a[0]};
    }

    print BED join("\t", @a) . "\n";
  }

  close BED;
  close OLD;

}

foreach my $junction (glob "$samplesDirectory/*/junctions.tab") {
  my $oldJunction = "$junction.old";

  move($junction, $oldJunction);

  open(OLD, $oldJunction) or die "Cannot open file $oldJunction for reading: $!";
  open(JXN, ">$junction") or die "Cannot open file $junction for writing: $!";

  my $header = <OLD>;
  print JXN $header;

  while(<OLD>) {
    chomp;
    my @a = split(':', $_);
    if($map{$a[0]}) {
      $a[0] = $map{$a[0]};
    }

    print JXN join(":", @a) . "\n";
  }

  close JXN;
  close OLD;
}


sub usage {
  die "ebiDumper.pl -init_directory=DIR --mysql_directory=DIR --output_directory=DIR --schema_definition_file=FILE --chromosome_map_file=FILE container_name=s dataset_name=s dataset_version=s ncbi_tax_id=s\n";
}

1;

