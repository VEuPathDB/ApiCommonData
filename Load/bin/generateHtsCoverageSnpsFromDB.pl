#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | broken
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | broken
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

## to be run after all HTS snps have been loaded.  

## note: can get the strain / external_database_release_id pairs for all strains for this reference genome from seqVariation or potentially study.sample would be quicker
## then for each hts_snp in SNPFeature, if an ext_db_id is not there do substring in extnaseq to pull out base and if like reference, add seqvariation.

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;

my $file; 
my $outputFile = 'coverageSnps.gff';
my $gusConfigFile = $ENV{GUS_HOME} ."/config/gus.config";
my $referenceOrganism;
my $referenceStrain;
my $verbose;

&GetOptions("gusConfigFile|gc=s"=> \$gusConfigFile,
            "outputFile|o=s"=> \$outputFile,
            "verbose|v!"=> \$verbose,
            "referenceOrganism|r=s"=> \$referenceOrganism,
            "referenceStrain|s=s"=> \$referenceStrain,
            );

if (!$referenceOrganism){
die <<endOfUsage;
generateCoverageSnps.pl usage:

  generateCoverageSnpsFromDB.pl --gusConfigFile|gc <gusConfigFile [\$GUS_HOME/config/gus.config] --referenceOrganism <organism on which SNPs are predicted .. ie aligned to .. in dots.snpfeature.organism> --outputFile|o <outputFile [coverageSnps.gff]> --verbose!
endOfUsage
}

my $gusConfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusConfig->getDbiDsn(),
                                         $gusConfig->getDatabaseLogin(),
                                         $gusConfig->getDatabasePassword(),
                                         $verbose, 0, 1,
                                         $gusConfig->getCoreSchemaName()
                                        );

my $dbh = $db->getQueryHandle();

open(O,">$outputFile") || die "unable to open $outputFile for output\n";

##need to get the list of strains and external_db_ids
my $strainSQL = <<SQL;
select sv.strain,sv.external_database_release_id,count(*)
from dots.snpfeature sf, DOTS.seqvariation sv,SRES.externaldatabase d, SRES.externaldatabaserelease rel
where d.name = 'InsertSnps.pm NGS SNPs INTERNAL'
and rel.external_database_id = d.external_database_id
and sf.external_database_release_id = rel.external_database_release_id
and sf.organism = '$referenceOrganism'
and sv.parent_id = sf.na_feature_id
group by sv.strain,sv.external_database_release_id
SQL

my $strainStmt = $dbh->prepare($strainSQL);
$strainStmt->execute();
my %strains;
while(my($strain,$rel_id,$count) = $strainStmt->fetchrow_array()){
  print STDERR "Strain: ($strain,$rel_id,$count)\n" if $verbose;
  $strains{$rel_id} = $strain;
}

print STDERR "Found ".scalar(keys%strains)." strains in the database\n";

die "ERROR: unable to identify any strains for referenceOrganism $referenceOrganism\n" unless scalar(keys%strains) > 0;

my $snpSQL = <<EOSQL;
select sf.source_id as snp_id,s.source_id as seq_id,l.start_min,sf.reference_na,sv.allele,sv.external_database_release_id,sf.reference_strain
from dots.snpfeature sf, DOTS.seqvariation sv, dots.nalocation l,
SRES.externaldatabase d, SRES.externaldatabaserelease rel,dots.nasequence s, sres.sequenceontology so
where d.name = 'InsertSnps.pm NGS SNPs INTERNAL'
and rel.external_database_id = d.external_database_id
and sf.external_database_release_id = rel.external_database_release_id
and sf.organism = '$referenceOrganism'
and sv.parent_id = sf.na_feature_id
and l.na_feature_id = sf.na_feature_id
and s.na_sequence_id = sf.na_sequence_id
and sf.sequence_ontology_id = so.sequence_ontology_id
and so.term_name = 'SNP'
EOSQL

my %snps;

my $stmt = $dbh->prepare($snpSQL);
$stmt->execute();
my $ct = 0;
print STDERR "Returning rows from snp query\n";
while(my $row = $stmt->fetchrow_hashref()){
  $snps{$row->{SEQ_ID}}->{$row->{START_MIN}}->{id} = $row->{SNP_ID};
  $snps{$row->{SEQ_ID}}->{$row->{START_MIN}}->{ref} = $row->{REFERENCE_NA};
  $snps{$row->{SEQ_ID}}->{$row->{START_MIN}}->{strains}->{$row->{EXTERNAL_DATABASE_RELEASE_ID}} = $row->{ALLELE}; ##could be multiple alleles but doesn't matter as not adding any new ones if there is at least one
  if($referenceStrain &&  $row->{REFERENCE_STRAIN} && $referenceStrain ne $row->{REFERENCE_STRAIN}){
    die "ERROR: there are multiple references strains for this organism: $referenceStrain, $row->{REFERENCE_STRAIN}\n";
  }
  $referenceStrain = $row->{REFERENCE_STRAIN} unless $referenceStrain;
  $ct++;
  print STDERR "Retrieved $ct rows\n" if ($verbose && $ct % 10000 == 0);
}

die "ERROR: unable to determine reference strain from the snpFeatures\n" unless $referenceStrain;

##need the ext_db_rel_id for reference strain as want to add to strains if not there.
my $refSQL = <<EOSQL;
select distinct s.external_database_release_id
from dots.nasequence s,dots.snpfeature sf,SRES.externaldatabase d, SRES.externaldatabaserelease rel
where d.name = 'InsertSnps.pm NGS SNPs INTERNAL'
and rel.external_database_id = d.external_database_id
and sf.external_database_release_id = rel.external_database_release_id
and sf.organism = '$referenceOrganism'
and s.na_sequence_id = sf.na_sequence_id
EOSQL

my $refStmt = $dbh->prepare($refSQL);
$refStmt->execute();
my @tmpEx;
while(my($id) = $refStmt->fetchrow_array()){
  push(@tmpEx,$id);
}
die "ERROR getting reference external_database_release_id: query returned more than one row\n" if scalar(@tmpEx) > 1;
my $referenceDbRelId = $tmpEx[0];
if(! $strains{$tmpEx[0]}){
  print STDERR "Also adding SeqVars for reference strain $referenceStrain\n";
  $strains{$tmpEx[0]} = $referenceStrain; 
}

my $ntSQL = <<EOSQL;
select dbms_lob.substr(sequence,1,?)
from dots.nasequence
where source_id = ?
and external_database_release_id = ?
EOSQL

my $ntStmt = $dbh->prepare($ntSQL);

my $ctSnps = 0;
foreach my $seqid (keys%snps){
  foreach my $loc (keys%{$snps{$seqid}}){
    ##now loop through the strains and if not present here generate snp
    my @alleles;
    my $snpid = $snps{$seqid}->{$loc}->{id};
    my $refna = $snps{$seqid}->{$loc}->{ref};
    foreach my $dbrelid (keys%strains){
      my $stNa = &getNt($loc,$dbrelid == $referenceDbRelId ? $seqid : $seqid . ".".$strains{$dbrelid},$dbrelid);
#      print STDERR "'$dbrelid' -> db: '$snps{$seqid}->{$loc}->{strains}->{$dbrelid}'\n";
      next if $snps{$seqid}->{$loc}->{strains}->{$dbrelid}; ##already have this one
      push(@alleles,$strains{$dbrelid}.":".$stNa.":::::$dbrelid") if $stNa eq $refna;
    }
    if(scalar(@alleles) >= 1){
      print O "$seqid\tNGS_SNP\tSNP\t$loc\t$loc\t.\t+\t.\tID $snpid; Allele \"".join("\" \"",@alleles)."\";\n";
      $ctSnps++;
      print STDERR "Created $ctSnps SNPs\n" if ($verbose && $ctSnps % 10000 == 0);
    }
#    last if $ctSnps % 10 == 0; ##limit output when testing ..
  }
}

print STDERR "Coverage SNPs: Added strains to $ctSnps SNPs\n";

close O;

$db->logout();

sub getNt {
  my($pos,$sid,$extid) = @_;
  my @tmp;
  $ntStmt->execute($pos,$sid,$extid);
  while(my($nt) = $ntStmt->fetchrow_array()){
    push(@tmp,$nt);
  }
  die "getNt ERROR: query returned more than one row for ($pos,$sid,$extid)\n" if scalar(@tmp) > 1;
  return $tmp[0];
}
