package ApiCommonData::Load::SnpChipVariationFileMaker;

use strict;
use DBI;
use Getopt::Long;

use ApiCommonData::Load::SnpUtils  qw(variationFileColumnNames);

use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::PropertySet;
use File::Basename;

my $columnNames = &variationFileColumnNames();

my ($gusConfigFile,$outputFile,$tmpDir);

&GetOptions("gusConfigFile=s" => \$gusConfigFile,
                      "outputFileName=s" => \$outputFile,
                      "workingDir=s" => \$tmpDir,
            );

$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless (-e $gusConfigFile) {
  print STDERR "gus.config file not found! \n";
  &usage;
}

unless (defined $outputFile) {
  print STDERR "outputFileName must be provided \n";
  &usage;
}

unless (-d $tmpDir) {
  print STDERR "workingDir $tmpDir does not exist! \n";
  &usage;
}


my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $dbh = DBI->connect($gusconfig->{props}->{dbiDsn},
		       $gusconfig->{props}->{databaseLogin},
		       $gusconfig->{props}->{databasePassword})
  ||  die "Couldn't connect to database: " . DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;
my $variationsText = [];
my $header = (join (/\t/,$columnNames));
my $getVariations = $dbh->prepare(<<SQL) or die "preparing variants query";
 select distinct
 seq.source_id as sequence_source_id,
       nal.START_MIN as location,
        var.strain || '_' || snp.name as strain,
        var.allele as base,
        100 as coverage,
        100 as allele_percent,
        '' as quality,
        0.0005 as pvalue,
        '' as external_database_release_id,
        var.matches_reference,
        var.product,
        snp.position_in_cds,
        snp.position_in_protein,
        var.na_sequence_id,
        var.na_sequence_id as ref_na_sequence_id,
        snp.external_database_release_id as snp_ext_db_rls_id
        from dots.seqvariation var, dots.SnpFeature snp, dots.NaSequence seq,
             DOTS.NALOCATION nal, SRES.EXTERNALDATABASE ed, SRES.EXTERNALDATABASERELEASE edr              
       where var.EXTERNAL_DATABASE_RELEASE_ID =edr.EXTERNAL_DATABASE_RELEASE_ID
         and edr.EXTERNAL_DATABASE_ID = ed.EXTERNAL_DATABASE_ID
         and lower(ed.name) like '%snpchip%'
         and var.parent_id = snp.na_feature_id
         and snp.na_feature_id = nal.na_feature_id
         and snp.na_sequence_id = seq.na_sequence_id
  union
select source_id as sequence_source_id,
        location,
        strain,
        base,
        coverage,
        allele_percent,
        quality,
        pvalue,
        external_database_release_id,
        matches_reference,
        product,
        cast(replace(min(nvl(position_in_cds,999999999999)),999999999999,NULL) as number(12)) as position_in_cds,
        cast(replace(min(nvl(position_in_protein,999999999999)),999999999999,NULL) as number(12)) as position_in_protein,    
        na_sequence_id,
        ref_na_sequence_id,
        snp_ext_db_rls_id
        from (
          select distinct
          seq.source_id as source_id,
          nal.START_MIN as location,
          snp.REFERENCE_STRAIN || '_ref'  as strain,
          dbms_lob.substr(seq.sequence,1,nal.start_min) as base,
          100 as coverage,
          100 as allele_percent,
          '' as quality,
          0.0005 as pvalue,
          '' as external_database_release_id,
          1 as matches_reference,
          '' as product,
          snp.position_in_cds,
          snp.position_in_protein,
          snp.na_sequence_id,
          snp.na_sequence_id as ref_na_sequence_id,
          (select distinct edr.external_database_release_id
              from sres.externaldatabase ed, sres.externaldatabaserelease edr 
            where ed.external_database_id =edr.external_database_id
                and ed.name = 'pfal3D7_primary_genome_RSRC') as snp_ext_db_rls_id
         from dots.SnpFeature snp, dots.NaSequence seq, 
                DOTS.NALOCATION nal,
                (select distinct
                     seq.source_id as source_id,
                     nal.START_MIN as location
                    from dots.SnpFeature snp, dots.NaSequence seq, 
                             DOTS.NALOCATION nal
                  where snp.name like 'Broad_%'
                      and snp.na_feature_id = nal.na_feature_id
                     and snp.na_sequence_id = seq.na_sequence_id) locations

      where snp.na_feature_id = nal.na_feature_id
      and snp.na_sequence_id = seq.na_sequence_id
      and locations.source_id =seq.source_id
      and locations.location = nal.start_min)
      group by source_id,
        location,
        strain,
        base,
        coverage,
        allele_percent,
        quality,
        pvalue,
        external_database_release_id,
        matches_reference,
        product, 
        na_sequence_id,
        ref_na_sequence_id,
        snp_ext_db_rls_id
SQL

$getVariations->execute()
  || die "executing variations query: " . DBI->errstr;
while (my @row  = $getVariations->fetchrow_array()) {
  push (@$variationsText,@row);
}



$getVariations->execute();

open(OUT, "|sort -T $tmpDir -k 1,1 -k 2,2n > $outputFile") or die "Cannot open file $outputFile for writing: $!";
$getVariations->execute()
  || die "executing variations query: " . DBI->errstr;
while (my @row  = $getVariations->fetchrow_array()) {
  print OUT join ("\t", @row)."\n";
}
close OUT;

my $getStrains = $dbh->prepare(<<SQL) or die "preparing variants query";
 select distinct
        var.strain || '_' || snp.name as strain
        from dots.seqvariation var, dots.snpfeature snp, SRES.EXTERNALDATABASE ed, SRES.EXTERNALDATABASERELEASE edr              
    where var.EXTERNAL_DATABASE_RELEASE_ID =edr.EXTERNAL_DATABASE_RELEASE_ID
      and edr.EXTERNAL_DATABASE_ID = ed.EXTERNAL_DATABASE_ID
      and var.parent_id = snp.na_feature_id
      and lower(ed.name) like '%snpchip%'
SQL

$getStrains->execute();
my ($junk, $outputFileDir) = fileparse($outputFile);
my $strainFile =  $outputFileDir."/snpChipStrains.dat";
open(STRAINS, "|sort -T $tmpDir -k 1,1 -k 2,2n > $strainFile") or die "Cannot open file $strainFile for writing: $!";
$getStrains->execute()
  || die "executing variations query: " . DBI->errstr;
while (my @row  = $getStrains->fetchrow_array()) {
  print STRAINS join ("\t", @row)."\n";
}
close STRAINS;

$dbh->disconnect;

sub usage {
  die "
Create create variations file and strains file consumed by the hsssCreateStrainFiles script for chip based snps.

Usage: SnpChipVariationFileMaker --outputFileName {file_location} --workingDir {directory_location} [--gusConfigFile {file_location}]

Where:
  outputFileName:   Name to use for for variations file that will be created. Strains file will be written to the same directory. 
  
  workinDir:     Directory to use for temporary files created by this script.

  gusConfigFile:     location of the file containing information on how to connect to GUS databases. Default = \$GUS_HOME/config/gus.config


Details:
Create create input variations file and strains file consumed by the hsssCreateStrainFiles script for chip based snps.

This program also two files:
  - variations file: a tab file that contains the strain, location, and referene information for each each based snp in DoTS.SeqVariation 
  - strains file: a file that contains a single column list of the unique concatenations of strain name and isolate assay type 
    found in sequence variations
";
}
