#!/usr/bin/perl

use strict;
use JSON;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;


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

my $sql = "select abbrev, is_annotated_genome from apidb.organism";

my $stmt = $dbh->prepareAndExecute($sql);

while (my ($abbrev, $isAnnot) = $stmt->fetchrow_array()) {
  $isAnnotated{$abbrev} = $isAnnot;
}
$stmt->finish();

$dbh->disconnect();

## in case do not need to export whole set of organism, then give a list of organism abbrev
if ($organismListFile) {
  my %isAnnotated = {};
  open (IN, "$organismListFile") || die "can not open $organismListFile file to read\n";
  while (<IN>) {
    chomp;
    my @items = split (/\t/, $_);
    $isAnnotated{$items[0]} = $items[1];
  }
  close IN;
}

my $c = 0;
foreach my $abbrev (sort keys %isAnnotated) {

  print STDERR "processing $abbrev ......\n";

  ## 1) make genome fasta file
  my $makeGenomeFastaCmd;

  ## 2) make gff3 and protein file
  if ($isAnnotated{$abbrev} == 1) {
    my $makeGff3Cmd = "makeGff4BRC4.pl --orgAbbrev $abbrev --gusConfigFile $gusConfigFile --outputFileDir $outputFileDir --ifSeparateParents Y";
    system($makeGff3Cmd);

    my $makeProteinFastaCmd;

    my $functAnnotJsonCmd = "generateFunctionalAnnotationJson.pl --organismAbbrev $abbrev --gusConfigFile $gusConfigFile --outputFileDir $outputFileDir";
    system($functAnnotJsonCmd);

  }

  ## 3) make genome metadata json file
  my $genomeJsonCmd = "generateGenomeJson.pl --genomeSummaryFile GenomeSummary.txt --organismAbbrev $abbrev --outputFileDir $outputFileDir";
  system($genomeJsonCmd);

  ## 4) make seq region metadata json file
  my $seqRegionJsonCmd = "generateSeqRegionJson.pl --organismAbbrev $abbrev --gusConfigFile $gusConfigFile --outputFileDir $outputFileDir";
  system($seqRegionJsonCmd);

  ## 5) make manifest file
  my $runManifestCmd;
  my $makeManifestFileCmd;

#  $c++;
#  last if ($c > 2);
}



###########

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
