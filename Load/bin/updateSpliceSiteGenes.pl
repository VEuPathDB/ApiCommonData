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
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | broken
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

## to update 'first_atg_location' and 'dist_to_first_atg' columns in apidb.spliceSiteGenes table

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;
use CBIL::Bio::SequenceUtils;

my ($sample,$verbose,$gusConfigFile,$commit);
&GetOptions("verbose|v!"=> \$verbose,
            "gusConfigFile|c=s" => \$gusConfigFile,
            "commit!" => \$commit,
           );

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);
my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName());
my $dbh = $db->getQueryHandle();


my $geneModelQuery = "SELECT source_id, na_sequence_id, decode(strand,'forward','+','reverse','-') as strand,
CASE WHEN coding_start is not null THEN coding_start ELSE CASE WHEN strand = 'forward' THEN start_min ELSE end_max END END as coding_start,
CASE WHEN coding_end is not null THEN coding_end ELSE CASE WHEN strand = 'forward' THEN end_max ELSE start_min END END as coding_end
FROM webready.GeneAttributes
WHERE source_id in  (SELECT source_id FROM apidb.SpliceSiteGenes)
ORDER BY na_sequence_id,strand,coding_start";

my $geneStmt = $dbh->prepare($geneModelQuery);

my $splicesitesQuery = "SELECT source_id,location, strand, dist_to_cds, splice_site_feature_id
FROM apidb.SpliceSiteGenes";

my $ssStmt = $dbh->prepare($splicesitesQuery);

my $updateQuery = "UPDATE apidb.SpliceSiteGenes
SET first_atg_location = ?,
    dist_to_first_atg = ?
WHERE splice_site_feature_id = ?";

my $upStmt = $dbh->prepare($updateQuery);

my $seqQuery = "SELECT dbms_lob.SUBSTR(sequence,?,?)
FROM dots.ExternalNASequence
WHERE na_sequence_id = ?";

my $seqStmt = $dbh->prepare($seqQuery);

my %stop = (TAG => 1,
            TAA => 1,
            TGA => 1);

# get gene info
$geneStmt->execute();
my %genes;
my $ctGenes = 0;
while(my ($source_id,$na_sequence_id,$strand,$coding_start,$coding_end) = $geneStmt->fetchrow_array()){
  push(@{$genes{$source_id}},{source_id => $source_id,
                              na_sequence_id => $na_sequence_id,
                              strand => $strand,
                              coding_start => $coding_start,
                              coding_end => $coding_end});
  $ctGenes++;
}
$geneStmt->finish();
print STDERR "Retrieved ",scalar(keys%genes)," $ctGenes genes\n" if $verbose;

# get splice site info
my $ct = 0;
$ssStmt->execute();
my @list;

while(my ($source_id,$location,$strand,$dist_to_cds,$splice_site_feature_id)= $ssStmt->fetchrow_array()){
    push(@list,{source_id=>$source_id,
		location=>$location,
		strand => $strand,
		dist_to_cds => $dist_to_cds,
		splice_site_feature_id => $splice_site_feature_id});
  }
$ssStmt->finish();
print STDERR "Retrieved ",scalar(@list), " splice sites\n\n" if $verbose;

# work on first atg locations
my $ct = 0;
my $ctRes = 0;
my %output;

my($src_id, $loc, $feature_id, $atg_loc, $utr_len, $key);
foreach my $site (@list){
  $ct++;
  print STDERR "Processing $ct\n" if ($verbose && $ct % 500 == 0);
$key = $site->{source_id}.$site->{location};
  if ( $output{$key}{'splicesite_loc'} ) {
    $feature_id = $site->{splice_site_feature_id};
    $atg_loc = $output{$key}{'atg_loc'};
    $utr_len = $output{$key}{'utr_len'};
    #print STDERR "GETTING value from hash\n";
  } else {
    ($src_id, $loc, $feature_id, $atg_loc, $utr_len) = &getAgtLocation($site);
    $output{$key}{'splicesite_loc'} = $loc;
    $output{$key}{'atg_loc'} = $atg_loc;
    $output{$key}{'utr_len'} = $utr_len;
  }
  if ($atg_loc) {
    $ctRes++;
    print STDERR "RESULT: $feature_id,$atg_loc,$utr_len\n" if ($verbose && $ct % 100 == 0);

    $upStmt->execute($atg_loc,$utr_len,$feature_id);
    $dbh->do("commit") if (($ctRes % 100 == 0) && $dbh->do("commit"));
  }
}
print "Processed $ctRes splice sites\n";
if($commit){
  $dbh->do("commit");
}else{
  $dbh->do("rollback");
}

$db->logout();


sub getAgtLocation {
  my($site) = @_;
  my($feature_id,$atg_loc,$utr_len);

  foreach my $gene (@{$genes{$site->{source_id}}}) {
#  my $gene = $genes{$site->{source_id}};
    if ( ($site->{strand}) eq '+'){
      ($feature_id,$atg_loc,$utr_len) = ($gene->{coding_start} > $site->{location}) ?  &findUpstreamATG($gene,$site) : &findInternalATG($gene,$site);
    } else {
      ($feature_id,$atg_loc,$utr_len)= ($gene->{coding_start} < $site->{location}) ?  &findUpstreamATG($gene,$site) : &findInternalATG($gene,$site);
    }
    return ($site->{source_id},$site->{location}, $feature_id, $atg_loc, $utr_len);
  }
}



##get sequence of cds and look for first ATG downstream of site;
sub findInternalATG {
  my ($gene,$site) = @_;
  my $start = $gene->{strand} eq '+' ? $gene->{coding_start} : $gene->{coding_end};
  my $length = abs($gene->{coding_end} - $gene->{coding_start} - 1);
  my $seq = &getSequence($gene->{na_sequence_id},$start,$length,$gene->{strand});

  # walk along and look for first ATG past splice site
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
  #print STDERR "Found internal splice site and ATG for $site->{location} in gene $gene->{source_id}\n";

  my $newCodingStart = $gene->{strand} eq '+' ? $gene->{coding_start} + $a : $gene->{coding_start} - $a;
  #print STDERR "OUT: ($gene->{source_id}, " . abs($newCodingStart - $site->{location}) . "\n";

  return ($site->{splice_site_feature_id}, $newCodingStart, abs($newCodingStart - $site->{location}));
}


##go upstream 6 kb and walk back looking for most upstream atg before encounter stop codon
sub findUpstreamATG {
  my($gene,$site) = @_;
  my $length = 6000;
  my $start = $gene->{strand} eq '+' ? ($gene->{coding_start} - $length) : $gene->{coding_start} + 1;
  my $seq = &getSequence($gene->{na_sequence_id},$start,$length,$gene->{strand});
  my $a = 3;
  my $ups;
  my $sitelen = abs($site->{location} - $gene->{coding_start}) - 2;
  for($a; $a < $sitelen; $a += 3){
    my $s = substr($seq,$length - $a,3);
    last if $stop{$s};
    $ups = $a  if $s eq 'ATG';
  }
  #print STDERR "FOUND ATG $ups bp upstream for $gene->{source_id}\n\n" if $ups;

  my $cod_start = $ups ? $gene->{strand} eq '+' ? $gene->{coding_start} - $ups : $gene->{coding_start} + $ups : $gene->{coding_start};
  #print STDERR "UP OUT: ($gene->{source_id}, " . (abs($cod_start - $site->{location})) . "\n";

  if ($cod_start) {
    return ($site->{splice_site_feature_id}, $cod_start, abs($cod_start - $site->{location}));
  } else {
    return ($site->{splice_site_feature_id}, $gene->{coding_start}, $site->{dist_to_cds});
  }
}

sub getSequence {
  my($na_sequence_id,$start,$length,$strand,$tries) = @_;
  my $tmpSeq;

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
