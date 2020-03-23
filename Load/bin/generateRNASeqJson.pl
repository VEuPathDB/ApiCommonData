#/usr/bin/perl

use strict;

use CBIL::Util::PropertySet;
use Getopt::Long;
use DBI;

my %hash;
my %manual;

my $gusConfigFile;
$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, [], 1);

my $u   = $gusconfig->{props}->{databaseLogin};
my $pw  = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;

while(<DATA>) {
  chomp;
  my($p, $o, $d) = split/\|/,$_;
  $manual{"$o$d"} = 1;
  #print "$p, $o, $d\n";
}

my $sql =<<EOL;
SELECT distinct r.name, y.property, y.value 
FROM apidbtuning.DATASETPRESENTER r, apidbtuning.DATASETPROPERTY y
WHERE r.DATASET_PRESENTER_ID = y.DATASET_PRESENTER_ID
 AND lower(r.name) like '%rnaseq%'
 AND (y.property='buildNumberIntroduced' or 
      y.property='hasPairedEnds' or 
      y.property='isStrandSpecific' or 
      y.property='projectName' or
      y.property='version')
order by r.name, y.property
EOL

my $sth = $dbh->prepare($sql);
$sth->execute();

while(my $row = $sth->fetchrow_arrayref) {
  my($name, $p, $v) = @$row;
  my($organism, $dataset) = $name =~ /([^_]+)_(.*)_rnaSeq_RSRC/;
  #print "$organism, $dataset, $p, $v\n";
  #push @{$hash{$name}}, {$p => $v};
  $hash{$organism}{$dataset}{$p} = $v;
}

&getJSONFromDataset(%hash);
&getJSONFromManual(%hash);

sub getJSONFromDataset {
  my (%hash) = @_;


while(my($k, $v) = each %hash) {

  my $organism = $k;

print <<EOL;
{
  "species": "$organism",
   "datasets": [
EOL
  
  while(my ($dataset, $v2) = each %$v) {

    next if (exists $manual{"$organism$dataset"});

print <<EOL;
      {
         "name" : "$dataset",
         "runs" : [
EOL
  
    my $path = '/eupath/data/EuPathDB/manualDelivery';
    my $project = $v2->{projectName};
    my $version = $v2->{version};
    my $paired  = $v2->{hasPairedEnds};
    my $strand  = $v2->{isStrandSpecific};

    $path .= "/$project/$organism/rnaSeq/$dataset/$version/final/analysisConfig.xml";
    open F, $path;
    while(<F>) {
      chomp;
      if(/<value>(.*)\|(.*)<\/value>/) {
        my $sample = $1;
        my $sra    = $2;
print <<EOL;
            {
               "accession" : "$sra",
               "isStrandSpecific" : true,
               "hasPairedEnds" : true
            }
EOL

      } 

    } # end of samples 
    close F;

print <<EOL
         ]
      }
EOL

  } # end of datasets

print <<EOL;
   ]
}
EOL

}

} # end sub getJSONFromDataset

# EuPathDB did not load SRA dynamically in early release, their SRA accessions 
# have been meanully collected and will be reloaded using SRA 
sub getJSONFromManual {
  my (%hash) = @_;


while(my($k, $v) = each %hash) {

  my $organism = $k;

print <<EOL;
{
  "species": "$organism",
   "datasets": [
EOL
  
  while(my ($dataset, $v2) = each %$v) {

    next if (not exists $manual{"$organism$dataset"});

print <<EOL;
      {
         "name" : "$dataset",
         "runs" : [
EOL
  
    my $path = '/eupath/data/EuPathDB/manualDelivery';
    my $project = $v2->{projectName};
    my $version = $v2->{version};
    my $paired  = $v2->{hasPairedEnds};
    my $strand  = $v2->{isStrandSpecific};

    $path .= "/$project/$organism/rnaSeq/$dataset/$version/workSpace/sampleList.txt";
    print "## does not exist $path\n" and die unless (-e $path);
    open F, $path;
    while(<F>) {
      chomp;
      my($sample, $sra) = split /\|/, $_;
print <<EOL;
            {
               "accession" : "$sra",
               "isStrandSpecific" : true,
               "hasPairedEnds" : true
            }
EOL

    } # end of samples 
    close F;

print <<EOL
         ]
      }
EOL

  } # end of datasets

print <<EOL;
   ]
}
EOL

}

} # end sub getJSONFromDataset 

# legacy data manaully prepared - 
# https://docs.google.com/spreadsheets/d/1ymvtGhzjhJr6VIHxBoXozjdQ8U1DQi3_ocnx1P7ZNIA/edit?pli=1#gid=0
__DATA__
FungiDB|afumAf293|Lind_SecondaryMetabolism_Afum
FungiDB|afumAf293|Losada_normoxia_hypoxia
FungiDB|anidFGSCA4|Glass_CellulaseSecretion
FungiDB|anidFGSCA4|Lind_SecondaryMetabolism_Anid
FungiDB|anigCBS513-88|David_ConidialDormancy
FungiDB|calbSC5314|Desai_GlycerolRole
FungiDB|calbSC5314|Hnisz_TranscriptionKinetics
FungiDB|calbSC5314|Lemoine_DrugResistance
FungiDB|calbSC5314|Snyder_ComprehensiveAnnotation
FungiDB|cimmRS|Taylor_SaprobicParasitic
FungiDB|cneoH99|Haynes_CapsuleRegulation
FungiDB|cneoH99|Kim_AzoleDrugs
FungiDB|cneoH99|OMeara_ExpressionInDMEM
FungiDB|cposC735deltSOWgp|Taylor_SaprobicParasitic
FungiDB|haraEmoy2|McDowell_Adaptation
FungiDB|ncraOR74A|Ellison_PopulationGenomics
FungiDB|ncraOR74A|Glass_CellulaseSecretion
FungiDB|ncraOR74A|Glass_EssentialTranscription
FungiDB|ncraOR74A|Glass_LignocelluloseDegrading
FungiDB|ncraOR74A|Wang_fiveCropStraws
FungiDB|spom972h|Barraud_DicerProtein
FungiDB|spom972h|Pleiss_AlternativeSplicing
FungiDB|spom972h|Vjestica_GeneExprProfile
PlasmoDB|pberANKA|Female_Male_Gametocyte
PlasmoDB|pberANKA|Janse_Hoeijmakers_five_stages
PlasmoDB|pchachabaudi|Mosquito_And_Blood_Transmitted
PlasmoDB|pfal3D7|Bunnik_Asexual_Cell_Cycle
PlasmoDB|pfal3D7|Caro_ribosome_profiling
PlasmoDB|pfal3D7|Cultured_Sporozoites_Transcriptome
PlasmoDB|pfal3D7|Lasonder_Bartfai_Gametocytes
PlasmoDB|pfal3D7|Newbold
PlasmoDB|pfal3D7|Stunnenberg
PlasmoDB|pvivP01|intraerythrocyticTimeSeries
PlasmoDB|pvivSal1|intraerythrocyticTimeSeries
PlasmoDB|pyoeyoelii17X|Kappe
TriTrypDB|ldonBPK282A1|Zhang_Visceral_vs_Cutaneous_Leishmaniasis
TriTrypDB|lmexMHOMGT2001U1103|macrophage_mouse
TriTrypDB|tbruTREU927|AdiposeTissueAndBloodStream
TriTrypDB|tbruTREU927|Gowthaman_mRNA
TriTrypDB|tbruTREU927|Tschudi_Transcriptome
ToxoDB|etenHoughton|Reid_RNASeq
ToxoDB|etenHoughton|Walker_gametocytes
ToxoDB|ncanLIV|Reid_tachy
ToxoDB|tgonME49|Hassan_intra_extra_ribo_profiling
ToxoDB|tgonME49|Knoll_Laura_Pittman
ToxoDB|tgonME49|RamakrishnanTachyzoiteAndMerozoite
ToxoDB|tgonME49|Reid_tachy
ToxoDB|tgonME49|TgSR3_Overexpression_Time_Series
ToxoDB|tgonME49|White_paper_GT1
ToxoDB|tgonME49|White_paper_ME49
AmoebaDB|ehisHM1IMSS|Guillen
AmoebaDB|einvIP1|Singh_Encyst_Excyst
AmoebaDB|nfowATCC30863|Pathogenic_Trophozoite_Trascriptome
CryptoDB|cparIowaII|Tandel_Lifecycle_development
GiardiaDB|gassAWB|Ansell_AxenicTrophozoites
GiardiaDB|gassAWB|Tolba_RNAseq
GiardiaDB|gassAWB|Tolba_TSSseq
GiardiaDB|ssalATCC50377|Feifei_trophozoites
MicrosporidiaDB|nparERTm1|Troemel_Time_Course
HostDB|mmusC57BL6J|macrophage_Lmexicana
