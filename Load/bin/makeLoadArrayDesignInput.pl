#!/usr/bin/perl

use strict;

use DBI;
use DBD::Oracle;

use Getopt::Long;
use CBIL::Util::PropertySet;

use GUS::Community::AffymetrixArrayFileReader;

my ($targetFile, $probeFile, $cdfFile, $designElementType, $polymerType, $physicalBioSequenceType, $verbose, $help, $gusConfigFile, $out);

&GetOptions('help|h' => \$help, 
            'target_file=s' => \$targetFile,
            'probe_tab_file=s' => \$probeFile,
            'cdf_file=s' => \$cdfFile,
            'design_element_type=s' => \$designElementType,
            'polymer_type=s' => \$polymerType, 
            'physical_biosequence_type=s' => \$physicalBioSequenceType,
            'gus_config_file=s' => \$gusConfigFile,
            'output_file=s' => \$out,
            'verbose' => \$verbose,
           );

&usage() unless($targetFile && $probeFile && $cdfFile && 
                   $designElementType && $polymerType && $physicalBioSequenceType && $out);

my $dbh = &connectToDatabase($gusConfigFile);

my $cdfReader =  GUS::Community::AffymetrixArrayFileReader->new($cdfFile, 'cdf');
my $probeReader =  GUS::Community::AffymetrixArrayFileReader->new($probeFile, 'probe');

my $array = $cdfReader->readFile();
my $probeMap = $probeReader->readFile();
my $targetMap = &readTargetFile($targetFile, $dbh);

my $designElementTypeId = &getOntologyEntryId($designElementType, 'DesignElement', $dbh);
my $polymerTypeId = &getOntologyEntryId($polymerType, 'PolymerType', $dbh);
my $physicalBioSequenceTypeId = &getOntologyEntryId($physicalBioSequenceType, 'PhysicalBioSequenceType', $dbh);

&printLoadArrayDesignInput($array, $probeMap, $targetMap, $designElementTypeId, $polymerTypeId, $physicalBioSequenceTypeId);

$dbh->disconnect();

#-------------------------------------------------------------------------------
#  SUBROUTINES
#-------------------------------------------------------------------------------

sub printLoadArrayDesignInput {
  my ($array, $probeMap, $targetMap, $designElementTypeId, $polymerTYpeId, $physicalBioSequenceTypeId) = @_;

  open(OUT, "> $out") or die "Cannot open file $out for writing: $!";

  my $header = join "\t","x_pos", "y_pos", "sequence", "match", "name", "ext_db_rel_id", "source_id", "design_element_type_id", 
  "polymer_type_id", "physical_biosequence_type_id";

  print OUT $header, "\n";

  foreach my $set ($array->each_featuregroup) {
    my $name = $set->id;
    $name =~ s/\s+$//;

    # sort probe pairs based on their x_position, then by y_position
    my @sorted_ftrs = sort {$a->x <=> $b->x || $a->y <=> $b->y} $set->each_feature;

    foreach my $ftr (@sorted_ftrs) {
      my $key = join "\t", $name, $ftr->x, $ftr->y;
      my $probeSequence = $probeMap->{$key} || "";

      my $sourceId = $targetMap->{$name}->{source_id};
      my $extDbRlsId = $targetMap->{$name}->{ext_db_rls_id};

      my $xpos = $ftr->x;
      my $ypos = $ftr->y;

    if(!$sourceId || !$name) {
      print STDERR "$name\t$xpos\t$ypos\t$probeSequence\t$sourceId\n" if($verbose);
    }

      print OUT join "\t", $xpos, 
        $ypos, 
          $probeSequence, 
            $ftr->is_match, 
              $name, 
                $extDbRlsId, 
                  $sourceId, 
                    $designElementTypeId, 
                      $polymerTypeId, 
                        $physicalBioSequenceTypeId; 
      print OUT "\n";
    }
  }
  close(OUT);
}

#-------------------------------------------------------------------------------

sub getOntologyEntryId {
  my ($value, $category, $dbh) = @_;

  my $sql = "select ontology_entry_id from Study.OntologyEntry where value = ? and category = ?";

  my $sh = $dbh->prepare($sql);
  $sh->execute($value, $category);

  my $rv;
  unless( ($rv) = $sh->fetchrow_array()) {
    die "No ontologyEntry with value of $value and category of $category";
  }
  return($rv);
}

#-------------------------------------------------------------------------------

sub connectToDatabase {
  my ($fn) = @_;

  my $gusConfigFile = defined($fn) ? $fn : $ENV{GUS_HOME} .  "/config/gus.config";

  my @properties = ();
  my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

  my $u = $gusconfig->{props}->{databaseLogin};
  my $pw = $gusconfig->{props}->{databasePassword};
  my $dsn = $gusconfig->{props}->{dbiDsn};

  my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;

  return($dbh);
}

#-------------------------------------------------------------------------------

sub readTargetFile {
  my ($fn, $dbh) = @_;

  my %extDbRlsIds;
  my %sourceIds;

  open(FILE, $fn) or die "Cannot open file $fn for reading: $!";

  while(<FILE>) {
    chomp;
    my ($affyProbeId, $sourceId, $extDbSpec) = split(/\t/, $_, 3);

    my $extDbRlsId = &retrieveExtDbRlsId($extDbSpec, \%extDbRlsIds, $dbh);

    $sourceIds{$affyProbeId} = {source_id => $sourceId, ext_db_rls_id => $extDbRlsId};
  }
  return(\%sourceIds);
}

#-------------------------------------------------------------------------------

sub retrieveExtDbRlsId {
  my ($extDbSpec, $allIdsHashRef, $dbh) = @_;

  my $extDbRlsId;

  if($extDbRlsId = $allIdsHashRef->{$extDbSpec}) {
    return($extDbRlsId);
  }

  my ($extDbName, $extDbVersion) = split(/\|/, $extDbSpec);

  my $sql = "select r.external_database_release_id from SRes.EXTERNALDATABASE e, SREs.EXTERNALDATABASERELEASE r
               where r.external_database_id = e.external_database_id and e.name = ? and r.version = ?";

  my $sh = $dbh->prepare($sql);
  $sh->execute($extDbName, $extDbVersion);

  ($extDbRlsId) = $sh->fetchrow_array();

  unless($extDbRlsId) {
    die "No external database Release id with name $extDbName and version $extDbVersion";
  } 

  $allIdsHashRef->{$extDbSpec} = $extDbRlsId;
  return($extDbRlsId);
}

#-------------------------------------------------------------------------------

sub usage {
  my ($m) = @_;

  print STDERR $m."\n" if($m);
  print STDERR "usage: perl makeLoadArrayDesignInput \\
target_file < \"affy_probe<TAB>source_id<TAB>external_database_SPEC(NM|VERSION)\"> \\
probe_tab_file <AFFY PROBE TAB FILE> \\
cdf_file <AFFY CDF FILE> \\
design_element_type <study::OntologyEntry with category=DesignElement> \\
polymer_type <study::OntologyEntry with category=PolymerType> \\
physical_biosequence_type <study::OntologyEntry with category=PhysicalBioSequenceType>  \\
output_file <OUTFILE>
";
  exit();
}


1;


