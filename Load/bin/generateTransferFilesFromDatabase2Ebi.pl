#!/usr/bin/perl

use strict;
use JSON;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;
#use ApiCommonData::Load::AnnotationUtils;

## TODO, better to ignore null record

my ($genomeSummaryFile, $gusConfigFile, $outputFileDir, $organismListFile, $help);

&GetOptions(
            'genomeSummaryFile=s' => \$genomeSummaryFile,
            'outputFileDir=s' => \$outputFileDir,
            'gusConfigFile=s' => \$gusConfigFile,
            'organismListFile=s' => \$organismListFile,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $genomeSummaryFile && $outputFileDir);

$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);
my $verbose;
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName()
                                       );
my $dbh = $db->getQueryHandle();

my (%isAnnotated);

if ($organismListFile) {    ## extract organisms that listed in the organismListFile

  open (IN, "$organismListFile") || die "can not open $organismListFile file to read\n";
  while (<IN>) {
    chomp;
    my @items = split (/\t/, $_);
    $isAnnotated{$items[0]} = $items[1];
  }
  close IN;

} else {    ## extract from whole set of organisms from the database

  my $sql = "select abbrev, is_annotated_genome from apidb.organism";
  my $stmt = $dbh->prepareAndExecute($sql);

  while (my ($abbrev, $isAnnot) = $stmt->fetchrow_array()) {
    $isAnnotated{$abbrev} = $isAnnot;
  }

  $stmt->finish();
}

unless (-e $outputFileDir) {
  my $mkOutputDirCmd = "mkdir $outputFileDir";
  system ($mkOutputDirCmd);
  print STDERR "making the dir $outputFileDir\n";
}

my $c = 0;
foreach my $abbrev (sort keys %isAnnotated) {

  print STDERR "processing $abbrev ......\n";

  my $primaryExtDbRlsId = getPrimaryExtDbRlsIdFromOrganismAbbrev($abbrev);
  print STDERR "For $abbrev, \$primaryExtDbRlsId = $primaryExtDbRlsId\n";

  my $gff3FileNameBefore = $abbrev . ".gff3.before";
  my $gff3FileNameAfter = $abbrev.".gff3";

  ## 1) make genome fasta file
  my $dnaFastaFile = $outputFileDir . "\/". $abbrev . "_dna.fa";
  my $makeGenomeFastaCmd = "gusExtractSequences --outputFile $dnaFastaFile --gusConfigFile $gusConfigFile --idSQL 'select s.source_id, s.SEQUENCE from apidbtuning.genomicseqattributes sa, dots.nasequence s where s.na_sequence_id = sa.na_sequence_id and sa.is_top_level = 1 and s.EXTERNAL_DATABASE_RELEASE_ID=$primaryExtDbRlsId'";
  system($makeGenomeFastaCmd);

  ## 2) make gff3, protein, and etc. files that related with annotation
  if ($isAnnotated{$abbrev} == 1) {
    my $makeGff3Cmd = "makeGff4BRC4.pl --orgAbbrev $abbrev --outputFile $gff3FileNameBefore --gusConfigFile $gusConfigFile --outputFileDir $outputFileDir --ifSeparateParents Y";
    system($makeGff3Cmd);

    my $proteinFastaFileName = $outputFileDir . "\/" . $abbrev . "_protein.fa";
#    my $makeProteinFastaCmd = "gusExtractSequences --outputFile $proteinFastaFileName --gusConfigFile $gusConfigFile --idSQL 'select SOURCE_ID, SEQUENCE from DOTS.TRANSLATEDAASEQUENCE where AA_SEQUENCE_ID in (select AA_SEQUENCE_ID from dots.translatedaafeature where EXTERNAL_DATABASE_RELEASE_ID=$primaryExtDbRlsId)'";
    my $makeProteinFastaCmd = "gusExtractSequences --outputFile $proteinFastaFileName --gusConfigFile $gusConfigFile --idSQL 'select tas.SOURCE_ID, tas.SEQUENCE from dots.transcript t, dots.translatedaafeature taf, DOTS.translatedaasequence tas where t.NA_FEATURE_ID=taf.NA_FEATURE_ID and taf.AA_SEQUENCE_ID=tas.AA_SEQUENCE_ID and t.is_pseudo is null and t.EXTERNAL_DATABASE_RELEASE_ID=$primaryExtDbRlsId'";  ## only export protein sequence for non-pseudogene
    system($makeProteinFastaCmd);

    my $functAnnotJsonCmd = "generateFunctionalAnnotationJson.pl --organismAbbrev $abbrev --gusConfigFile $gusConfigFile --outputFileDir $outputFileDir";
    system($functAnnotJsonCmd);

    my $geneTransProteinIdsCmd = "generateGeneTransciptProteinIdMapping.pl --organismAbbrev $abbrev --gusConfigFile $gusConfigFile --outputFileDir $outputFileDir";
    system($geneTransProteinIdsCmd);

  }

  ## 3) make genome metadata json file
  my $genomeJsonCmd = "generateGenomeJson.pl --genomeSummaryFile GenomeSummary.txt --organismAbbrev $abbrev --outputFileDir $outputFileDir";
  system($genomeJsonCmd);

  ## 4) make seq region metadata json file
  my $seqRegionJsonCmd = "generateSeqRegionJson.pl --organismAbbrev $abbrev --gusConfigFile $gusConfigFile --outputFileDir $outputFileDir";
  system($seqRegionJsonCmd);

#  $c++;
#  last if ($c > 2);
}

foreach my $abbrev (sort keys %isAnnotated) {
  my $gff3FileNameBefore = $outputFileDir . "\/" . $abbrev . ".gff3.before";
  my $gff3FileNameAfter = $outputFileDir . "\/" . $abbrev.".gff3";
  my $gff3FileNameWoPseudoCDS = $outputFileDir . "\/" . $abbrev. ".modified". ".gff3";
  my $dnaFastaFile = $outputFileDir . "\/". $abbrev . "_dna.fa";

  if ($isAnnotated{$abbrev} == 1) {
    ## 5) validateGff3
    my $validationCmd = "gff3Validator.pl --inputFileOrDir $gff3FileNameBefore --fastaInputFile $dnaFastaFile --outputGffFileName $gff3FileNameAfter";
    system ($validationCmd);

    ## 6) remove unnecessary files
    my $removeFileCmd = "rm $gff3FileNameBefore";
    system ($removeFileCmd);

    ## make gff3 file without CDS for pseudogene
    my $modifyGff3BasedEbiCmd = "modifyGff3BasedEbi.pl $gff3FileNameAfter > $gff3FileNameWoPseudoCDS ";
    system ($modifyGff3BasedEbiCmd);
  }

  ## 7) make manifest file
  my $runManifestCmd;
  my $makeManifestFileCmd;

  ## 8) tar and gzip files
  my $tarFileName = $outputFileDir . "\/" . $abbrev .".tar.gz";
  my $filesToTar = $outputFileDir . "\/" . $abbrev . "*";

  my $tarFilesCmd = "tar -czf $tarFileName $filesToTar";
  system ($tarFilesCmd);

  $tarFileName =~ s/^.*\///;
  my $echoCmd = "echo \"To untar the files, \ntar -xvf $tarFileName\n\" ". "\>" . $outputFileDir . "\/" . $abbrev . "_readme.txt";
  system ($echoCmd);

}

$dbh->disconnect();

###########
sub getPrimaryExtDbRlsIdFromOrganismAbbrev{
  my ($abbrev) = @_;

  my $extDbRlsName = $abbrev . "_primary_genome_RSRC";

  my $sql = "select edr.external_database_release_id from sres.externaldatabaserelease edr, sres.externaldatabase ed
             where ed.name = '$extDbRlsName'
             and edr.external_database_id = ed.external_database_id";

  my $stmt = $dbh->prepareAndExecute($sql);

  my @rlsIdArray;
  while ( my($extDbRlsId) = $stmt->fetchrow_array()) {
      push @rlsIdArray, $extDbRlsId;
    }

  die "No extDbRlsId found for '$extDbRlsName'" unless(scalar(@rlsIdArray) > 0);

  die "trying to find unique extDbRlsId for '$extDbRlsName', but more than one found" if(scalar(@rlsIdArray) > 1);

  return @rlsIdArray[0];
}


sub usage {
  die
"
A script to generate all files to transfer genome sequence and annotation to EBI pipline

Usage: perl generateTransferFilesFromDatabase2Ebi.pl --genomeSummaryFile GenomeSummary.txt --outputFileDir PlasmoDB_output --gusConfigFile \$GUS_HOME/config/gus.config

where:
  --genomeSummaryFile: required, the txt file that include all genome info that loaded in EuPathDB
  --outputFileDir: required, the directory that hold all output file
  --organismListFile: optional, the list of organisms that want to export
  --gusConfigFile: optional, default is \$GUS_HOME/config/gus.config

";
}
