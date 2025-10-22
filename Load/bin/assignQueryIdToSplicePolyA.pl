#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | broken
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | broken
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

## Update the query_id and utr_length (end_b) in apidb.nextgenseq_align for George Cross's data
## NOTE: will delete those splice sites that are contained within genes and do not align to the 
## genome uniquely

## Brian Brunk 2/1/2010

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;
use CBIL::Bio::SequenceUtils;

my ($sample,$verbose,$gusConfigFile,$extDbSpecs,$type,$organism,$commit);
&GetOptions("verbose|v!"=> \$verbose,
            "organism|o=s" => \$organism,
            "sample|s=s" => \$sample,
            "type|t=s" => \$type,
            "extDbSpecs|r=s" => \$extDbSpecs,
            "gusConfigFile|c=s" => \$gusConfigFile,
            "commit!" => \$commit,
           );

die "you MUST provide --organism|o <external_db_name for genome> --sample|s <sample name> --extDbSpecs|r <RNA Seq extDbSpecs> --type|t <(polyA|splice)> and optionally --gusConfigFile|c --verbose|v on command line\n" unless ($type && $sample && $extDbSpecs && $organism); 

my ($extDbName,$extDbRlsVer)=split(/\|/,$extDbSpecs);

my $sql = "select external_database_release_id from sres.externaldatabaserelease d, sres.externaldatabase x where x.name = '${extDbName}' and x.external_database_id = d.external_database_id and d.version = '${extDbRlsVer}'";

my $ext_db_rel_id= `getValueFromTable --idSQL \"$sql\"`;


my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName());

my $dbh = $db->getQueryHandle();

my %query;
my %subject;
my $stmt;

my $geneModelQuery = "select source_id,na_sequence_id,
CASE WHEN coding_start is not null THEN coding_start ELSE CASE WHEN strand = 'forward' THEN start_min ELSE end_max END END as coding_start,
CASE WHEN coding_end is not null THEN coding_end ELSE CASE WHEN strand = 'forward' THEN end_max ELSE start_min END END as coding_end,
decode(strand,'forward','+','reverse','-') as strand,
CASE WHEN coding_start is not null THEN 'yes' ELSE 'no' END as protein_coding
from webready.GeneAttributes_p
where organism = '$organism'
and product not like '\%unlikely\%'
order by na_sequence_id,strand,coding_start";

my $geneStmt = $dbh->prepare($geneModelQuery);

my $outsideQuery = $type eq 'splice' ? "select nextgenseq_align_id,na_sequence_id,query_id,strand,CASE WHEN strand = '+' THEN end_a ELSE start_a END as location,intron_size, genome_matches
  from apidb.nextgenseq_align 
  where external_database_release_id = ?
  and sample = ?" :
"select nextgenseq_align_id,na_sequence_id,query_id,strand,CASE WHEN strand = '+' THEN start_a ELSE end_a END as location,intron_size,genome_matches
  from apidb.nextgenseq_align 
  where external_database_release_id = ?
  and sample = ?";

my $oStmt = $dbh->prepare($outsideQuery);

my $updateQuery = "update apidb.nextgenseq_align
set query_id = ?,
    end_b = ?
where nextgenseq_align_id = ?";

my $upStmt = $dbh->prepare($updateQuery);

my $deleteQuery = "delete from apidb.nextgenseq_align where nextgenseq_align_id = ?";

my $delStmt = $dbh->prepare($deleteQuery);

## (length,start,na_sequence_id)
my $seqQuery = "select dbms_lob.SUBSTR(sequence,?,?)
from dots.EXTERNALNASEQUENCE 
where na_sequence_id = ?";

my $seqStmt = $dbh->prepare($seqQuery);

my %stop = (TAG => 1,
            TAA => 1,
            TGA => 1);


##first get all gene information.
$geneStmt->execute();
my %genes;
my $ctGenes = 0;
while(my ($source_id,$na_sequence_id,$coding_start,$coding_end,$strand,$protein_coding) = $geneStmt->fetchrow_array()){
  push(@{$genes{$na_sequence_id}->{$strand}},{source_id => $source_id,
                                              na_sequence_id => $na_sequence_id,
                                              coding_start => $coding_start,
                                              coding_end => $coding_end,
                                              protein_coding => $protein_coding,
                                              strand => $strand});
  $ctGenes++;
}
$geneStmt->finish();
print STDERR "Retrieved ",scalar(keys%genes)," sequences containing $ctGenes genes\n" if $verbose;

##next do the mapping to the query..
my $ct = 0;
print STDERR "retrieving identifiers on which to work\n" if $verbose;
$oStmt->execute($ext_db_rel_id,$sample);
my @list;
while(my ($nextgenseq_align_id,$na_sequence_id,$query_id,$strand,$location,$intron_size, $genome_matches) = $oStmt->fetchrow_array()){

  push(@list,{nextgenseq_align_id => $nextgenseq_align_id,
              na_sequence_id => $na_sequence_id,
              query_id => $query_id,
              strand => $strand,
              location => $location,
              genome_matches => $genome_matches,
              intron_size => $intron_size});

}
$oStmt->finish();
print STDERR "processing ",scalar(@list), " total rows\n\n" if $verbose;

##now do the work ...
my $ct = 0;
foreach my $site (@list){
  $ct++;
  print STDERR "Processing $ct\n" if ($verbose && $ct % 100 == 0);
  my($gene_id,$utr_len,$newCds) = &getGeneAndDistance($site);
  ##sanity check ... is this different than what George called?
  if($site->{query_id} =~ /-(\d+)\*?\(/){
    my $dist = $1;
    if($dist != $utr_len && $site->{genome_matches} == 1){
      print STDERR "NOTICE: utr length for $site->{query_id} determined different than from George Cross\n" if $verbose;
    }
  }
  print STDERR "$site->{query_id} ($site->{strand}): $gene_id-$utr_len$newCds($site->{intron_size})\n" if $gene_id && $utr_len;
  if($utr_len > 2000 && $type eq 'splice'){
    print STDERR "ERROR: utr length ($utr_len) too long for $site->{query_id} .. $site->{genome_matches} genome matches\n";
    ##should delete this site
    $delStmt->execute($site->{nextgenseq_align_id});
    next;
  }

  my $queryId = "$gene_id-$utr_len$newCds($site->{intron_size})";
  if($newCds eq '*') {
    $queryId = $queryId . " - Alternate CDS Start";
  }

  $upStmt->execute($queryId, $utr_len,$site->{nextgenseq_align_id});
}
if($commit){
  $dbh->do("commit");
}else{
  $dbh->do("rollback");
}

$db->logout();

sub getGeneAndDistance {
  my($site) = @_;
  if(!$genes{$site->{na_sequence_id}}->{$site->{strand}}){
    print STDERR "ERROR: there are no genes on this strand for $site->{query_id}\n";
    ##perhaps should delete this one??
    $delStmt->execute($site->{nextgenseq_align_id});
    return;
  }
  if($type eq 'splice'){
    if($site->{strand} eq '+'){
      foreach my $gene (@{$genes{$site->{na_sequence_id}}->{'+'}}){
        next if $gene->{coding_end} < $site->{location};
        return ($gene->{source_id}, $gene->{coding_start} - $site->{location} - 2) if($gene->{protein_coding} eq 'no'); 
        my($gene_id,$utr_len,$newCds) = $gene->{coding_start} < $site->{location} ? &findInternalATG($gene,$site) : &findUpstreamATG($gene,$site);
        next if !$gene_id  && !$utr_len;  ##if doesn't find internal ATG
        return ($gene_id,$utr_len,$newCds);
      }
    }else{
#      print STDERR "processing $site->{query_id}($site->{strand}) on the negative strand\n";
      foreach my $gene (reverse(@{$genes{$site->{na_sequence_id}}->{'-'}})){
        next if $gene->{coding_end} > $site->{location};
        ##check to see if is in the 3' half of the gene .. if so, go to the next one
        return ($gene->{source_id}, $site->{location} - $gene->{coding_start} - 2) if($gene->{protein_coding} eq 'no'); 
        my($gene_id,$utr_len,$newCds) = $gene->{coding_start} > $site->{location} ? &findInternalATG($gene,$site) : &findUpstreamATG($gene,$site);
        next if !$gene_id  && !$utr_len;  ##if doesn't find internal ATG
        return ($gene_id,$utr_len,$newCds);
      }
    } 
  }elsif($type eq 'polyA'){
    if($site->{strand} eq '+'){
      my @genes = @{$genes{$site->{na_sequence_id}}->{'+'}};
      for(my $a = 0; $a < scalar(@genes);$a++){
        next if $genes[$a]->{coding_end} < $site->{location}; ##note that will stop if within cds ... assign to upstream gene
        return ($genes[$a-1]->{source_id}, $site->{location} - $genes[$a-1]->{coding_end});
      }
    }else{
#      print STDERR "processing $site->{query_id}($site->{strand}) on the negative strand\n";
      my @genes = reverse(@{$genes{$site->{na_sequence_id}}->{'-'}});
      for(my $a = 0; $a < scalar(@genes);$a++){
        next if $genes[$a]->{coding_end} > $site->{location}; ##note that will stop if within cds ... assign to upstream gene
        return ($genes[$a-1]->{source_id}, $genes[$a-1]->{coding_end} - $site->{location});

      }
    } 
  }else {
    die "Unknown type $type\n";
  }
}

##get sequence of cds and look for first ATG downstream of site;
sub findInternalATG {
  my($gene,$site) = @_;
#  print STDERR "-------- processing internal site for - strand ---------\n" if $gene->{strand} eq '-';
  ## if this site is not a unique alignment, delete it from the db?? check with george first ... all alignments are good so don't delete!
#  if($site->{genome_matches} > 1){
#    print STDERR "DELETING internal non-unique splice site $site->{nextgenseq_align_id}, $site->{query_id}\n";
#    $delStmt->execute($site->{nextgenseq_align_id});
#    return;
#  }
  ##first get the sequence
  my $start = $gene->{strand} eq '+' ? $gene->{coding_start} : $gene->{coding_end};
  my $length = abs($gene->{coding_end} - $gene->{coding_start} - 1);
  my $seq = &getSequence($gene->{na_sequence_id},$start,$length,$gene->{strand});
#  print STDERR "ERROR: CDS for $gene->{source_id} does NOT begin with ATG ... ".substr($seq,0,20)."\n" unless substr($seq,0,3) eq 'ATG';

  ##now walk along and look for first ATG past splice site
  my $spliceLoc = abs($site->{location} - $gene->{coding_start});
  my $a = 0;
  my $haveNew = 0;
  for($a;$a < length($seq); $a += 3){
    next unless $a >= $spliceLoc;
    if(substr($seq,$a,3) eq 'ATG'){
      $haveNew = 1;
      last;
    }
  }
  return unless $haveNew; ##no internal atg so must be the next gene
  print STDERR "Found internal splice site and ATG for $site->{query_id} in gene $gene->{source_id}\n";

  my $newCodingStart = $gene->{strand} eq '+' ? $gene->{coding_start} + $a : $gene->{coding_start} - $a;

  return ($gene->{source_id},abs($newCodingStart - $site->{location}) - 2,$haveNew ? '*' : '');
}

##get upstream 2 kb and walk back looking for most upstream atg before encounter stop codon
sub findUpstreamATG {
  my($gene,$site) = @_;
  ## should delete this site if it is > 4000 bp upstream of gene and non-unique after find most upstream atg
  my $length = 3000;
  my $start = $gene->{strand} eq '+' ? ($gene->{coding_start} - $length) + 3 : $gene->{coding_start} - 2;
  my $seq = &getSequence($gene->{na_sequence_id},$start,$length,$gene->{strand});
  #  print STDERR "ERROR: upstream for $gene->{source_id}($gene->{strand}) does NOT end with ATG ... ".substr($seq,$length - 20,30)."(". substr($seq,$length - 3,3).")\n" unless substr($seq,$length - 3,3) eq 'ATG';
  
  my $a = 6;  ##we'll start here which is 1 codon upstream since 3 = ATG;
  my $ups;
  my $sitelen = abs($site->{location} - $gene->{coding_start}) - 2;
  for($a; $a < $sitelen; $a += 3){
    my $s = substr($seq,$length - $a,3);
    last if $stop{$s};
    $ups = $a - 3 if $s eq 'ATG';
  }
  print STDERR "FOUND ATG $ups bp upstream for $gene->{source_id}\n" if $ups;
  
  my $cod_start = $ups ? $gene->{strand} eq '+' ? $gene->{coding_start} - $ups : $gene->{coding_start} + $ups : $gene->{coding_start};
  
  return ($gene->{source_id},abs($cod_start - $site->{location}) - 2, $ups ? '*' : '');
}

sub getSequence {
  my($na_sequence_id,$start,$length,$strand,$tries) = @_;
  my $tmpSeq;
  
  #  $seqStmt->execute($len > 4000 ? 4000 : $len,$start,$na_sequence_id);
  #  while(my($rawSeq) = $seqStmt->fetchrow_array()){
  #    $tmpSeq .= $rawSeq;
  #  }
  for (my $s = $start; $s < $start + $length;$s += 4000) {
    $seqStmt->execute($s + 4000 <= $start + $length ? 4000 : $length + $start - $s,$s,$na_sequence_id);
    while (my($str) = $seqStmt->fetchrow_array()) {
      $tmpSeq .= $str;
    }
  }
  my $seq = $strand eq '+' ? $tmpSeq : CBIL::Bio::SequenceUtils::reverseComplementSequence($tmpSeq);
  $seq =~ tr/a-z/A-Z/;
  
  return $seq;
  
}
