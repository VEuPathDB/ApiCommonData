#!/usr/bin/perl

use Getopt::Long;
use strict;
use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;
use DBD::Oracle;
use CBIL::Util::PropertySet;

my (
    $projectName,
    $excelFile,
    $organismAbbrev,
    $organismNameForFiles,
    $organismFullName,
    $strainAbbrev,
    $orthomclAbbrev,
    $ncbiTaxonId,
    $speciesNcbiTaxonId,
    $genomeSource,
    $genomeVersion,
    $isAnnotatedGenome,
    $annotationIncludesTRNAs,
    $isReferenceStrain,
    $referenceStrainOrganismAbbrev,
    $isFamilyRepresentative,
    $familyRepOrganismAbbrev,
    $familyNcbiTaxonIds,
    $familyNameForFiles,
    $haveChromosome,
    $haveSupercontig,
    $haveContig,
    $dbxrefVersion,
    $soTerm,
    $format,
    $secondaryAnnot,
    $sourceIdRegex,
    $isfMappingFile,

    $help);

&GetOptions(
	    'projectName=s' => \$projectName,
	    'organismAbbrev=s' => \$organismAbbrev,
	    'excelFile=s' => \$excelFile,
            'organismNameForFiles=s' => \$organismNameForFiles,
            'organismFullName=s' => \$organismFullName,
            'strainAbbrev=s' => \$strainAbbrev,
            'orthomclAbbrev=s' => \$orthomclAbbrev,
            'ncbiTaxonId=s' => \$ncbiTaxonId,
	    'speciesNcbiTaxonId' => \$speciesNcbiTaxonId,
	    'genomeSource' => \$genomeSource,
	    'genomeVersion' => \$genomeVersion,
	    'isAnnotatedGenome' => \$isAnnotatedGenome,
	    'annotationIncludesTRNAs' => \$annotationIncludesTRNAs,
	    'isReferenceStrain' => \$isReferenceStrain,
	    'referenceStrainOrganismAbbrev' => \$referenceStrainOrganismAbbrev,
	    'isFamilyRepresentative' => \$isFamilyRepresentative,
	    'familyRepOrganismAbbrev' => \$familyRepOrganismAbbrev,
	    'familyNcbiTaxonIds' => \$familyNcbiTaxonIds,
	    'familyNameForFiles' => \$familyNameForFiles,
	    'dbxrefVersion=s' => \$dbxrefVersion,
	    'soTerm' => \$soTerm,
	    'format=s' => \$format,
	    'secondaryAnnot=s' => \$secondaryAnnot,
	    'sourceIdRegex=s' => \$sourceIdRegex,
	    'isfMappingFile=s' => \$isfMappingFile,

	    'help|h' => \$help,
	    );
&usage() if($help);
&usage("Missing a Required Argument") unless(defined $projectName && $organismAbbrev && $excelFile);
&usage("Missing a Required Argument --sourceIdRegex") if ($format =~ /fasta/i && !$sourceIdRegex);
&usage("Missing a Required Argument --sourceIdRegex") if ($format =~ /genedb/i && !$sourceIdRegex);
&usage("Missing a Required Argument --sourceIdRegex --isfMappingFile") if ($format =~ /gff/i && (!$sourceIdRegex || !$isfMappingFile ) );
&usage("Missing a Required Argument --isfMappingFile") if ($format =~ /embl/i && !$isfMappingFile);

my (%excelInfo, @excelColumn, $orgAbbrevColumn);
my $count = 0;
open (EXL, "$excelFile") || die "can not open Excel File to read\n";
while (<EXL>) {
  chomp;
  my @items = split (/\t/, $_);

  if ($count == 0) {
    foreach my $i (0..$#items) {
      $excelColumn[$i] = $items[$i];  ## get the info of head line
      if ($items[$i] eq "organismAbbrev" ) {  ## get the column # for organismAbbrev
	$orgAbbrevColumn = $i;
      }
    }
  } else {
    foreach my $i (0..$#items) { ## get the info of whole spreadsheet
      ## get rid of the extra characters in () if there is any
      $items[$i] =~ s/\(.+$//;

      ## get rid of the spaces in both ends
      $items[$i] =~ s/^\s+//;
      $items[$i] =~ s/\s+$//;

      $excelInfo{$items[$orgAbbrevColumn]}{$excelColumn[$i]} = $items[$i];
    }
  }
  $count++;
}
close;

## add some constant value
$excelInfo{$organismAbbrev}{"publicOrganismAbbrev"} = $excelInfo{$organismAbbrev}{"organismAbbrev"};
$excelInfo{$organismAbbrev}{'projectName'} = $projectName;
$excelInfo{$organismAbbrev}{"referenceStrainOrganismAbbrev"} = $excelInfo{$organismAbbrev}{"organismAbbrev"} 
  if ($excelInfo{$organismAbbrev}{"isReferenceStrain"} =~ /^y/i);

## add secondaryAnnot if it is not get from arguments
if ($secondaryAnnot !~ /mito/i && $excelInfo{$organismAbbrev}{"hasMito"} =~ /^y/i) {
  die "ERROR: mito- genome included, please add argument: --secondaryAnnot 'mito'\n";
}
if ($secondaryAnnot !~ /api/i && $excelInfo{$organismAbbrev}{"hasApicoplast"} =~ /^y/i) {
  die "ERROR: api- genome included, please add argument: --secondaryAnnot 'api'\n";
}

if ($excelInfo{$organismAbbrev}{"haveChromosome"} =~ /^y/i) {
  if ($excelInfo{$organismAbbrev}{"haveSupercontig"} =~ /^y/i) {
    if ($secondaryAnnot !~ /superc/i) {
      die "ERROR: secondary genome, supercontig included, please add argument --secondaryAnnot 'supercontig'\n";
    }
  }
  if ($excelInfo{$organismAbbrev}{"haveContig"} =~ /^y/i) {
    if ($secondaryAnnot !~ /con/i || ($secondaryAnnot =~ /con/i && $secondaryAnnot =~ /superc/i) ) {
      die "ERROR: secondary genome, contig included, please add argument --secondaryAnnot 'contig'\n";
    }
  }
} else {
  if ($excelInfo{$organismAbbrev}{"haveSupercontig"} =~ /^y/i && $excelInfo{$organismAbbrev}{"haveContig"} =~ /^y/i ) {
    if ($secondaryAnnot !~ /cont/i) {
      die "ERROR: secondary genome, contig included, please add argument --secondaryAnnot 'contig'\n";
    }
  }
}

## check format is consistant with %excelInfo
if ($excelInfo{$organismAbbrev}{'isAnnotatedGenome'} =~ /^n/i ) {
  unless ($format =~ /fasta/i) {
    die "ERROR: The format argument is fasta, but isAnnotatedGenome in Excel file is not no\n";
  }
}

print STDERR "\$count = $count\n";
 
foreach my $j (0..$#excelColumn) {
#  print STDERR "$j, $excelColumn[$j]\n";
}

foreach my $k (sort keys %excelInfo) {
  if ($k eq $organismAbbrev) {
    foreach my $kk (sort keys %{$excelInfo{$k}}) {
      print STDERR "$k, $kk, $excelInfo{$k}{$kk}\n";
    }
  }
}

my $xmlDir = "xmlFile/";
mkdir("$xmlDir") unless -e "$xmlDir";
my $projFile = $xmlDir . $projectName. "_". $organismAbbrev. ".xml";
my $orgFile = $xmlDir. $organismAbbrev. ".bkp";

open (PO, ">$projFile") || die "can not open file to write\n";

printHeaderLine();
printRegularLine (\%excelInfo, $organismAbbrev, "organismAbbrev");
print PO "    <prop name=\"projectName\">\$\$projectName\$\$</prop>\n";

printRegularLine (\%excelInfo, $organismAbbrev, "ncbiTaxonId");
printRegularLine (\%excelInfo, $organismAbbrev, "publicOrganismAbbrev");
printRegularLine (\%excelInfo, $organismAbbrev, "organismFullName");
printRegularLine (\%excelInfo, $organismAbbrev, "organismNameForFiles");
printRegularLine (\%excelInfo, $organismAbbrev, "speciesNcbiTaxonId");
printTrueOrFalseLine (\%excelInfo, $organismAbbrev, "isReferenceStrain");

printRegularLine (\%excelInfo, $organismAbbrev, "referenceStrainOrganismAbbrev");
printTrueOrFalseLine (\%excelInfo, $organismAbbrev, "isAnnotatedGenome");
printTrueOrFalseLine (\%excelInfo, $organismAbbrev, "hasTemporaryNcbiTaxonId", $excelInfo{$organismAbbrev}{'ncbiTaxonId'});

printRegularLine (\%excelInfo, $organismAbbrev, "orthomclAbbrev");
printRegularLine (\%excelInfo, $organismAbbrev, "strainAbbrev");
printRegularLine (\%excelInfo, $organismAbbrev, "genomeSource");
printRegularLine (\%excelInfo, $organismAbbrev, "taxonHierarchyForBlastxFilter");

printTrueOrFalseLine (\%excelInfo, $organismAbbrev, "annotationIncludesTRNAs");
printLinesBasedProject ($projectName);

printRegularLine (\%excelInfo, $organismAbbrev, "genomeVersion");
printTrueOrFalseLine (\%excelInfo, $organismAbbrev, "isFamilyRepresentative");
printSpecialFamilyRepLines (\%excelInfo, $organismAbbrev);

printTailerLine();

printRefStrainLines (\%excelInfo, $organismAbbrev);

close PO;




##########  start print xml file for organism  ##########

open my $ofh, '>', $orgFile || die "can not open organism xml file to write\n";
print $ofh "<datasets>\n";

printConstantName ($ofh, \%excelInfo, "organismAbbrev");
printConstantName ($ofh, \%excelInfo, "strainAbbrev");
printConstantName ($ofh, \%excelInfo, "referenceStrainOrganismAbbrev");
printConstantName ($ofh, \%excelInfo, "familyRepOrganismAbbrev");
printConstantName ($ofh, \%excelInfo, "projectName");
printConstantName ($ofh, \%excelInfo, "ncbiTaxonId");
printConstantName ($ofh, \%excelInfo, "speciesNcbiTaxonId");
printConstantName ($ofh, \%excelInfo, "familyNcbiTaxonIds") if ($excelInfo{$organismAbbrev}{'familyNcbiTaxonIds'} =~ /^\d+/);
printConstantName ($ofh, \%excelInfo, "soTerm", "soTerm");
printConstantName ($ofh, \%excelInfo, "genomeSource");
printConstantName ($ofh, \%excelInfo, "genomeVersion");
printConstantName ($ofh, \%excelInfo, "source", "genomeSource");
printConstantName ($ofh, \%excelInfo, "functAnnotVersion", "genomeVersion");
print $ofh "\n";

printValidateOrganismInfo($ofh);

printAnnotation($ofh, $format, $secondaryAnnot) if ($format);

printProductNamesClass ($ofh, \%excelInfo) if ($excelInfo{$organismAbbrev}{'hasProduct'} =~ /^y/i);

printGOClass ($ofh, \%excelInfo) if ($excelInfo{$organismAbbrev}{'hasGO'} =~ /^y/i);

printECClass ($ofh, \%excelInfo, $format) if ($excelInfo{$organismAbbrev}{'hasEC'} =~ /^y/i);

printGeneNameClass ($ofh, \%excelInfo) if ($excelInfo{$organismAbbrev}{'hasName'} =~ /^y/i);

printSynonymClass ($ofh, \%excelInfo) if ($excelInfo{$organismAbbrev}{'hasSynonym'} =~ /^y/i);

printCommentClass ($ofh, \%excelInfo, "transcript") if ($excelInfo{$organismAbbrev}{'hasNote'} =~ /^t/i);
printCommentClass ($ofh, \%excelInfo, "gene") if ($excelInfo{$organismAbbrev}{'hasNote'} =~ /^g/i);

printGenbankProteinIdClass ($ofh, \%excelInfo) if ($format =~ /genbank/i && $excelInfo{$organismAbbrev}{'isAnnotatedGenome'} =~ /^y/i);

print STDERR "\$dbxrefVersion= $dbxrefVersion\n";
printGene2Entrez ($ofh, $dbxrefVersion) if ($excelInfo{$organismAbbrev}{'isAnnotatedGenome'} =~ /^y/i);
printGene2PubmedFromNcbi ($ofh, $dbxrefVersion) if ($excelInfo{$organismAbbrev}{'isAnnotatedGenome'} =~ /^y/i);
printGene2Uniprot ($ofh, $dbxrefVersion) if ($excelInfo{$organismAbbrev}{'isAnnotatedGenome'} =~ /^y/i);
printECAssocFromUniprot ($ofh) if ($excelInfo{$organismAbbrev}{'isAnnotatedGenome'} =~ /^y/i);

printRefStraindbEST ($ofh, \%excelInfo);
printRefStrainEpitope ($ofh, \%excelInfo) if ($excelInfo{$organismAbbrev}{'isAnnotatedGenome'} =~ /^y/i);
printIsolatesFromFamilyRep ($ofh, \%excelInfo);


print $ofh "</datasets>\n";

close $ofh;




##################### subroutine ###################
sub printSecondaryFasta {
  my ($fh, $secondAnnot) = @_;

  my @secondaryAnnotations = split (/\,/, $secondAnnot);

  foreach my $second (@secondaryAnnotations) {
    $second =~ s/^\s+//;

    ## print fasta
    if ($second =~ /^contig/i || $second =~ /^supercontig/i) {
      print $fh "  <dataset class=\"fasta_secondary_genome\">\n";
      printNameWithValue ($fh, 'soTerm', $second);
    } elsif ($second =~ /^api/i ) {
      print $fh "  <dataset class=\"fasta_organelle_genome\">\n";
      printNameWithValue ($fh, 'organelle', 'apicoplast');
      printNameWithValue ($fh, 'soTerm', 'apicoplast_chromosome');
    } elsif ($second =~ /^mito/i ) {
      print $fh "  <dataset class=\"fasta_organelle_genome\">\n";
      printNameWithValue ($fh, 'organelle', 'mitochondrion');
      printNameWithValue ($fh, 'soTerm', 'mitochondrial_chromosome');
    } else {
      next;
    }
    printNameWithDollarSign ($fh, 'projectName');
    printNameWithDollarSign ($fh, 'organismAbbrev');
    printNameWithDollarSign ($fh, 'ncbiTaxonId');
    printNameWithDollarSign ($fh, 'name', 'genomeSource');
    printNameWithDollarSign ($fh, 'version', 'genomeVersion');
    printNameWithValue ($fh, 'table', "DoTS::ExternalNASequence");
    printNameWithValue ($fh, 'sourceIdRegex', "$sourceIdRegex");
    print $fh "  </dataset>\n";
    print $fh "\n";
  }
}

sub printPrimaryFasta {
  my ($fh, $format, $secondAnnot) = @_;

  print $fh "  <dataset class=\"fasta_primary_genome_sequence\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'ncbiTaxonId');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  printNameWithDollarSign ($fh, 'version', 'genomeVersion');
  printNameWithDollarSign ($fh, 'soTerm');
  printNameWithValue ($fh, 'table', "DoTS::ExternalNASequence");
  printNameWithValue ($fh, 'sourceIdRegex', "$sourceIdRegex");
  printNameWithDollarSign ($fh, 'releaseDate', 'genomeVersion');
  print $fh "  </dataset>\n";
  print $fh "\n";

  printSecondaryFasta ($fh, $secondAnnot) if ($secondAnnot);

  return 0;
}

sub printAnnotation {
  my ($fh, $format, $secondAnnot) = @_;

  if ( $format =~ /genbank/i ) {
    printGenBankAnnotation ($fh, $format, $secondAnnot);
  } elsif ( $format =~ /genedb/i) {
    printGeneDBAnnotation ($fh, $format, $secondAnnot);
  } elsif ( $format =~ /gff3/i) {
    printGff3Annotation ($fh, $format, $secondAnnot);
  } elsif ( $format =~ /embl/i) {
    printEmblAnnotation ($fh, $format, $secondAnnot);
  } elsif ( $format =~ /fasta/i) {
    printPrimaryFasta ($fh, $format, $secondAnnot);
  } else {
    print STDERR "format have not been configured yet\n";
  }

  return 0;
}

sub printEmblAnnotation {
  my ($fh, $format, $secondAnnot) = @_;
  my @secondaryAnnotations = split (/\,/, $secondAnnot);

  ## print primary_genome
  print $fh "  <dataset class=\"embl_primary_genome\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'ncbiTaxonId');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  printNameWithDollarSign ($fh, 'version', 'genomeVersion');
  printNameWithDollarSign ($fh, 'soTerm');
  printNameWithValue ($fh, 'mapFile', "$isfMappingFile");
  printNameWithDollarSign ($fh, 'releaseDate', 'genomeVersion');
  print $fh "  </dataset>\n";
  print $fh "\n";


  foreach my $second (@secondaryAnnotations) {
    $second =~ s/^\s+//;

    ## print secondary_genome, include mito_ and api_
    if ($second =~ /^contig/i || $second =~ /^supercontig/i) {
      print $fh "  <dataset class=\"embl_secondary_genome\">\n";
      printNameWithValue ($fh, 'soTerm', $second);
    } elsif ($second =~ /^api/i ) {
      print $fh "  <dataset class=\"embl_organelle_genome\">\n";
      printNameWithValue ($fh, 'organelle', 'apicoplast');
      printNameWithValue ($fh, 'soTerm', 'apicoplast_chromosome');
    } elsif ($second =~ /^mito/i ) {
      print $fh "  <dataset class=\"embl_organelle_genome\">\n";
      printNameWithValue ($fh, 'organelle', 'mitochondrion');
      printNameWithValue ($fh, 'soTerm', 'mitochondrial_chromosome');
    } else {
      next;
      print STDERR "The secondary annotation has not been configurated yet!";
    }
    printNameWithDollarSign ($fh, 'projectName');
    printNameWithDollarSign ($fh, 'organismAbbrev');
    printNameWithDollarSign ($fh, 'ncbiTaxonId');
    printNameWithDollarSign ($fh, 'version', 'genomeVersion');
    printNameWithDollarSign ($fh, 'name', 'genomeSource');
    printNameWithValue ($fh, 'mapFile', "$isfMappingFile");
    print $fh "  </dataset>\n";
    print $fh "\n";
  }
  return 0;
}

sub printGff3Annotation {
  my ($fh, $format, $secondAnnot) = @_;
  my @secondaryAnnotations = split (/\,/, $secondAnnot);

  ## print fasta
  print $fh "  <dataset class=\"fasta_primary_genome_sequence\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'ncbiTaxonId');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  printNameWithDollarSign ($fh, 'version', 'genomeVersion');
  printNameWithDollarSign ($fh, 'soTerm');
  printNameWithValue ($fh, 'table', "DoTS::ExternalNASequence");
  printNameWithValue ($fh, 'sourceIdRegex', "$sourceIdRegex");
  printNameWithDollarSign ($fh, 'releaseDate', 'genomeVersion');
  print $fh "  </dataset>\n";
  print $fh "\n";

  ## print GFF
  print $fh "  <dataset class=\"NoPreprocess_primary_genome_features\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'ncbiTaxonId');
  printNameWithDollarSign ($fh, 'source', 'genomeSource');
  printNameWithDollarSign ($fh, 'version', 'genomeVersion');
  printNameWithDollarSign ($fh, 'soTerm');
  printNameWithValue ($fh, 'mapFile', "$isfMappingFile");
  print $fh "  </dataset>\n";
  print $fh "\n";

  foreach my $second (@secondaryAnnotations) {
    $second =~ s/^\s+//;

    ## print fasta
    if ($second =~ /^contig/i || $second =~ /^supercontig/i) {
      print $fh "  <dataset class=\"fasta_secondary_genome\">\n";
      printNameWithValue ($fh, 'soTerm', $second);
    } elsif ($second =~ /^api/i ) {
      print $fh "  <dataset class=\"fasta_organelle_genome\">\n";
      printNameWithValue ($fh, 'organelle', 'apicoplast');
      printNameWithValue ($fh, 'soTerm', 'apicoplast_chromosome');
    } elsif ($second =~ /^mito/i ) {
      print $fh "  <dataset class=\"fasta_organelle_genome\">\n";
      printNameWithValue ($fh, 'organelle', 'mitochondrion');
      printNameWithValue ($fh, 'soTerm', 'mitochondrial_chromosome');
    } else {
      next;
    }
    printNameWithDollarSign ($fh, 'projectName');
    printNameWithDollarSign ($fh, 'organismAbbrev');
    printNameWithDollarSign ($fh, 'ncbiTaxonId');
    printNameWithDollarSign ($fh, 'name', 'genomeSource');
    printNameWithDollarSign ($fh, 'version', 'genomeVersion');
    printNameWithValue ($fh, 'table', "DoTS::ExternalNASequence");
    printNameWithValue ($fh, 'sourceIdRegex', "$sourceIdRegex");
    print $fh "  </dataset>\n";
    print $fh "\n";

    ## print GFF
    if ($second =~ /^contig/i || $second =~ /^supercontig/i) {
      print $fh "  <dataset class=\"NoPreprocess_secondary_genome_features\">\n";
      printNameWithValue ($fh, 'soTerm', $second);
    } elsif ($second =~ /^api/i ) {
      print $fh "  <dataset class=\"NoPreprocess_organelle_genome_features\">\n";
      printNameWithValue ($fh, 'organelle', 'apicoplast');
      printNameWithValue ($fh, 'soTerm', 'apicoplast_chromosome');
    } elsif ($second =~ /^mito/i ) {
      print $fh "  <dataset class=\"NoPreprocess_organelle_genome_features\">\n";
      printNameWithValue ($fh, 'organelle', 'mitochondrion');
      printNameWithValue ($fh, 'soTerm', 'mitochondrial_chromosome');
    } else {
      next;
    }
    printNameWithDollarSign ($fh, 'projectName');
    printNameWithDollarSign ($fh, 'organismAbbrev');
    printNameWithDollarSign ($fh, 'ncbiTaxonId');
    printNameWithDollarSign ($fh, 'version', 'genomeVersion');
    printNameWithDollarSign ($fh, 'name', 'genomeSource');
    printNameWithValue ($fh, 'mapFile', "$isfMappingFile");
    print $fh "  </dataset>\n";
    print $fh "\n";
  }
  return 0;
}


sub printGeneDBAnnotation {
  my ($fh, $format, $secondAnnot) = @_;
  my @secondaryAnnotations = split (/\,/, $secondAnnot);

  ## print fasta
  print $fh "  <dataset class=\"fasta_primary_genome_sequence\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'ncbiTaxonId');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  printNameWithDollarSign ($fh, 'version', 'genomeVersion');
  printNameWithDollarSign ($fh, 'soTerm');
  printNameWithValue ($fh, 'table', "DoTS::ExternalNASequence");
  printNameWithValue ($fh, 'sourceIdRegex', "$sourceIdRegex");
  printNameWithDollarSign ($fh, 'releaseDate', 'genomeVersion');
  print $fh "  </dataset>\n";
  print $fh "\n";

  ## print GFF
  print $fh "  <dataset class=\"GeneDB_GFF_primary_genome_features\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'ncbiTaxonId');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  printNameWithDollarSign ($fh, 'version', 'genomeVersion');
  printNameWithDollarSign ($fh, 'soTerm');
  printNameWithValue ($fh, 'mapFile', "geneDBGFF2Gus.xml");
  print $fh "  </dataset>\n";
  print $fh "\n";

  foreach my $second (@secondaryAnnotations) {
    $second =~ s/^\s+//;

    ## print fasta
    if ($second =~ /^contig/i || $second =~ /^supercontig/i) {
      print $fh "  <dataset class=\"fasta_secondary_genome\">\n";
      printNameWithValue ($fh, 'soTerm', $second);
    } elsif ($second =~ /^api/i ) {
      print $fh "  <dataset class=\"fasta_organelle_genome\">\n";
      printNameWithValue ($fh, 'organelle', 'apicoplast');
      printNameWithValue ($fh, 'soTerm', 'apicoplast_chromosome');
    } elsif ($second =~ /^mito/i ) {
      print $fh "  <dataset class=\"fasta_organelle_genome\">\n";
      printNameWithValue ($fh, 'organelle', 'mitochondrion');
      printNameWithValue ($fh, 'soTerm', 'mitochondrial_chromosome');
    } else {
      next;
    }
    printNameWithDollarSign ($fh, 'projectName');
    printNameWithDollarSign ($fh, 'organismAbbrev');
    printNameWithDollarSign ($fh, 'ncbiTaxonId');
    printNameWithDollarSign ($fh, 'name', 'genomeSource');
    printNameWithDollarSign ($fh, 'version', 'genomeVersion');
    printNameWithValue ($fh, 'table', "DoTS::ExternalNASequence");
    printNameWithValue ($fh, 'sourceIdRegex', "$sourceIdRegex");
    print $fh "  </dataset>\n";
    print $fh "\n";

    ## print GFF
    if ($second =~ /^contig/i || $second =~ /^supercontig/i) {
      print $fh "  <dataset class=\"GeneDB_GFF_secondary_genome_features\">\n";
      printNameWithValue ($fh, 'soTerm', $second);
    } elsif ($second =~ /^api/i ) {
      print $fh "  <dataset class=\"GeneDB_GFF_organelle_genome_features\">\n";
      printNameWithValue ($fh, 'organelle', 'apicoplast');
      printNameWithValue ($fh, 'soTerm', 'apicoplast_chromosome');
    } elsif ($second =~ /^mito/i ) {
      print $fh "  <dataset class=\"GeneDB_GFF_organelle_genome_features\">\n";
      printNameWithValue ($fh, 'organelle', 'mitochondrion');
      printNameWithValue ($fh, 'soTerm', 'mitochondrial_chromosome');
    } else {
      next;
    }
    printNameWithDollarSign ($fh, 'projectName');
    printNameWithDollarSign ($fh, 'organismAbbrev');
    printNameWithDollarSign ($fh, 'ncbiTaxonId');
    printNameWithDollarSign ($fh, 'version', 'genomeVersion');
    print $fh "  </dataset>\n";
    print $fh "\n";
  }
  return 0;
}

sub printGenBankAnnotation {
  my ($fh, $format, $secondAnnot) = @_;
  $isfMappingFile = "genbankGenbank2Gus.xml" if (!$isfMappingFile);
  my @secondaryAnnotations = split (/\,/, $secondAnnot);
  print $fh "  <dataset class=\"genbank_primary_genome\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'ncbiTaxonId');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  printNameWithDollarSign ($fh, 'version', 'genomeVersion');
  printNameWithDollarSign ($fh, 'soTerm');
  printNameWithValue ($fh, 'mapFile', $isfMappingFile);
  printNameWithDollarSign ($fh, 'releaseDate', 'genomeVersion');
  print $fh "  </dataset>\n";
  print $fh "\n";

  foreach my $second (@secondaryAnnotations) {
    $second =~ s/^\s+//;
    if ($second =~ /^contig/i || $second =~ /^supercontig/i) {
      print $fh "  <dataset class=\"genbank_secondary_genome\">\n";
      printNameWithValue ($fh, 'soTerm', $second);
    } elsif ($second =~ /^api/i ) {
      print $fh "  <dataset class=\"genbank_organelle_genome\">\n";
      printNameWithValue ($fh, 'organelle', 'apicoplast');
      printNameWithValue ($fh, 'soTerm', 'apicoplast_chromosome');
    } elsif ($second =~ /^mito/i ) {
      print $fh "  <dataset class=\"genbank_organelle_genome\">\n";
      printNameWithValue ($fh, 'organelle', 'mitochondrion');
      printNameWithValue ($fh, 'soTerm', 'mitochondrial_chromosome');
    } else {
      next;
    }
    printNameWithDollarSign ($fh, 'projectName');
    printNameWithDollarSign ($fh, 'organismAbbrev');
    printNameWithDollarSign ($fh, 'ncbiTaxonId');
    printNameWithDollarSign ($fh, 'name', 'genomeSource');
    printNameWithDollarSign ($fh, 'version', 'genomeVersion');
    printNameWithValue ($fh, 'mapFile', 'genbankGenbank2Gus.xml');
    print $fh "  </dataset>\n";
    print $fh "\n";
  }
  return 0;
}

sub printRefStraindbEST {
  my ($fh, $excelInfoPoint) = @_;
  if ($excelInfoPoint->{$organismAbbrev}->{'isReferenceStrain'} =~ /^y/i) {
    print $fh "  <dataset class=\"referenceStrain-dbEST\">\n";
    printNameWithDollarSign ($fh, 'projectName');
    printNameWithDollarSign ($fh, 'organismAbbrev');
    printNameWithDollarSign ($fh, 'speciesNcbiTaxonId');
    print $fh "  </dataset>\n";
    print $fh "\n";
  }

  print $fh "  <dataset class=\"transcriptsFromReferenceStrain\">\n";
  printNameWithDollarSign ($fh, 'referenceStrainOrganismAbbrev');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printRefStrainEpitope {
  my ($fh, $excelInfoPoint) = @_;
  if ($excelInfoPoint->{$organismAbbrev}->{'isReferenceStrain'} =~ /^y/i) {
    print $fh "  <dataset class=\"referenceStrain-epitope_sequences_IEDB\">\n";
    printNameWithDollarSign ($fh, 'organismAbbrev');
    printNameWithDollarSign ($fh, 'speciesNcbiTaxonId');
    printNameWithValue ($fh, 'version', '3.10.0');
    print $fh "  </dataset>\n";
    print $fh "\n";
  }

  print $fh "  <dataset class=\"epitopesFromReferenceStrain\">\n";
  printNameWithDollarSign ($fh, 'referenceStrainOrganismAbbrev');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printIsolatesFromFamilyRep {
  my ($fh, $excelInfoPoint) = @_;
  if ($excelInfoPoint->{$organismAbbrev}->{'isFamilyRepresentative'} =~ /^y/i) {
    print $fh "  <dataset class=\"familyRepresentative-isolatesGenbank\">\n";
    printNameWithDollarSign ($fh, 'organismAbbrev');
    printNameWithDollarSign ($fh, 'ncbiTaxonId', 'familyNcbiTaxonIds');
    print $fh "  </dataset>\n";
    print $fh "\n";
  }

  print $fh "  <dataset class=\"isolatesFromFamilyRepresentative\">\n";
  printNameWithValue ($fh, 'name', 'genbank');
  printNameWithDollarSign ($fh, 'familyRepOrganismAbbrev');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printGene2Entrez {
  my ($fh, $version) = @_;
  print $fh "  <dataset class=\"dbxref_gene2Entrez\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'ncbiTaxonId');
  printNameWithDollarSign ($fh, 'genomeVersion');
  printNameWithValue ($fh, 'version', $version);
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printGene2PubmedFromNcbi {
  my ($fh, $version) = @_;
  print $fh "  <dataset class=\"dbxref_gene2PubmedFromNcbi\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'ncbiTaxonId');
  printNameWithDollarSign ($fh, 'genomeVersion');
  printNameWithValue ($fh, 'version', $version);
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printGene2Uniprot {
  my ($fh, $version) = @_;
  print $fh "  <dataset class=\"dbxref_gene2Uniprot\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'ncbiTaxonId');
  printNameWithDollarSign ($fh, 'genomeVersion');
  printNameWithValue ($fh, 'version', $version);
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printECAssocFromUniprot {
  my ($fh) = @_;
  print $fh "  <dataset class=\"ECAssocFromUniprot\">\n";
  printNameWithDollarSign ($fh, 'speciesNcbiTaxonId');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithValue ($fh, 'version', "TODAY");
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printGenbankProteinIdClass {
  my ($fh, $excelInfoPoint) = @_;
  print $fh "  <dataset class=\"aliases\">\n";
  printNameWithValue ($fh, 'name', "gbProteinId");
  printNameWithDollarSign ($fh, 'version', 'genomeVersion');
  printNameWithValue ($fh, 'idType', "alternate id");
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithValue ($fh, 'columnSpec', "primary_identifier");
  printNameWithValue ($fh, 'url', "<![CDATA[http://www.ncbi.nlm.nih.gov/protein/EXTERNAL_ID_HERE]]>");
  printNameWithEmptyValue ($fh, 'urlUsesSecondaryId');
  printNameWithValue ($fh, 'target', "NAFeature");
  printNameWithValue ($fh, 'viewName', "Transcript");
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printGOClass {
  my ($fh, $excelInfoPoint) = @_;
  print $fh "  <dataset class=\"GeneOntologyAssociations\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'version', 'functAnnotVersion');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printECClass {
  my ($fh, $excelInfoPoint, $format) = @_;
  print $fh "  <dataset class=\"EnzymeCommissionAssociations\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'version', 'functAnnotVersion');
  ($format =~ /genbank/i) ? printNameWithValue ($fh, 'name', "gb") : printNameWithDollarSign ($fh, 'name', 'genomeSource');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printCommentClass {
  my ($fh, $excelInfoPoint, $geneOrTrans) = @_;
  print $fh "  <dataset class=\"comments\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  my $commentName = $excelInfoPoint->{$organismAbbrev}->{'genomeSource'} . "_" . $geneOrTrans;
  printNameWithValue ($fh, 'name', $commentName);
  printNameWithDollarSign ($fh, 'version', 'functAnnotVersion');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printGeneNameClass {
  my ($fh, $excelInfoPoint) = @_;
  print $fh "  <dataset class=\"geneName\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'genomeVersion');
  printNameWithDollarSign ($fh, 'version', 'functAnnotVersion');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printSynonymClass {
  my ($fh, $excelInfoPoint) = @_;
  print $fh "  <dataset class=\"dbxref_synonym\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'version', 'functAnnotVersion');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printProductNamesClass {
  my ($fh, $excelInfoPoint) = @_;
  print $fh "  <dataset class=\"productNames\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'version', 'functAnnotVersion');
  printNameWithDollarSign ($fh, 'name', 'source');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printValidateOrganismInfo {
  my ($fh, $item) = @_;
  print $fh "  <dataset class=\"validateOrganismInfo\">\n";

  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'strainAbbrev');
  printNameWithDollarSign ($fh, 'ncbiTaxonId');
  printNameWithDollarSign ($fh, 'speciesNcbiTaxonId');
  printNameWithDollarSign ($fh, 'genomeVersion');

  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}
sub printNameWithDollarSign {
  ## print <prop name="projectName">$$projectName$$</prop>
  my ($fh, $item, $value) = @_;
  $value = $item if (!$value);
  print $fh "    <prop name=\"$item\">\$\$$value\$\$</prop>\n";
  return 0;
}

sub printNameWithValue {
  ## print <prop name="name">GeneDB_transcript</prop>
  my ($fh, $item, $value) = @_;
  $value = $item if (!$value);
  print $fh "    <prop name=\"$item\">$value</prop>\n";
  return 0;
}

sub printNameWithEmptyValue {
  ## <prop name="urlUsesSecondaryId"></prop> 
  my ($fh, $item) = @_;
  print $fh "    <prop name=\"$item\"></prop>\n";
  return 0;
}

sub printConstantName {
  ## print <constant name="strainAbbrev" value="yoelii17X"/>
  my ($fh, $excelInfoPoint, $item, $value) = @_;
  $value = $item if (!$value);
  print $fh "  <constant name=\"$item\" value=\"$excelInfoPoint->{$organismAbbrev}->{$value}\"\/>\n";
  return 0;
}

sub printHeaderLine {
  print PO "  <dataset class=\"organism\">\n";
}
sub printTailerLine {
  print PO "  </dataset>\n";
}

sub printRegularLine {
  my ($excelInfoPoint, $organismAbbrev, $item) = @_;
  print PO "    <prop name=\"$item\">$excelInfoPoint->{$organismAbbrev}->{$item}</prop>\n";
  return 0;
}

sub printTrueOrFalseLine { ## take 3 or 4 arguments depend if need judge based on the value of the 4th argument
  my ($excelInfoPoint, $organismAbbrev, $item, $value) = @_;
  my $tof;

  if ($value) {  ## if there is the 4th argument, print true or false based on the 4th argument
    $tof = ($value =~ /^9/ && length($value) == 10) ? "true" : "false";
  } else {
    $tof = ($excelInfoPoint->{$organismAbbrev}->{$item} =~ /^Y/i ) ? "true" : "false";
  }
  $tof = "true" if ($item eq "annotationIncludesTRNAs" && $excelInfoPoint->{$organismAbbrev}->{'isAnnotatedGenome'} !~ /^Y/i);
  print PO "    <prop name=\"$item\">$tof</prop>\n";
  return 0;
}

sub printSpecialFamilyRepLines { ## print the lines related with familyRepresent based on $isFamilyRepresentative
  my ($excelInfoPoint, $organismAbbrev) = @_;
  my $tof;

  if ($excelInfoPoint->{$organismAbbrev}->{'isFamilyRepresentative'} =~ /^Y/i) {
    print PO "    <prop name=\"familyRepOrganismAbbrev\">$organismAbbrev</prop>\n";
    print PO "    <prop name=\"familyNcbiTaxonIds\">$excelInfoPoint->{$organismAbbrev}->{'familyNcbiTaxonIds'}</prop>\n";
    print PO "    <prop name=\"familyNameForFiles\">$excelInfoPoint->{$organismAbbrev}->{'familyNameForFiles'}</prop>\n";
  } else {
    print PO "    <prop name=\"familyRepOrganismAbbrev\">$excelInfoPoint->{$organismAbbrev}->{'familyRepOrganismAbbrev'}</prop>\n";
    print PO "    <prop name=\"familyNcbiTaxonIds\"></prop>\n";
    print PO "    <prop name=\"familyNameForFiles\"></prop>\n";
  }
  return 0;
}

sub printRefStrainLines { ## print the reference lines based on isReferenceStrain info
  my ($excelInfoPoint, $organismAbbrev) = @_;
  my $tof;
  if ($excelInfoPoint->{$organismAbbrev}->{'isReferenceStrain'} =~ /^Y/i) {
    print PO "\n";
    print PO "  <dataset class=\"referenceStrain\">\n";
    print PO "    <prop name=\"organismAbbrev\">$organismAbbrev</prop>\n";
    $tof = ($excelInfoPoint->{$organismAbbrev}->{'isAnnotatedGenome'} =~ /^Y/i) ? "true" : "false";
    print PO "    <prop name=\"isAnnotatedGenome\">$tof</prop>\n";
    print PO "  </dataset>\n";
  }
  return 0;
}

sub printLinesBasedProject { ## print several lines based on projectname
  my ($projectName) = @_;
  my $tof;
  my $runExportPred =  ($projectName =~ /Plasmo/i) ? "true" : "false";

  my $isHugeGenome = ($projectName =~ /Host/i) ? "true" : "false";

  my $maxIntronSize;
  if ($projectName =~ /Microsporidia/i) {
    $maxIntronSize = 100;
  } elsif ($projectName =~ /Giardia/i) {
    $maxIntronSize = 500;
  } elsif ($projectName =~ /Fungi/i) {
    $maxIntronSize = 1000;
  } elsif ($projectName =~ /Trich/i) {
    $maxIntronSize = 1200;
  } elsif ($projectName =~ /TriTryp/i) {
    $maxIntronSize = 2000;
  } elsif ($projectName =~ /Schisto/i) {
    $maxIntronSize = 30000;
  } elsif ($projectName =~ /Host/i) {
    $maxIntronSize = 750000;
  } else {
    $maxIntronSize = 20000;
  }

  print PO "    <prop name=\"runExportPred\">$runExportPred</prop>\n";
  print PO "    <prop name=\"isHugeGenome\">$isHugeGenome</prop>\n";
  print PO "    <prop name=\"maxIntronSize\">$maxIntronSize</prop>\n";
  return 0;
}

sub usage {
  die
"
Usage: printDatasetXmlFileToLoad.pl --organismAbbrev ffujIMI58289 --excelFile organismExcelFile.txt --projectName FungiDB --dbxrefVersion 2017-01-30
       printDatasetXmlFileToLoad.pl --organismAbbrev afumA1163 --excelFile organismExcelFile.txt --projectName FungiDB --dbxrefVersion 2017-03-06
                                    --format gff3 --sourceIdRegex '^>(\\S+)' --isfMappingFile genemRNAExonCDS2Gus.xml
 

where
  --organismAbbrev: required, the organism abbrev
  --excelFile: required, the excel file in .txt format that has all info of genome
  --projectName: required, project name, such as PlasmoDB, etc. in full name
  --dbxrefVersion: required, the version of dbxref_gene2Entrez, dbxref_gene2PubmedFromNcbi, dbxref_gene2Uniprot
  --format: optional, the format of annotation, such as GenBank, GeneDB, and etc.
  --secondaryAnnot: optional, the soTerm of secondary annotation, separated by ",", such as 'contig, api-, mito-'
  --sourceIdRegex: optional, it is required if format is gff3 or fasta
  --isfMappingFile: optional, it is required if format is gff3 or embl. Also required if it doesn't use genbankGenbank2Gus.xml

";
}
