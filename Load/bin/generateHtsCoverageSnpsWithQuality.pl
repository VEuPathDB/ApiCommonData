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

my $varscanDir;
my $outputFile = 'coverageSnps.tab';
my $gusConfigFile = $ENV{GUS_HOME} ."/config/gus.config";
my $referenceOrganism;
my $referenceStrain;
my $verbose;
my $noCommit;
my $testRowCount = 0;
my $minAllelePercent = 60;

&GetOptions("gusConfigFile|gc=s"=> \$gusConfigFile,
            "varscanDir|vd=s"=> \$varscanDir,
            "outputFile|o=s"=> \$outputFile,
            "verbose|v!"=> \$verbose,
            "referenceOrganism|r=s"=> \$referenceOrganism,
            "referenceStrain|s=s"=> \$referenceStrain,
            "noCommit|nc!"=> \$noCommit,
            "testRowCount|tc=i"=> \$testRowCount, ##use for testing ... only retrieves this many rows.
            "minAllelePercent|ap=i"=> \$minAllelePercent, ##use for testing ... only retrieves this many rows.
            );

if (!$referenceOrganism){
die <<endOfUsage;
generateCoverageSnps.pl usage:

  generateCoverageSnpsWithQuality.pl --varscanDir|vd <directory containing the varscan consensus files> --gusConfigFile|gc <gusConfigFile [\$GUS_HOME/config/gus.config] --referenceOrganism <organism on which SNPs are predicted .. ie aligned to .. in dots.snpfeature.organism> --outputFile|o <outputFile [coverageSnps.gff]> --verbose|v! --testRowCount|tc <number of seqvariation rows to retrieve for testing script>\n
endOfUsage
}

print STDERR "\nTesting with $testRowCount SeqVariation rows\n\n" if $testRowCount;

my $gusConfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusConfig->getDbiDsn(),
                                         $gusConfig->getDatabaseLogin(),
                                         $gusConfig->getDatabasePassword(),
                                         $verbose, 0, 1,
                                         $gusConfig->getCoreSchemaName()
                                        );

my $dbh = $db->getQueryHandle();

open(O,">$outputFile") || die "unable to open $outputFile for output\n";

## print "Identifying strains ... will get later with snp search\n";

my %strains;
my %algIds;
my $ctDelSnp = 0;  ##keep track of numbers of deleted rows
my $ctDelNaLoc = 0;  ##keep track of numbers of deleted rows
my $ctDelSeqVar = 0;  ##keep track of numbers of deleted rows
my $ctSv = 0;  ##count seqvars printed
my $sequence_ontology_id;
my $row_user_id;
my $row_group_id;
my $row_project_id;

my $snpSQL = "
select sf.na_sequence_id,sf.na_feature_id, sf.source_id as snp_id,s.source_id as seq_id,l.start_min,sf.reference_na,sf.reference_aa, sv.allele,sv.external_database_release_id,sf.reference_strain,sv.strain,sv.row_alg_invocation_id,sv.row_group_id,sv.row_project_id,sv.row_user_id,sv.sequence_ontology_id,sv.matches_reference
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
";

my %snps;

my $stmt = $dbh->prepare($snpSQL);
$stmt->execute();
my $ct = 0;
print STDERR "Returning rows from snp query\n";
my %naseq;  ##store source_id -> na_sequence_id mapping
while(my $row = $stmt->fetchrow_hashref()){
  $snps{$row->{SEQ_ID}}->{$row->{START_MIN}}->{id} = $row->{SNP_ID};
  $snps{$row->{SEQ_ID}}->{$row->{START_MIN}}->{na_feature_id} = $row->{NA_FEATURE_ID};
  $snps{$row->{SEQ_ID}}->{$row->{START_MIN}}->{ref} = $row->{REFERENCE_NA};
  $snps{$row->{SEQ_ID}}->{$row->{START_MIN}}->{product} = $row->{REFERENCE_AA};
  $snps{$row->{SEQ_ID}}->{$row->{START_MIN}}->{strains}->{$row->{EXTERNAL_DATABASE_RELEASE_ID}} = $row->{ALLELE}; ##could be multiple alleles but doesn't matter as not adding any new ones if there is at least one
  $snps{$row->{SEQ_ID}}->{$row->{START_MIN}}->{alleles}->{$row->{ALLELE}}++;

  $naseq{$row->{SEQ_ID}} = $row->{NA_SEQUENCE_ID};
  if($referenceStrain &&  $row->{REFERENCE_STRAIN} && $referenceStrain ne $row->{REFERENCE_STRAIN}){
    die "ERROR: there are multiple references strains for this organism: $referenceStrain, $row->{REFERENCE_STRAIN}\n";
  }
  $referenceStrain = $row->{REFERENCE_STRAIN} unless $referenceStrain;
  $strains{$row->{EXTERNAL_DATABASE_RELEASE_ID}} = $row->{STRAIN};
  $algIds{$row->{EXTERNAL_DATABASE_RELEASE_ID}} = $row->{ROW_ALG_INVOCATION_ID} unless $row->{MATCHES_REFERENCE} == 1;
  if(!$row_user_id){
    $row_user_id = $row->{ROW_USER_ID};
    $row_project_id = $row->{ROW_PROJECT_ID};
    $row_group_id = $row->{ROW_GROUP_ID};
    $sequence_ontology_id = $row->{SEQUENCE_ONTOLOGY_ID};
  }
    
  $ct++;
  print STDERR "Retrieved $ct rows\n" if ($verbose && $ct % 10000 == 0);
  last if ($testRowCount && $ct > $testRowCount);
}
$stmt->finish();

print STDERR "Retrieved $ct rows -- Found ".scalar(keys%strains)." strains in the database\n";
die "ERROR: unable to identify any strains for referenceOrganism $referenceOrganism\n" unless scalar(keys%strains) > 0;
die "ERROR: unable to determine reference strain from the snpFeatures\n" unless $referenceStrain;

##check to see if have reference strain and if not, determine extDbRelId.
my $referenceDbRelId;
foreach my $s (keys%strains){
  if($strains{$s} eq $referenceStrain){
    $referenceDbRelId = $s;
    last;
  }
}

if(!$referenceDbRelId){
  ##need the ext_db_rel_id for reference strain as want to add to strains if not there.
  print STDERR "Don't have an external_db_release for reference strain .. retrieving from db\n";
  my $refSQL = <<EOSQL;
select s.external_database_release_id
from dots.nasequence s,dots.snpfeature sf,SRES.externaldatabase d, SRES.externaldatabaserelease rel
where d.name = 'InsertSnps.pm NGS SNPs INTERNAL'
and rel.external_database_id = d.external_database_id
and sf.external_database_release_id = rel.external_database_release_id
and sf.organism = '$referenceOrganism'
and s.na_sequence_id = sf.na_sequence_id
group by s.external_database_release_id
EOSQL

  my $refStmt = $dbh->prepare($refSQL);
  $refStmt->execute();
  my @tmpEx;
  while(my($id) = $refStmt->fetchrow_array()){
    push(@tmpEx,$id);
  }
  die "ERROR getting reference external_database_release_id: query returned more than one row\n" if scalar(@tmpEx) > 1;
  $referenceDbRelId = $tmpEx[0];
  if(! $strains{$tmpEx[0]}){
    print STDERR "Also adding SeqVars for reference strain $referenceStrain\n";
    $strains{$tmpEx[0]} = $referenceStrain; 
    $algIds{$tmpEx[0]} = 1; ##this will be a problem for the undo process but there should always already be a reference strain ... and if there isn't we'll undo this when we do a root undo for hts snps for this organism.
  }
}

my $ntSQL = <<EOSQL;
select dbms_lob.substr(sequence,1,?)
from dots.nasequence
where source_id = ?
and external_database_release_id = ?
EOSQL

my $ntStmt = $dbh->prepare($ntSQL);

##first go through and remove any SNPFeatures without any variation.  Due to undoing the only strain with avariation at this position
print STDERR "Checking SNPs for sequence variation and deleting those with none\n";
foreach my $seqid (keys%snps){
  foreach my $loc (keys%{$snps{$seqid}}){
    if(scalar(keys%{$snps{$seqid}->{$loc}->{alleles}}) <= 1){  ##there is no variability here ...only 1 allele
      &deleteSnp($snps{$seqid}->{$loc}->{na_feature_id});
      delete $snps{$seqid}->{$loc};
    }
  }
}

print STDERR "  Deleted $ctDelSnp SNPs with no sequence variation\n";

my $ctSnps = 0;
###we need to do this a strain at a time rather then a SNP at a time. We will be printing sqlLoader lines for each strain/snp so can print as we find them.
##If the varscan file isn't found then track strains and generate SNP based on DB consensus.
my %missingVS;
foreach my $relid (keys%strains){
  print STDERR "Processing strain $strains{$relid}\n";
  my $f = "$strains{$relid}.varscan.cons";
  if(-e "$varscanDir/$f" || -e "$varscanDir/$f.gz"){
    if(-e "$varscanDir/$f"){
      open(F, "$varscanDir/$f") || die "unable to open file $varscanDir/$f\n"; 
    }else{
      open(F, "zcat $varscanDir/$f.gz |") || die "unable to open file $varscanDir/$f.gz\n";
    }
    my $strain = $strains{$relid};
    print STDERR "Processing file $f for strain $strain\n";
    my $ctLines = 0;
    while(<F>){
      next if /^Chrom\s+Position/;
      $ctLines++;
      print STDERR "$f: Processed $ctLines\n" if ($verbose && $ctLines % 1000000 == 0);
      chomp;
      my @tmp = split("\t",$_);
      next if (!$snps{$tmp[0]}->{$tmp[1]} || $snps{$tmp[0]}->{$tmp[1]}->{strains}->{$relid});
      ##snp here and not present in this strain .... only add if like reference as already processed for snps 
      my $reference = $snps{$tmp[0]}->{$tmp[1]}->{ref};
      print STDERR "WARNING: $tmp[0]:$tmp[1] - reference alleles not same ($tmp[2] - $reference)\n" unless $tmp[2] eq $reference;
      next if $tmp[3] ne $reference;
      #    print STDERR "Identified coverage snp $tmp[0]:$tmp[1] for $strain\n" if $verbose;
      
      ##here we just want to print out the sqlLoader row ....
      my $coverage = &getCoverage(\@tmp);
      my $allelePerc = &getPercent(\@tmp);
      next if $allelePerc < $minAllelePercent;
      &printLine($naseq{$tmp[0]},$snps{$tmp[0]}->{$tmp[1]}->{id},$snps{$tmp[0]}->{$tmp[1]}->{na_feature_id},$reference,$snps{$tmp[0]}->{$tmp[1]}->{product},$relid,$coverage,$allelePerc);
    }
    close F;
  }else{
    print STDERR "Unable to find file for strain $strains{$relid} ($f) in $varscanDir so getting consensus from DB\n";
    $missingVS{$relid} = $strains{$relid};
  }
}

##now if there are missing strains from the db, loop through and generate sqlLoader lines.
print STDERR "Processing the ".scalar(keys%missingVS)." strains for which we had no varscan file\n";
if(scalar(keys%missingVS) >= 1){
  foreach my $seqid (keys%snps){
    foreach my $loc (keys%{$snps{$seqid}}){
      ##now loop through the strains and if not present here generate snp
      my $snpid = $snps{$seqid}->{$loc}->{id};
      my $refna = $snps{$seqid}->{$loc}->{ref};
      foreach my $dbrelid (keys%missingVS){
        next if $snps{$seqid}->{$loc}->{strains}->{$dbrelid}; ##already have this one
        my $stNa = &getNt($loc,$dbrelid == $referenceDbRelId ? $seqid : $seqid . ".".$missingVS{$dbrelid},$dbrelid);
        if($stNa eq $refna){
          ##print here
          &printLine($naseq{$seqid},$snpid,$snps{$seqid}->{$loc}->{na_feature_id},$refna,$snps{$seqid}->{$loc}->{product},$dbrelid,undef,undef);
        }
      }
    }
  }
}

$db->logout();
close O;

print "$ctSv SeqVars exported, $ctDelSnp SNPs deleted due to no variability: commit is ".($noCommit ? "off" : "on")."\n";

##(na_sequence_id,subclass_view,name,sequence_ontology_id,parent_id,external_database_release_id,source_id,organism,strain,phenotype,product,allele,matches_reference,coverage,allele_percent,modification_date,user_read,user_write,group_read,group_write,other_read,other_write,row_user_id,row_group_id,row_project_id,row_alg_invocation_id)
sub printLine {
  my($na_sequence_id,$snp_source_id,$parent_id,$reference_na,$reference_aa,$ext_rel_id,$coverage,$allele_percent) = @_;
  print O "$na_sequence_id 'SeqVariation' 'SNP' $sequence_ontology_id $parent_id ";
  print O "$ext_rel_id '$snp_source_id' '$referenceOrganism' '$strains{$ext_rel_id}' 'wild_type' '$reference_aa' '$reference_na' ";
  print O "1 '$coverage' '$allele_percent' 1 1 1 1 1 0 $row_user_id $row_group_id $row_project_id ".($algIds{$ext_rel_id} ? $algIds{$ext_rel_id} : 1)."\n";
  $ctSv++;
  print STDERR "$ctSv rows written\n" if $ctSv % 10000 == 0;

}

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

sub deleteSnp {
  my($na_feature_id) = @_;
  print "Deleting SNPFeature $na_feature_id\n" if $verbose;
  ##first the seqVars
  $ctDelSeqVar += $dbh->do("delete from DoTS.NaFeature where parent_id = $na_feature_id") or die $dbh->errstr;
  ##then the nalocations
  $ctDelNaLoc += $dbh->do("delete from DoTS.NaLocation where na_feature_id = $na_feature_id") or die $dbh->errstr;
  ##then the snp features
  $ctDelSnp += $dbh->do("delete from DoTS.SnpFeature where na_feature_id = $na_feature_id") or die $dbh->errstr;

  if($noCommit){
    $dbh->rollback();
  }else{
    $dbh->commit();
  }
}


sub getCoverage {
  my($line) = @_;
  return $line->[4] + $line->[5];
}

sub getPercent {
  my($line) = @_;
  chop $line->[6];
  return $line->[2] eq $line->[3] ? 100 - $line->[6] : $line->[6];
}
