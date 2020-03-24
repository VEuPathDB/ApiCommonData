#!/usr/bin/perl

use strict;
use JSON;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;
#use ApiCommonData::Load::AnnotationUtils;

## TODO, better to ignore null record

my ($genomeSummaryFile, $gusConfigFile, $outputFileDir, $organismListFile, $annotationFile, $transpIdSuffix, $help);

&GetOptions(
            'genomeSummaryFile=s' => \$genomeSummaryFile,
            'outputFileDir=s' => \$outputFileDir,
            'gusConfigFile=s' => \$gusConfigFile,
            'organismListFile=s' => \$organismListFile,
            'annotationFile=s' => \$annotationFile,
            'transpIdSuffix=s' => \$transpIdSuffix,
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

  my $orgOutputFileDir = $outputFileDir."\/".$abbrev . "\/";

  unless (-e $orgOutputFileDir) {
    my $mkOutputDirCmd = "mkdir $orgOutputFileDir";
    system ($mkOutputDirCmd);
    print STDERR "making the dir $orgOutputFileDir\n";
  }

  my $primaryExtDbRlsId = getPrimaryExtDbRlsIdFromOrganismAbbrev($abbrev);
  print STDERR "For $abbrev, \$primaryExtDbRlsId = $primaryExtDbRlsId\n";

  my $gff3FileNameBefore = $abbrev . ".gff3.before";
  my $gff3FileNameAfter = $abbrev.".gff3";

  my $ncbiTaxonId = getNcbiTaxonId ($abbrev);

  ## 1) make genome fasta file
  my $dnaFastaFile = $orgOutputFileDir. "\/". $abbrev . "_dna.fa";
  my $makeGenomeFastaCmd = "gusExtractSequences --outputFile $dnaFastaFile --gusConfigFile $gusConfigFile --idSQL 'select s.source_id, s.SEQUENCE from apidbtuning.genomicseqattributes sa, dots.nasequence s where s.na_sequence_id = sa.na_sequence_id and sa.is_top_level = 1 and sa.NCBI_TAX_ID=$ncbiTaxonId'";
  system($makeGenomeFastaCmd);

  ## 2) make gff3, protein, and etc. files that related with annotation
  if ($isAnnotated{$abbrev} == 1) {
    my $makeGff3Cmd = "makeGff4BRC4.pl --orgAbbrev $abbrev --outputFile $gff3FileNameBefore --gusConfigFile $gusConfigFile --outputFileDir $orgOutputFileDir --ifSeparateParents Y";
    system($makeGff3Cmd);

#    if ($abbrev eq "ccayNF1_C8") {
#      my $rmGff3BeforeCmd = "rm $orgOutputFileDir" . "\/" . $gff3FileNameBefore;
#      system ($rmGff3BeforeCmd);
#      my $gff3FromAnnotation = $orgOutputFileDir . "\/" . $gff3FileNameBefore;
#      my $makeGff3CmdFromAnnot = "convertGenbank2Gff3Simply.pl --inputFile $annotationFile --outputFile $gff3FromAnnotation --transpIdSuffix $transpIdSuffix";
#      system ($makeGff3CmdFromAnnot);
#    }

    my $proteinFastaFileName = $orgOutputFileDir . "\/" . $abbrev . "_protein.fa";
#    my $makeProteinFastaCmd = "gusExtractSequences --outputFile $proteinFastaFileName --gusConfigFile $gusConfigFile --idSQL 'select SOURCE_ID, SEQUENCE from DOTS.TRANSLATEDAASEQUENCE where AA_SEQUENCE_ID in (select AA_SEQUENCE_ID from dots.translatedaafeature where EXTERNAL_DATABASE_RELEASE_ID=$primaryExtDbRlsId)'";
#    my $makeProteinFastaCmd = "gusExtractSequences --outputFile $proteinFastaFileName --gusConfigFile $gusConfigFile --idSQL 'select tas.SOURCE_ID, tas.SEQUENCE from dots.transcript t, dots.translatedaafeature taf, DOTS.translatedaasequence tas where t.NA_FEATURE_ID=taf.NA_FEATURE_ID and taf.AA_SEQUENCE_ID=tas.AA_SEQUENCE_ID and t.is_pseudo is null and t.EXTERNAL_DATABASE_RELEASE_ID=$primaryExtDbRlsId'";  ## only export protein sequence for non-pseudogene
    my $makeProteinFastaCmd = "gusExtractProteinSequence4Ebi.pl --outputFile $proteinFastaFileName --extDbRlsId $primaryExtDbRlsId --gusConfigFile $gusConfigFile";
    system($makeProteinFastaCmd);

    my $functAnnotJsonCmd = "generateFunctionalAnnotationJson.pl --organismAbbrev $abbrev --gusConfigFile $gusConfigFile --outputFileDir $orgOutputFileDir";
    system($functAnnotJsonCmd);

# do not need geneIdMapping.tab anymore
#    my $geneTransProteinIdsCmd = "generateGeneTransciptProteinIdMapping.pl --organismAbbrev $abbrev --gusConfigFile $gusConfigFile --outputFileDir $outputFileDir";
#    system($geneTransProteinIdsCmd);

  }

  ## 3) make genome metadata json file
  my $genomeJsonCmd = "generateGenomeJson.pl --genomeSummaryFile $genomeSummaryFile --organismAbbrev $abbrev --outputFileDir $orgOutputFileDir";
  system($genomeJsonCmd);

  ## 4) make seq region metadata json file
  my $seqRegionJsonCmd = "generateSeqRegionJson.pl --organismAbbrev $abbrev --ncbiTaxId $ncbiTaxonId --gusConfigFile $gusConfigFile --outputFileDir $orgOutputFileDir";
  system($seqRegionJsonCmd);

  $db->undefPointerCache();
#  $c++;
#  last if ($c > 2);
}

foreach my $abbrev (sort keys %isAnnotated) {

  my $orgOutputFileDir = $outputFileDir . "\/" . $abbrev ."\/";

  my $gff3FileNameBefore = $orgOutputFileDir. "\/" . $abbrev . ".gff3.before";
  my $gff3FileNameAfter = $orgOutputFileDir. "\/" . $abbrev.".gff3";
  my $gff3FileNameWoPseudoCDS = $orgOutputFileDir. "\/" . $abbrev. ".modified". ".gff3";
  my $dnaFastaFile = $orgOutputFileDir. "\/". $abbrev . "_dna.fa";

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
  my $runMd5sumCmd = "md5sum $orgOutputFileDir/* > md5sumList";
  system ($runMd5sumCmd);

  my %md5sumValues;
  open (MDIN, "md5sumList") || die "can not open md5sumList of $abbrev file to read\n";
  while (<MDIN>) {
    chomp;
    my @items = split (/\s+/, $_);
    if ($items[0] && length($items[0]) == 32) {
      $items[1] =~ s/.*\///;
      my %md5sumValue = (
			  'md5sum' => $items[0],
			  'file' => $items[1]
			  );

      if ($items[1] =~ /genome\.json/ ) {
	$md5sumValues{genome} = \%md5sumValue;
      } elsif ($items[1] =~ /seq_region\.json/) {
	$md5sumValues{seq_region} = \%md5sumValue;
      } elsif ($items[1] =~ /functional_annotation\.json/) {
	$md5sumValues{functional_annotation} = \%md5sumValue;
      } elsif ($items[1] =~ /functional_annotation\.json/) {
	$md5sumValues{functional_annotation} = \%md5sumValue;
      } elsif ($items[1] =~ /dna\.fa/) {
	$md5sumValues{fasta_dna} = \%md5sumValue;
      } elsif ($items[1] =~ /protein\.fa/) {
	$md5sumValues{fasta_pep} = \%md5sumValue;
      } elsif ($items[1] =~ /modified\.gff3/) {
	$md5sumValues{gff3} = \%md5sumValue;
      } elsif ($items[1] =~ /$abbrev\.gff3/) {
      } else {
	die "ERROR: non-except file found $items[1]\n";
      }
    }
  }
  close MDIN;

  my $md5sumJson = encode_json(\%md5sumValues);
  my $md5sumJsonFile = $orgOutputFileDir . "\/manifest.json";
  open (MDOUT, ">$md5sumJsonFile") || die "can not open $md5sumJsonFile of $abbrev file to write\n";
  print MDOUT "$md5sumJson\n";
  close MDOUT;


  ## 8) tar and gzip files
  my $tarFileName = $orgOutputFileDir . "\/" . $abbrev .".tar.gz";
#  my $filesToTar = $orgOutputFileDir . "\/" . $abbrev . "*";
  my $filesToTar = $orgOutputFileDir . "\/"  . "*";
  my $tarFilesCmd = "tar -czf $tarFileName $filesToTar";
  system ($tarFilesCmd);

  $tarFileName =~ s/^.*\///;
#  my $echoCmd = "echo \"To untar the files, \ntar -xvf $tarFileName\n\" ". "\>" . $orgOutputFileDir . "\/" . $abbrev . "_readme.txt";
#  system ($echoCmd);


  ## run json validator
  my $genomeJsonFile = $outputFileDir. "\/" . $abbrev . "\/" . $abbrev . "_genome.json";
  my $seqRegionFile = $outputFileDir. "\/" . $abbrev . "\/" . $abbrev . "_seq_region.json";
  my $functAnnotFile = $outputFileDir. "\/" . $abbrev . "\/" . $abbrev . "_functional_annotation.json";
  my $validateGenomeCmd = "jsonschema -i $genomeJsonFile /home/sufenhu/jsonSchema/genome_schema.json";
  system ($validateGenomeCmd);
  my $validateSeqRegionCmd = "jsonschema -i $seqRegionFile /home/sufenhu/jsonSchema/seq_region_schema.json";
  system ($validateSeqRegionCmd);
  if (-e $functAnnotFile) {
    my $validateFunctAnnotCmd = "jsonschema -i $functAnnotFile /home/sufenhu/jsonSchema/functional_annotation_schema.json";
    system ($validateFunctAnnotCmd);
  }
}

$dbh->disconnect();

###########
sub getNcbiTaxonId {
  my ($abbrev) = @_;

  my $sql = "select t.NCBI_TAX_ID from apidb.organism o, SRES.TAXON t where o.TAXON_ID=t.TAXON_ID and o.abbrev like '$abbrev'";

  my $stmt = $dbh->prepareAndExecute($sql);

  my @taxonArray;

  while ( my($ncbiTaxonId) = $stmt->fetchrow_array()) {
      push @taxonArray, $ncbiTaxonId;
    }

  die "No taxon_id found for '$abbrev'" unless(scalar(@taxonArray) > 0);

  die "trying to find unique taxon_id for '$abbrev', but more than one found" if(scalar(@taxonArray) > 1);

  return @taxonArray[0];
}

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
  --annotationFile: optional, an annotation file that need to be extracted separately
  --transpIdSuffix: optional, only need when --annotationFile called and need to add a suffix for transcript ID
  --gusConfigFile: optional, default is \$GUS_HOME/config/gus.config

";
}
