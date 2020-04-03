#!/usr/bin/perl

use strict;
use CBIL::Util::PropertySet;
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
  my($p, $o, $d, $status) = split/\|/,$_;
  $manual{$o}{$d} = $status;
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
  #push @{$hash{$organism}{$dataset}{props}}, {$p => $v};
  $hash{$organism}{$dataset}{props}{$p} = $v;
  $hash{$organism}{$dataset}{toEBI} = 0; # flag to indicate if send to ebi
}

# get data from existing datasets with SRA accessions
while(my($organism, $v) = each %hash) {

  while(my ($dataset, $v2) = each %$v) {

    next if (exists $manual{$organism}{$dataset}); # skip if legacy

    $hash{$organism}{$dataset}{toEBI} = 1; 
    my $project = $v2->{props}->{projectName};
    my $version = $v2->{props}->{version};
    my $paired  = $v2->{props}->{hasPairedEnds};
    my $strand  = $v2->{props}->{isStrandSpecific};
    my $path = "/eupath/data/EuPathDB/manualDelivery/$project/$organism/rnaSeq/$dataset/$version/final/analysisConfig.xml";

    open F, $path;
    while(<F>) {
      chomp;
      if(/<value>(.*)\|(.*)<\/value>/) {
        my $sample = $1;
        my $sra    = $2;
        $sra =~ s/\s//g;
        push @{$hash{$organism}{$dataset}{samples}}, $sra;
        #$hash{$organism}{$dataset}{samples}{$sra} = $sample;
      } 
    } 
    close F;
  } # end of datasets
}

# legacy data
while(my($organism, $v) = each %hash) {

  while(my ($dataset, $v2) = each %$v) {

    next if ((not exists $manual{$organism}{$dataset}) || ($manual{$organism}{$dataset} !~ /done/i));

    $hash{$organism}{$dataset}{toEBI} = 1; 
    my $project = $v2->{props}->{projectName};
    my $version = $v2->{props}->{version};
    my $paired  = $v2->{props}->{hasPairedEnds};
    my $strand  = $v2->{props}->{isStrandSpecific};

    my $path = "/eupath/data/EuPathDB/manualDelivery/$project/$organism/rnaSeq/$dataset/$version/workSpace/sampleList.txt";
    print "$path does not exist\n" and die unless (-e $path);
    open F, $path;
    while(<F>) {
      chomp;
      my($sample, $sra) = split /\|/, $_;
      $sra =~ s/\s//g;
      push @{$hash{$organism}{$dataset}{samples}}, $sra;
      #$hash{$organism}{$dataset}{samples}{$sra} = $sample;

    } # end of samples 
    close F;
  } 
}

# print out in json format
my $org_count = 0;
my $org_size  = keys %hash;
my $org_comma = ',';

print "[\n";
while(my($organism, $v) = each %hash) {
  $org_count++;
  $org_comma = '' if ($org_size == $org_count);

  # organism has no rnaseq with sra accessions, e.g crypto vbraCCMP3155
  # $hash{$organism}{$dataset}{toEBI} = 1; 

print <<EOL;
{
  "species": "$organism",
   "datasets": [
EOL

  my $ds_count  = 0;
  my $ds_size   = 0;
  my $ds_comma  = ',';

  while(my ($dataset, $h) = each %$v) {
    if( $h->{toEBI} ) {
      $ds_size++;
    }
  }

  while(my ($dataset, $h) = each %$v) {
    if( $h->{toEBI} ) {
      $ds_count++;
      $ds_comma = '' if ($ds_count == $ds_size);
      my $paired  = $h->{props}->{hasPairedEnds};
      my $strand  = $h->{props}->{isStrandSpecific};

print <<EOL;
      {
         "name" : "$dataset",
         "runs" : [
EOL

     my @samples = @{$h->{samples}};
     my $s_size = @samples;
     my $s_count = 0;
     my $s_comma = ',';
     foreach my $sra (@samples) { 
       $s_count++; 
       $s_comma = '' if ($s_count == $s_size);
        
print <<EOL;
            {
               "accession" : "$sra",
               "isStrandSpecific" : $strand,
               "hasPairedEnds" : $paired
            }$s_comma
EOL
     } # end foreach

print <<EOL
         ]
      }$ds_comma
EOL

    } # end if
  } # end while datasets

print <<EOL;
   ]
}$org_comma
EOL
}

print "]\n";

# legacy rnaSeq data with manaully updated SRA accessions - 
# https://docs.google.com/spreadsheets/d/1ymvtGhzjhJr6VIHxBoXozjdQ8U1DQi3_ocnx1P7ZNIA/edit?pli=1#gid=0
__DATA__
FungiDB|afumAf293|Lind_SecondaryMetabolism_Afum|DONE
FungiDB|afumAf293|Losada_normoxia_hypoxia|DONE
FungiDB|anidFGSCA4|Glass_CellulaseSecretion|DONE
FungiDB|anidFGSCA4|Lind_SecondaryMetabolism_Anid|DONE
FungiDB|anigCBS513-88|David_ConidialDormancy|DONE
FungiDB|calbSC5314|Desai_GlycerolRole|DONE
FungiDB|calbSC5314|Hnisz_TranscriptionKinetics|DONE
FungiDB|calbSC5314|Lemoine_DrugResistance|DONE
FungiDB|calbSC5314|Snyder_ComprehensiveAnnotation|DONE
FungiDB|ccinokay7-130|Stajich_HyphalGrowth|N/A
FungiDB|cimmRS|Taylor_SaprobicParasitic|DONE
FungiDB|cneoH99|Haynes_CapsuleRegulation|DONE
FungiDB|cneoH99|Kim_AzoleDrugs|DONE
FungiDB|cneoH99|OMeara_ExpressionInDMEM|DONE
FungiDB|cneoH99|OMeara_Nrg1Expression|N/A
FungiDB|cposC735deltSOWgp|Taylor_SaprobicParasitic|DONE
FungiDB|haraEmoy2|McDowell_Adaptation|DONE
FungiDB|ncraOR74A|Ellison_PopulationGenomics|DONE
FungiDB|ncraOR74A|Glass_CellulaseSecretion|DONE
FungiDB|ncraOR74A|Glass_EssentialTranscription|DONE
FungiDB|ncraOR74A|Glass_LignocelluloseDegrading|DONE
FungiDB|ncraOR74A|Stajich_HyphalGrowth|N/A
FungiDB|ncraOR74A|Wang_fiveCropStraws|DONE
FungiDB|pcapLT1534|Xu_Infection|not loaded
FungiDB|pramPr-102|Kasuga_SporulationsMedia|N/A
FungiDB|psojP6497|Tyler_Infection|N/A
FungiDB|rdelRA99-880|Stajich_HyphalGrowth|N/A
FungiDB|spom972h|Barraud_DicerProtein|DONE
FungiDB|spom972h|Pleiss_AlternativeSplicing|DONE
FungiDB|spom972h|Vjestica_GeneExprProfile|DONE
PlasmoDB|pberANKA|Female_Male_Gametocyte|DONE
PlasmoDB|pberANKA|Janse_Hoeijmakers_five_stages|DONE
PlasmoDB|pchachabaudi|Mosquito_And_Blood_Transmitted|DONE
PlasmoDB|pfal3D7|Bartfai_time_series   |N/A
PlasmoDB|pfal3D7|Bunnik_Asexual_Cell_Cycle|DONE
PlasmoDB|pfal3D7|Caro_ribosome_profiling|DONE
PlasmoDB|pfal3D7|Cultured_Sporozoites_Transcriptome|DONE
PlasmoDB|pfal3D7|Duffy|N/A
PlasmoDB|pfal3D7|Lasonder_Bartfai_Gametocytes|DONE
PlasmoDB|pfal3D7|Newbold|DONE 
PlasmoDB|pfal3D7|Otto|N/A
PlasmoDB|pfal3D7|Stunnenberg|DONE
PlasmoDB|pfal3D7|Su_seven_stages|N/A
PlasmoDB|pfal3D7|Su_strand_specific|N/A
PlasmoDB|pvivP01|intraerythrocyticTimeSeries|DONE
PlasmoDB|pvivP01|Muller_salivary_gland|manually merged paired end
PlasmoDB|pvivSal1|intraerythrocyticTimeSeries|DONE
PlasmoDB|pyoeyoelii17X|Kappe|DONE
TriTrypDB|ldonBPK282A1|Zhang_Visceral_vs_Cutaneous_Leishmaniasis|DONE
TriTrypDB|linfJPCM5|Mottram_Jeremy|N/A
TriTrypDB|lmexMHOMGT2001U1103|macrophage_mouse|DONE
TriTrypDB|lpyrH10|Flegontov_Transcriptome|N/A
TriTrypDB|lseyATCC30220|Flegontov_PolyA_Transcriptome|N/A
TriTrypDB|tbruTREU927|AdiposeTissueAndBloodStream|DONE
TriTrypDB|tbruTREU927|Archer_Stuart_CellCycle|N/A
TriTrypDB|tbruTREU927|Clayton_mRNADegradation|N/A
TriTrypDB|tbruTREU927|Clayton_mRNADegradation_halfLife|N/A
TriTrypDB|tbruTREU927|Dickens_ORC1_RNAi_Knockdown|N/A
TriTrypDB|tbruTREU927|George_Cross|N/A
TriTrypDB|tbruTREU927|Gowthaman_mRNA|DONE (GSM)
TriTrypDB|tbruTREU927|H1_RNAi_Depleted|not loaded
TriTrypDB|tbruTREU927|RNAi_Horn|N/A
TriTrypDB|tbruTREU927|RNAi_Horn_CDS|N/A
TriTrypDB|tbruTREU927|Tschudi_Transcriptome|DONE
ToxoDB|etenHoughton|Reid_RNASeq|DONE
ToxoDB|etenHoughton|Walker_gametocytes|DONE
ToxoDB|ncanLIV|Gregory_Brian_mRNA|N/A
ToxoDB|ncanLIV|Gregory_Brian_ncRNA|N/A
ToxoDB|ncanLIV|Reid_tachy|DONE
ToxoDB|tgonGT1|Gregory_Brian|N/A
ToxoDB|tgonME49|Boothroyd_oocyst|N/A
ToxoDB|tgonME49|Buchholz_Boothroyd_M4_in_vivo_bradyzoite|N/A
ToxoDB|tgonME49|DBP_Hehl-Grigg|N/A
ToxoDB|tgonME49|Gregory_Brian|N/A
ToxoDB|tgonME49|Gregory_GT1_mRNA|N/A
ToxoDB|tgonME49|Gregory_ME49_mRNA|N/A
ToxoDB|tgonME49|Gregory_RH_mRNA|N/A
ToxoDB|tgonME49|Gregory_VEG_mRNA|N/A
ToxoDB|tgonME49|Hassan_intra_extra_ribo_profiling|DONE
ToxoDB|tgonME49|Knoll_Laura_Pittman|DONE
ToxoDB|tgonME49|ME49_bradyzoite|N/A
ToxoDB|tgonME49|RamakrishnanTachyzoiteAndMerozoite|N/A
ToxoDB|tgonME49|Reid_tachy|DONE
ToxoDB|tgonME49|Saeij_Jeroen_25_strains|N/A
ToxoDB|tgonME49|Saeij_Jeroen_strains|N/A
ToxoDB|tgonME49|TgSR3_Overexpression_Time_Series|DONE
ToxoDB|tgonME49|White_paper_GT1|DONE
ToxoDB|tgonME49|White_paper_ME49|DONE
ToxoDB|tgonVEG|Reid_tachy|N/A
AmoebaDB|ehisHM1IMSS|Guillen|DONE
AmoebaDB|einvIP1|Singh_Encyst_Excyst|DONE
AmoebaDB|nfowATCC30863|Pathogenic_Trophozoite_Trascriptome|DONE
CryptoDB|cparIowaII|Lippuner|N/A
CryptoDB|cparIowaII|Tandel_Lifecycle_development|DONE
CryptoDB|cvelCCMP2878|Otto|N/A
CryptoDB|vbraCCMP3155|Otto|N/A
GiardiaDB|gassAWB|Ansell_AxenicTrophozoites|DONE
GiardiaDB|gassAWB|Svard|N/A
GiardiaDB|gassAWB|Tolba_RNAseq|DONE
GiardiaDB|gassAWB|Tolba_TSSseq|DONE
GiardiaDB|gassBGS|Svard|N/A
GiardiaDB|gassEP15|Svard|N/A
GiardiaDB|ssalATCC50377|Feifei_trophozoites|DONE
MicrosporidiaDB|nparERTm1|Troemel_Time_Course|DONE
MicrosporidiaDB|slop42_110|Campbell_Transcriptome|N/A
HostDB|hsapREF|Gregory_ME49_mRNA|N/A
HostDB|mmusC57BL6J|macrophage_Lmexicana|DONE
HostDB|mmusC57BL6J|Saeij_Jeroen_strains|N/A
