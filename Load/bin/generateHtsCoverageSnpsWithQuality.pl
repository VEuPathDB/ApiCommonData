#!/usr/bin/perl

## to be run after all HTS snps have been loaded.  

## note: can get the strain / external_database_release_id pairs for all strains for this reference genome from seqVariation or potentially study.sample would be quicker
## then for each hts_snp in SNPFeature, if an ext_db_id is not there do substring in extnaseq to pull out base and if like reference, add seqvariation.

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;

my $varscanDir;
my $outputFile = 'coverageSnps.gff';
my $gusConfigFile = $ENV{GUS_HOME} ."/config/gus.config";
my $referenceOrganism;
my $referenceStrain;
my $verbose;
my $noCommit;

&GetOptions("gusConfigFile|gc=s"=> \$gusConfigFile,
            "varscanDir|vd=s"=> \$varscanDir,
            "outputFile|o=s"=> \$outputFile,
            "verbose|v!"=> \$verbose,
            "referenceOrganism|r=s"=> \$referenceOrganism,
            "referenceStrain|s=s"=> \$referenceStrain,
            "noCommit|nc!"=> \$noCommit,
            );

if (!$referenceOrganism){
die <<endOfUsage;
generateCoverageSnps.pl usage:

  generateCoverageSnpsWithQuality.pl --varscanDir|vd <directory containing the varscan consensus files> --gusConfigFile|gc <gusConfigFile [\$GUS_HOME/config/gus.config] --referenceOrganism <organism on which SNPs are predicted .. ie aligned to .. in dots.snpfeature.organism> --outputFile|o <outputFile [coverageSnps.gff]> --verbose|v!\n
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

##need to get the list of strains,  external_db_ids and row_algorithm_invocation_ids
my $strainSQL = <<SQL;
select sv.strain,sv.external_database_release_id, sv.row_algorithm_invocation_id,sv.sequence_ontology_id,row_user_id,row_group_id,row_project_id,count(*)
from dots.snpfeature sf, DOTS.seqvariation sv,SRES.externaldatabase d, SRES.externaldatabaserelease rel
where d.name = 'InsertSnps.pm NGS SNPs INTERNAL'
and rel.external_database_id = d.external_database_id
and sf.external_database_release_id = rel.external_database_release_id
and sf.organism = '$referenceOrganism'
and sv.parent_id = sf.na_feature_id
group by sv.strain,sv.external_database_release_id,sv.row_algorithm_invocation_id,sv.sequence_ontology_id,row_user_id,row_group_id,row_project_id
SQL

my $strainStmt = $dbh->prepare($strainSQL);
$strainStmt->execute();
my %strains;
my %algIds;
my %del;  ##keep track of numbers of deleted rows
my $ctSv = 0;  ##count seqvars printed
my $sequence_ontology_id;
my $row_user_id;
my $row_group_id;
my $row_project_id;
while(my($strain,$rel_id,$alg_id,$seq_ont_id,$user_id,$group_id,$project_id,$count) = $strainStmt->fetchrow_array()){
  print STDERR "Strain: ($strain,$rel_id,$alg_id,$alg_id,$seq_ont_id,$count)\n" if $verbose;
  $strains{$rel_id} = $strain;
  $algIds{$rel_id} = $alg_id;
  if($sequence_ontology_id != $seq_ont_id){
    print STDERR "WARNING: sequence_ontology_id differs ($sequence_ontology_id ne $seq_ont_id)\n" if $sequence_ontology_id;
    $sequence_ontology_id = $seq_ont_id;
  }
  if($row_user_id != $user_id){
    print STDERR "WARNING: row_user_id differs ($row_user_id ne $user_id)\n" if $row_user_id;
    $row_user_id = $user_id;
  }
  if($row_group_id != $group_id){
    print STDERR "WARNING: row_group_id differs ($row_group_id ne $group_id)\n" if $row_group_id;
    $row_group_id = $group_id;
  }
  if($row_project_id != $project_id){
    print STDERR "WARNING: row_project_id differs ($row_project_id ne $project_id)\n" if $row_project_id;
    $row_project_id = $project_id;
  }
  
}

print STDERR "Found ".scalar(keys%strains)." strains in the database\n";

die "ERROR: unable to identify any strains for referenceOrganism $referenceOrganism\n" unless scalar(keys%strains) > 0;

my $snpSQL = <<EOSQL;
select sf.na_sequence_id,sf.na_feature_id, sf.source_id as snp_id,s.source_id as seq_id,l.start_min,sf.reference_na,sf.reference_aa, sv.allele,sv.external_database_release_id,sf.reference_strain,sv.allele
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
  $algIds{$tmpEx[0]} = 1; ##this will be a problem for the undo process but there should always already be a reference strain ... and if there isn't we'll undo this when we do a root undo for hts snps for this organism.
}

my $ntSQL = <<EOSQL;
select dbms_lob.substr(sequence,1,?)
from dots.nasequence
where source_id = ?
and external_database_release_id = ?
EOSQL

my $ntStmt = $dbh->prepare($ntSQL);

##first go through and remove any SNPFeatures without any variation.  Due to undoing the only strain with avariation at this position
foreach my $seqid (keys%snps){
  foreach my $loc (keys%{$snps{$seqid}}){
    if(scalar(keys%{$snps{$seqid}->{$loc}->{alleles}}) <= 1){  ##there is no variability here ...only 1 allele
      &deleteSnp($snps{$seqid}->{$loc}->{na_feature_id});
      delete $snps{$seqid}->{$loc};
    }
  }
}

my $ctSnps = 0;
###we need to do this a strain at a time rather then a SNP at a time. We will be printing sqlLoader lines for each strain/snp so can print as we find them.
##If the varscan file isn't found then track strains and generate SNP based on DB consensus.
my %missingVS;
foreach my $relid (keys%strains){
  my $f = "";
  if(!-e "$varscanDir/$f" && "!$varscanDir/$f.gz"){
    print STDERR "Unable to find file for strain $strains{$relid} ($f) so getting consensus from DB\n";
    $missingVS{$relid} = $strains{$relid};
  }else{
    if(-e "$varscanDir/$f"){
      open(F, "$varscanDir/$f"); 
    }else{
      open(F, "zcat $varscanDir/$f.gz |");
    }
    my $strain = $strains{$relid};
    print STDERR "Processing file $f for strain $strain\n";
    my $ctLines = 0;
    while(<F>){
      next if /^Chrom\s+Position/;
      $ctLines++;
      print STDERR "$f: Processed $ctLines\n" if ($verbose && $ctLines % 100000 == 0);
      chomp;
      my @tmp = split("\t",$_);
      next if (!$snps{$tmp[0]}->{$tmp[1]} || $snps{$tmp[0]}->{$tmp[1]}->{strains}->{$strain});
      ##snp here and not present in this strain .... only add if like reference as already processed for snps 
      my $reference = $snps{$tmp[0]}->{$tmp[1]}->{ref};
      print STDERR "WARNING: $tmp[0]:$tmp[1] - reference alleles not same ($tmp[2] - $reference)\n" unless $tmp[2] eq $reference;
      next if $tmp[3] ne $reference;
      #    print STDERR "Identified coverage snp $tmp[0]:$tmp[1] for $strain\n" if $verbose;
      
      ##here we just want to print out the sqlLoader row ....
      my $coverage = &getCoverage(\@tmp);
      my $allelePerc = &getPercent(\@tmp);
      &printLine($naseq{$tmp[0]},$snps{$tmp[0]}->{$tmp[1]}->{id},$snps{$tmp[0]}->{$tmp[1]}->{na_feature_id},$reference,$snps{$tmp[0]}->{$tmp[1]}->{product},$relid,$coverage,$allelePerc);
    }
    close F;
  }
}

##now if there are missing strains from the db, loop through and generate sqlLoader lines.
if(scalar(keys%missingVS) >= 1){
  foreach my $seqid (keys%snps){
    foreach my $loc (keys%{$snps{$seqid}}){
      ##now loop through the strains and if not present here generate snp
      my $snpid = $snps{$seqid}->{$loc}->{id};
      my $refna = $snps{$seqid}->{$loc}->{ref};
      foreach my $dbrelid (keys%missingVS){
        next if $snps{$seqid}->{$loc}->{strains}->{$dbrelid}; ##already have this one
        my $stNa = &getNt($loc,$dbrelid == $referenceDbRelId ? $seqid : $seqid . ".".$missingVS{$dbrelid},$dbrelid);
        #      print STDERR "'$dbrelid' -> db: '$snps{$seqid}->{$loc}->{strains}->{$dbrelid}'\n";
        if($stNa eq $refna){
          ##print here
          &printLine($naseq{$seqid},$snpid,$snps{$seqid}->{$loc}->{na_feature_id},$refna,$snps{$seqid}->{$loc}->{product},$dbrelid,$coverage,$allelePerc);
        }
      }
    }
  }
}

$db->logout();
close O;

print "$ctSV SeqVars exported, $del{snpFeat} SNPs deleted due to no variability: commit is ".($noCommit ? "off" : "on")."\n";

##(na_feature_id,na_sequence_id,subclass_view,name,sequence_ontology_id,parent_id,external_database_release_id,source_id,organism,strain,phenotype,product,allele,matches_reference,coverage,allele_percent,modification_date,user_read,user_write,group_read,group_write,other_read,other_write,row_user_id,row_group_id,row_project_id,row_alg_invocation_id)
sub printLine {
  my($na_sequence_id,$snp_source_id,$parent_id,$reference_na,$reference_aa,$ext_rel_id,$coverage,$allele_percent) = @_;
  print O "dots.NaFeatureImp_sq.nextval\t$na_sequence_id\tSeqVariation\tSNP\t$sequence_ontology_id\t$parent_id\t";
  print O "$ext_rel_id\t$snp_source_id\t$referenceOrganism\t$strains{$ext_rel_id}\twild_type\t$reference_aa,$reference_na\t";
  print O "1\t$coverage\t$allele_percent\t1\t1\t1\t1\t1\t0\t$row_user_id\t$row_group_id\t$row_project_id\t$algIds{$ext_rel_id}\n";
  my $ctSv++;
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
  $del{seqvar} += $dbh->do("delete from DoTS.SeqVariation where parent_id = $na_feature_id") or die $dbh->errstr;
  ##then the nalocations
  $del{naloc} += $dbh->do("delete from DoTS.NaLocation where na_feature_id = $na_feature_id") or die $dbh->errstr;
  ##then the snp features
  $del{snpfeat} += $dbh->do("delete from DoTS.SnpFeature where na_feature_id = $na_feature_id") or die $dbh->errstr;

  if($noCommit){
    $dbh->rollback();
  }else{
    $dbh->commit();
  }
}

