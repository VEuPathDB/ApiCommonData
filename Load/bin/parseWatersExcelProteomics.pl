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
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

# Special-case parser for Wastling manually curated Excel files 
# derived from SEQUEST SQT.

use strict;
use Spreadsheet::BasicRead;
use Getopt::Long qw(GetOptions);
use Data::Dumper;
$Data::Dumper::Deepcopy = 1;

my ($infile, $outfile);
my @results;
my @hitgroup;
my $havePrunedDups = 0;
my $startOfHitGroup = 1;

GetOptions( 
           "infile=s" => \$infile,
           "outfile=s" => \$outfile    
          );

if (!defined $infile || !defined $outfile) {
  usage(); exit;
}

my($prefix) = ($infile =~ /^(...)/);
print STDERR "prefix=$prefix\n";


my $runningPepCount = 0;
my $spreadSheet = Spreadsheet::BasicRead->new(fileName => $infile,
                                              skipHeadings  => 0,
                                              skipBlankRows => 0) || die "Could not open '$infile':$!";

my $header = $spreadSheet->getNextRow();
my %map;                        ## map header to array location
for (my $a=0;$a<scalar(@$header);$a++) {
  $map{$header->[$a]} = $a;
}
my $data = {};
my $official = {};
my $noFinal = {};
while (my $row = $spreadSheet->getNextRow) {
  push(@{$data->{$row->[$map{'Accession Number'}]}},$row);
}

print STDERR "Found ".scalar(keys%$data)." official models containing peptides\n";

## now need to put into the right format for writing ....
&reformatData($data);

&writeTabFile(\@results);

######################################################################
######################################################################

#do in two passes, first all with official annotation then any that had peptides without official annotation
sub reformatData {
  my($data) = @_;
  foreach my $id (keys%$data){
#    print STDERR "reformatting $id\n";
    my @rows = &getRows($id);
    my $h = &getMetaData($id,\@rows);
    &getPeptideData($h,\@rows);
    push(@results,$h);
  }
}

## gets the rows to be operated on ...
sub getRows {
  my($id) = @_;
  return @{$data->{$id}};
}

sub getMetaData {
  my($id,$rows) = @_;
#  print STDERR "getting metadata from $row->[$map{tigr_final_match}]\n";
  my $h = { 'source_id' => $id,
            'description' => &getDescription($rows),
            'percentCoverage' => '',
            'sequenceCount' => &getSequenceCount($rows),
            'spectrumCount' => &getSpectrumCount($rows),
            'sourcefile' => $infile,
            'seqMolWt' => &getMolWt($rows),
            'score' => '',
	    'seqPI' => '',
          };
  return $h;
}

sub getDescription {
  my($rows) = @_;
  foreach my $row (@$rows){
    return $row->[$map{'Protein Name'}] if $row->[$map{'Protein Name'}];
  }
}
sub getProtScore {
  my($rows) = @_;
  foreach my $row (@$rows){
    return $row->[$map{'protein score'}] if $row->[$map{'protein score'}];
  }
}

sub getMolWt {
  my($rows) = @_;
  foreach my $row (@$rows){
    return $row->[$map{'Mol Wt'}] if $row->[$map{'Mol Wt'}];
  }
}

sub getCoverage {
  my($rows) = @_;
  foreach my $row (@$rows){
    return $row->[$map{Coverage}] if $row->[$map{Coverage}];
  }
}
sub getSequenceCount {
  my($rows) = @_;
  foreach my $row (@$rows){
    return $row->[$map{'# peptides'}] if $row->[$map{'# peptides'}]; 
  }
}

sub getPercentCoverage{
  my($rows) = @_;
  foreach my $row (@$rows){
    return $row->[$map{'Percent Coverage'}] if $row->[$map{'Percent Coverage'}]; 
  }
}

sub getSeqPI{
  my($rows) = @_;
  foreach my $row (@$rows){
    return $row->[$map{'Protein pI'}] if $row->[$map{'Protein pI'}]; 
  }
}

# don't have spectrum count for this analysis ... return sequence ct.
sub getSpectrumCount {
  my($rows) = @_;
 foreach my $row (@$rows){
    return $row->[$map{'# peptides'}] if $row->[$map{'spectral count'}]; 
  }
}

sub getPeptideData {
  my($h,$rows) = @_;
  foreach my $p (@$rows){
#    print STDERR "getting peptide data for $p->[$map{contig_sequence}]\n";
     
      my $processed_sequence =  $p->[$map{Sequence}];
      $processed_sequence=~ s/\[\d+\]//g;
    my $pep = {'sequence' => $processed_sequence,
               'ions_score' => $p->[$map{'score'}],
               'delta' => $p->[$map{'Peptide delta score'}],
               'mr_calc' => $p->[$map{'MCR (Mass charge ratio)'}],

              };
    push(@{$h->{peptides}},$pep);
  }
}

sub writeTabFile {
  my($results) = @_;
  ($outfile) ? 
    (open (TABF, ">$outfile") or die "could not open $outfile for writing\n") :
      (open (TABF, ">&STDOUT") or die "could not write to stdout\n");
    
  TABF->autoflush(1);
  for my $h (@$results) {
    print TABF 
      '# source_id',      "\t",
        'description',      "\t",
          'seqMolWt',         "\t",
            'seqPI',            "\t",
              'score',            "\t",
                'percentCoverage',  "\t",
                  'sequenceCount',    "\t",
                    'spectrumCount',    "\t",
                      'sourcefile',       "\n",
                        ;

    print TABF
      $h->{source_id},       "\t",
        $h->{description},     "\t",
          $h->{seqMolWt},        "\t",
            $h->{seqPI},           "\t",
              $h->{score},           "\t",
                $h->{percentCoverage}, "\t",
                  $h->{sequenceCount},   "\t",
                    $h->{spectrumCount},   "\t",
                      $h->{sourcefile},      "\n",
                        ;
    
    
    print TABF
      '## start',      "\t",
        'end',           "\t",
          'observed',      "\t",
            'mr_expect',     "\t",
              'mr_calc',       "\t",
                'delta',         "\t",
                  'miss',          "\t",
                    'sequence',      "\t",
                      'modification',  "\t",
                        'query',         "\t",
                          'hit',           "\t",
                            'ions_score',    "\n",
                              ;
    
    for my $pep (@{$h->{peptides}}) {
      print TABF
        $pep->{start},         "\t",
          $pep->{end},           "\t",
            $pep->{observed},      "\t",
              $pep->{mr_expect},     "\t",
                $pep->{mr_calc},       "\t",
                  $pep->{delta},         "\t",
                    $pep->{miss},          "\t",
                      $pep->{sequence},      "\t",
                        $pep->{modification},  "\t",
                          $pep->{query},         "\t",
                            $pep->{hit},           "\t",
                              $pep->{ions_score},    "\n",
                                ;
      $runningPepCount++;
    }
  }
}

sub parseOneHitDefinition {
  my $row = shift;
  my $h = {};
  ($h->{locus},
   $h->{providedSpectrumCount},
   $h->{seqMolWt},
   $h->{seqPI},
   $h->{description_junk}) = @$row;
     
  ($h->{source_id}, $h->{secondary_id}) = split /\s*\|\s*/, $h->{locus};
  MUNG_IDS($h->{source_id});
  MUNG_IDS($h->{secondary_id});
    
  # for compat with InsertMascotSummaries which looks does lookups on 
  # source_id and description
  $h->{description} = $h->{secondary_id};
    
  return $h;
}

sub parseOnePeptide {
  my $row = shift;
  my $pep = {};

  ($pep->{unique},
   $pep->{xcorr},
   $pep->{mr_expect},
   $pep->{mr_calc},
   $pep->{spr},
   $pep->{sequence}) = @$row;
     
  $pep->{ions_score} = "XCorr: $pep->{xcorr}, SpR: $pep->{spr}"; 
  $pep->{sequence} = adjustSequence($pep->{sequence});

  return $pep;
}

# The original Excel can have a group of locus-column ids like:
#   CpIOWA_EAK87386
#   cgd2_130|EAK87386.1|60S
# where the hits are the same protein but have differing identifier semantics.
# We will drop the cases where the source_id is found in a secondary_id.
# This method must be called after munging this column into source_id and
# secondary_id (see MUNG_ID()).
sub pruneDuplicates {
  my $hits = shift;
  my @prunedHits;
  my @secondary_ids = map {$_->{secondary_id}} @$hits;    
  for my $h (@$hits) {
    if ( ! grep(/$h->{source_id}/, @secondary_ids)) { 
      push @prunedHits, $h;
    }
  }
  return @prunedHits;
}

# data-specific alterations of source_ids. should be delt with in some other way.
sub MUNG_IDS {
  $_[0] =~ s/^ChTU502_[IVNA]+_//                              or
    $_[0] =~ s/^CpIOWA_[IVNA]+_//                               or
      $_[0] =~ s/^CpIOWA_(EAK\d+)/\1.1/                           or
        $_[0] =~ s/^ChTU502_(EAL\d+)/\1.1/                          or
          $_[0] =~ s/^(?:CpIOWA_)?(CAD\d{5})/\1.1/                    or
            $_[0] =~ s/^CpT2IOWA_(\d{2}-\d-\d+-\d+)/AAEE010000$1/       or
              $_[0] =~ s/^CpEST_//                                        or
                $_[0] =~ s/^CpGSS_//                                        or
                  $_[0] =~ s/^CpIOWA_//                                       or
                    $_[0] =~ s/^ChTU502_//                                       ;
    
  # cgd5_3040|EAK88225.1|40S
  # to
  # EAK88225.1
  $_[0] =~ s/^[^\|]+\|([^\|\s]+)\s*\|.*/\1/;

}

# do what ever sequence clean up is needed. such as trimming
# protease cleavage contexts that are not part of the MS peptide:
# FK.SSFNYFNEQK.SY becomes SSFNYFNEQK
sub adjustSequence {
  my ($sequence) = @_;
  $sequence =~ s/^[^\.]+\.//;
  $sequence =~ s/\.[^\.]+$//;
  return $sequence;
}

# move Spreadsheet::BasicRead's cursor past the experiment metadata
# and column headers to the first row of data.
sub skipHeader {
  my $spreadSheet = shift;
  my $endOfHeader;
  do {
    my $row = $spreadSheet->getNextRow;
    if ( ! grep /\w/, @$row ) {
      $spreadSheet->getNextRow;
      $spreadSheet->getNextRow;
      $spreadSheet->{skipBlankRows} = 1;
      $endOfHeader++;
    }
  } while ( ! $endOfHeader );
}


sub usage {
  chomp (my $thisScript = `basename $0`);
  print <<"EOF";
usage: 
$thisScript --infile excelFilename --outfile outputFilename

Parses one Excel spreadsheet from Jonathan Wastling's Sequest analysis.

Output is a format that can be load into GUS with ApiCommonData::Load::Plugin::InsertMascotSummaries
EOF
}



__DATA__

## Input Format ##

DTASelect v2.0.5	
  /data/5/jhprieto/Crypto/Crypto_insol_rep1/parc	
  /scratch/yates/Other_Cryptosporidium_parvum_na_08-31-2006_con_reversed.fasta	
  SEQUEST 3.0 in SQT format.	
  -y 2 -p 1 --fp 0.1 --hidedecoy --DB	
TRUE	Use criteria
0	Minimum peptide confidence
0.1	Peptide false positive rate
0	Minimum protein confidence
1	Protein false positive rate
1	Minimum charge state
9	Maximum charge state
0	Minimum ion proportion
1000	Maximum Sp rank
-1	Minimum Sp score
Include	Modified peptide inclusion
Full	Tryptic status requirement				
TRUE	Multiple, ambiguous IDs allowed				
Ignore	Peptide validation handling				
XCorr	Purge duplicate peptides by protein				
FALSE	Include only loci with unique peptide				
TRUE	Remove subset proteins				
Ignore	Locus validation handling				
0	Minimum modified peptides per locus				
1000	Minimum redundancy for low coverage loci				
1	Minimum peptides per locus				

Locus	Spectrum Count	MolWt	pI	Descriptive Name	
Unique	XCorr	M+H+	CalcM+H+	SpR	Sequence
CpIOWA_EAK87386	32	11511	4.5	no description	
cgd2_130|EAK87386.1|60S	32	11511	4.5	acidic ribosomal protein LP2 	
  CpIOWA_II_AAEE01000013-4-41131-40790	32	11725	4.5	no description	
  4.0539	2613.3123	2610.9795	1	K.VLESVGIEYDQSIIDVLISNMSGK.L	
  2.4738	1240.67	1241.43	1	K.LSHEVIASGLSK.L	
  3.3111	1241.3522	1241.43	1	K.LSHEVIASGLSK.L	
  6.4693	2682.7444	2683.8918	1	K.LQSVPTGGVAVSGGAAAASGGAAQDSAPAEK.K	
  5.3135	2683.9922	2683.8918	1	K.LQSVPTGGVAVSGGAAAASGGAAQDSAPAEK.K	
  4.2874	2130.5322	2131.211	1	K.KKEEEEEEEGDLGFSLFD.-	
  4.6138	2002.4122	2003.0369	1	K.KEEEEEEEGDLGFSLFD.-	
  2.5967	1876.5122	1874.8628	1	K.EEEEEEEGDLGFSLFD.-	
  ChTU502_EAL36423	121	33866	6.2	no description		
  cgd7_480|EAK90671.1|lactate	121	35876	6.5	dehydrogenase, adjacent gene encodes predicted malate dehydrogenase, transcript identified by EST 		
  CpIOWA_VII_AAEE01000001-6-118833-117823	121	35876	6.5	no description		
  CpIOWA_EAK90671	121	35876	6.5	no description		
  ChTU502_VII_AAEL01000175-1-8251-9267	121	36179	6.6	no description		
  4.7443	1833.5521	1831.1655	1	K.IAVIGSGQIGGNIAYIVGK.D	
  5.458	2017.3722	2015.2708	1	K.DNLADVVLFDIAEGIPQGK.A	
  4.2094	1725.7522	1726.0156	1	K.ALDITHSMVMFGSTSK.V	
  2.6058	1727.35	1726.0156	1	K.ALDITHSMVMFGSTSK.V	
  2.289	2761.4922	2760.1167	1	K.VIGTNDYADISGSDVVIITASIPGRPK.D	
  4.6171	2753.9343	2755.136	1	K.YCPNAFVICITNPLDVMVSHFQK.V	
  4.2591	2755.172	2755.136	1	K.YCPNAFVICITNPLDVMVSHFQK.V	
  6.4816	4443.7744	4445.0063	1	R.TFIAQHFGVNASDVSANVIGGHGDGMVPVTSSVSVGGVPLSSFIK.Q	
  3.8864	2040.4321	2041.2347	1	K.QGLITQEQIDEIVCHTR.T	
  3.3883	2041.5844	2041.2347	1	K.QGLITQEQIDEIVCHTR.T	
  2.9942	1796.5122	1796.9526	2	K.AVVPCSAFCSNHYGVK.G	
  2.1185	1248.71	1249.5542	1	K.GIYMGVPTIIGK.N	
  2.8885	1249.9722	1249.5542	3	K.GIYMGVPTIIGK.N	
  3.6222	1927.3922	1927.1589	1	K.NGVEDILELDLTPLEQK.L	
  4.0022	1517.4122	1517.7196	1	K.LLGESINEVNTISK.V	
  2.8483	1518.81	1517.7196	1	K.LLGESINEVNTISK.V	
	
	
  ## Output Format ##
