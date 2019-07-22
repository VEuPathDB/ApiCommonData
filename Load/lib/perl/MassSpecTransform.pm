package ApiCommonData::Load::MassSpecTransform;
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
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;

use vars qw( @ISA );

# these are required columns in the input file
sub getProteinIdColumn                  { $_[0]->{proteinIdColumn} }
sub setProteinIdColumn                  { $_[0]->{proteinIdColumn} = $_[1] eq "" ? undef : $_[1] }
sub getPeptideSequenceColumn            { $_[0]->{peptideSequenceColumn} }
sub setPeptideSequenceColumn            { $_[0]->{peptideSequenceColumn} = $_[1] eq "" ? undef : $_[1] }

# these are optional in the input file
sub getGeneSourceIdColumn               { $_[0]->{geneSourceIdColumn} }
sub setGeneSourceIdColumn               { $_[0]->{geneSourceIdColumn} = $_[1] eq "" ? undef : $_[1] }
sub getPeptideSpectrumColumn            { $_[0]->{peptideSpectrumColumn} }
sub setPeptideSpectrumColumn            { $_[0]->{peptideSpectrumColumn} = $_[1] eq "" ? undef : $_[1] }
sub getPeptideIonScoreColumn            { $_[0]->{peptideIonScoreColumn} }
sub setPeptideIonScoreColumn            { $_[0]->{peptideIonScoreColumn} = $_[1] eq "" ? undef : $_[1] }


sub getInputFile                        { $_[0]->{inputFile} }
sub getOutputFile                       { $_[0]->{outputFile} }

sub getOutputFh                         { $_[0]->{output_fh} }
sub setOutputFh {
  my ($self) = @_;

  my $outputFile = $self->getOutputFile();

  open(OUT, "> $outputFile") or die "Cannot open output file $outputFile for writing:$!";

  $self->{output_fh} = \*OUT;
}



sub getSkipLinesCount                   { $_[0]->{skipLinesCount} }
sub getDelimiter                        { $_[0]->{delimiter} }
sub getTrimPeptideRegex                 { $_[0]->{trimPeptideRegex} }
sub getHeaderRegex                      { $_[0]->{headerRegex} }

sub getData                             { $_[0]->{data} }

sub debug                               { $_[0]->{debug} }

sub new {
  my ($class, $args) = @_;

  # I only want valid values or undef (not the empty string)
  foreach my $arg (keys %$args) {
    my $value = $args->{$arg};
    if($value eq "") {
      $args->{$arg} = undef;
    }
  }

  unless($args->{inputFile} && $args->{outputFile}) {
    die "Could Not create class $class";
  }


  return bless $args, $class;
}

sub printXmlConfig {
  my ($self) = @_;

  my $proteinIdColumn = $self->getProteinIdColumn();
  my $geneSourceIdColumn = $self->getGeneSourceIdColumn();

  my $peptideSequenceColumn = $self->getPeptideSequenceColumn();
  my $peptideSpectrumColumn = $self->getPeptideSpectrumColumn();
  my $peptideIonScoreColumn = $self->getPeptideIonScoreColumn();

  print "Make Sure all of these lines are included in your Config File and Re-Run!!!\n\n";


  print "proteinIdColumn=$proteinIdColumn\n";
  print "geneSourceIdColumn=$geneSourceIdColumn\n";

  print "peptideSequenceColumn=$peptideSequenceColumn\n";
  print "peptideSpectrumColumn=$peptideSpectrumColumn\n";
  print "peptideIonScoreColumn=$peptideIonScoreColumn\n";

  exit;
}


sub hasMissingRequiredColumnInfo {
  my ($self) = @_;

  unless(defined $self->getProteinIdColumn() && defined $self->getPeptideSequenceColumn()) {
    return 1;
  }

  return 0;
}


sub hasMissingColumnInfo {
  my ($self) = @_;

  if($self->hasMissingRequiredColumnInfo()) {
    return 1;
  }

  unless(defined $self->getGeneSourceIdColumn() && defined $self->getPeptideSpectrumColumn() &&
         defined $self->getPeptideIonScoreColumn()) {
    return 1;
  }

  return 0;
}

sub isHeaderLine {
  my ($self, $lineString, $lineArray) = @_;

  my $headerRegex = $self->getHeaderRegex();

  if($lineString =~ $headerRegex) {
    return 1;
  }
  return 0;

}


# may need to override this 
sub isProteinLine {
  my ($self, $lineString, $lineArray) = @_;

  my $proteinIdIndex = $self->getProteinIdColumn();

  if($lineArray->[$proteinIdIndex]) {
    return 1;
  }
  return 0;
}


# Some input files will have the protein id and the peptides on the same line;  Will need to override this method in that case
sub isPeptideLine {
  my ($self, $lineString, $lineArray) = @_;
  if($self->isProteinLine($lineString, $lineArray)) {
    return 0;
  }
  return 1;
}

# return a hashmap which maps symbols to sequence_ontology_terms for residue modifications;  May need to modify or override in a subclass??
sub getReportedModificationSymbolMap {
  my ($self) = @_;

  my $rv = { '*' => 'phosphorylation_site',
  };

  return $rv;
}

sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  my $rv = {'+' => 'Oxidation',
  };

  return $rv;
}

sub askForColumns {
  my ($self, $line, $a) = @_;

  my $count = 0;
  foreach my $header (@$a) {
    print "[$count] $header\n";
    $count++;
  }

  unless(defined $self->getProteinIdColumn()) {
    print "Enter Column Number for The Protein Identifier:  ";
    my $proteinId = <STDIN>;
    chomp $proteinId;
    $self->setProteinIdColumn($proteinId);
  }

  unless(defined $self->getGeneSourceIdColumn()) {
    print "Enter Column Number for The Gene Source ID:  ";
    my $geneSourceId = <STDIN>;
    chomp $geneSourceId;
    $self->setGeneSourceIdColumn($geneSourceId);
  }

  unless(defined $self->getPeptideSequenceColumn()) {
    print "Enter Column Number for the Peptide Sequence:  ";
    my $peptideSequence = <STDIN>;
    chomp $peptideSequence;
    $self->setPeptideSequenceColumn($peptideSequence);
  }

  unless(defined $self->getPeptideSpectrumColumn()) {
    print "Enter Column Number for the Peptide Spectrum:  ";
    my $peptideSpectrum = <STDIN>;
    chomp $peptideSpectrum;
    $self->setPeptideSpectrumColumn($peptideSpectrum);
  }

  unless(defined $self->getPeptideIonScoreColumn()) {
    print "Enter Column Number for The PeptideIonScore:  ";
    my $peptideIonScore = <STDIN>;
    chomp $peptideIonScore;
    $self->setPeptideIonScoreColumn($peptideIonScore);
  }
}


sub readFile {
  my ($self) = @_;

  my $file = $self->getInputFile();
  my $delimiter = $self->getDelimiter();

  open(FILE, $file) or die "Cannot open file $file for reading: $!";

  if(my $skipLines = $self->getSkipLinesCount()) {
    foreach(1..$skipLines) {
      print STDERR "Skipping line $_\n" if($self->debug());
      <FILE>;
    }
  }

  my $currentProteinId;
  my $proteinCount = 0;

  my $printOnly = $self->hasMissingRequiredColumnInfo();


  unless(defined $self->getPeptideSpectrumColumn()) {
    print STDERR "SEVERE WARNING:  YOU DIDN'T PROVIDE A SPECTRUM COUNT COLUMN FOR PEPTIDES!!  FIX AND RERUN IF YOUR INPUT FILE CONTAINS THIS INFORMATION\n";
  }


  while(my $line = <FILE>) {
    chomp($line);
    next unless($line);

    my @a = split($delimiter, $line);

    foreach my $i (0..$#a) {
      $a[$i] =~ s/^\s+//g;
      $a[$i] =~ s/\s+$//g;
    }

    if($self->isHeaderLine($line, \@a)) {

      if($self->hasMissingColumnInfo() && $proteinCount < 1) {
        $self->askForColumns($line, \@a);
      }
      print STDERR "Skipping header line: $line\n" if($self->debug());
      next ;
    }

    # fail if we get through all header lines and don't have required column info
    if($self->hasMissingRequiredColumnInfo()) {
      die "Could not resolve Required Colulmns";
    }

    if($printOnly) {
      $self->printXmlConfig();
    }

    if($self->isProteinLine($line, \@a)) {
      $currentProteinId = $a[$self->getProteinIdColumn()];
      my $geneId;
      if(defined $self->getGeneSourceIdColumn()) {
        $geneId = $a[$self->getGeneSourceIdColumn()];
      }

      $self->{data}->{$currentProteinId}->{gene} = $geneId;

      $proteinCount++
    }

    if($self->isPeptideLine($line, \@a)) {
      print STDERR "Found Peptide line: $line\n" if($self->debug());
      $self->addPeptide($currentProteinId, \@a);
    }

    last if($self->debug && $proteinCount == 2);
  }

  close FILE;
}


sub addPeptide {
  my ($self, $proteinId, $fields) = @_;
  
  my $peptideSequence = $fields->[$self->getPeptideSequenceColumn()];
  my $peptideSpectrum = 1; # default
  if(defined $self->getPeptideSpectrumColumn()) {
    $peptideSpectrum = (defined $fields->[$self->getPeptideSpectrumColumn()] ? $fields->[$self->getPeptideSpectrumColumn()] : 1);
    $peptideSpectrum = 1 if ($peptideSpectrum < 1);
  }

  my $peptideIonScore;
  if(defined $self->getPeptideIonScoreColumn()) {
    $peptideIonScore = $fields->[$self->getPeptideIonScoreColumn()];
  }

  my $cleanedPeptideSequence = $peptideSequence;
  
  my $trimPeptideRegex=$self->getTrimPeptideRegex();
  if($peptideSequence =~ /$trimPeptideRegex/) {
    $cleanedPeptideSequence = $1;
  }

  my $trimmedPeptideSequence = $self->removeModifications($cleanedPeptideSequence);

  if(my $peptideRecord = $self->findPeptideRecord($cleanedPeptideSequence, $proteinId)) {
    print STDERR "WARN:  Same Peptide seen twice:  $cleanedPeptideSequence" if($self->debug());
    
    $peptideRecord->{spectrum} = $peptideRecord->{spectrum} + $peptideSpectrum;
    return;
  }

  my $peptideRecord = {sequence => $trimmedPeptideSequence,
                       spectrum => $peptideSpectrum,
                       ion_score => $peptideIonScore,
                       sequence_full => $cleanedPeptideSequence
  };

  if($self->isPeptideModified($cleanedPeptideSequence, $trimmedPeptideSequence)) {
    $self->addModifications($peptideRecord, $cleanedPeptideSequence);
  }

  push @{$self->{data}->{$proteinId}->{peptides}}, $peptideRecord;
}


sub findPeptideRecord {
  my ($self, $cleanedPeptideSequence, $proteinId) = @_;

  my $peptideRecords = $self->{data}->{$proteinId}->{peptides};

  foreach my $peptideRecord(@$peptideRecords) {
    if($peptideRecord->{sequence_full} eq $cleanedPeptideSequence) {
      return $peptideRecord;
    }
  }
  return undef;
}

sub removeModifications {
  my ($self, $peptideSequence) = @_;

  my $modificationToIgnoreMap = $self->getIgnoredModificationSymbolMap;
  my $modificationToReportMap = $self->getReportedModificationSymbolMap;

  for my $key (keys %$modificationToReportMap) {
    die "the symbol $key is used for the reported modification $modificationToReportMap->{$key} and ignored $modificationToIgnoreMap->{key}" if  $modificationToIgnoreMap->{$key};
  }

  my @a;
  foreach(split("", $peptideSequence)) {
    push @a, $_ unless($modificationToIgnoreMap->{$_} || $modificationToReportMap->{$_});
  }

  return join("", @a);
}

sub addModifications {
  my ($self, $peptideRecord, $fullSequence) = @_;

  my $modificationToReportMap = $self->getReportedModificationSymbolMap;
  my $modificationToIgnoreMap = $self->getIgnoredModificationSymbolMap;

  my @trimmedResidues = split("", $peptideRecord->{sequence});
  my @residuesAndMods = split("", $fullSequence);

  my $expectedModificationCount = scalar(@residuesAndMods) - scalar(@trimmedResidues);

  my $countMods = 0;

  for(my $i = 0; $i < scalar @residuesAndMods; $i++) {
    my $rm = $residuesAndMods[$i];
    my $tr = $trimmedResidues[$i];

    if(my $modificationType = $modificationToReportMap->{$residuesAndMods[$i]}) {
      die "Peptide sequence cannot begin w/ a Modification:  $fullSequence" if($i ==0);
      
      $countMods++;

      my $relativePosition = $i - $countMods;
      my $modificationRecord = {relative_position => $relativePosition,
                                modification_type => $modificationType,
                                order_num => $countMods
      };

      push @{$peptideRecord->{modified_residues}}, $modificationRecord;
    }
    elsif(my $modificationType = $modificationToIgnoreMap->{$residuesAndMods[$i]}) {
      die "Peptide sequence cannot begin w/ a Modification:  $fullSequence" if($i ==0);

      $expectedModificationCount--;
    }
  }
  die "Found $countMods modifications but expected $expectedModificationCount" unless($countMods == $expectedModificationCount);
}

sub isPeptideModified {
  my ($self, $seq1, $seq2) = @_;

  if(length($seq1) == length($seq2)) {
    return 0;
  }

  return 1;
}



sub writeFile {
  my ($self) = @_;

  $self->setOutputFh();

  foreach my $proteinId (keys %{$self->{data}}) {
    my $gene = $self->{data}->{$proteinId}->{gene};

    $self->writeProteinHeader() if ($proteinId || $gene);
    $self->writeProtein($proteinId, $gene) if ($proteinId || $gene);

    foreach my $peptide (@{$self->{data}->{$proteinId}->{peptides}}) {

      $self->writePeptideHeader() if ($peptide->{sequence});
      $self->writePeptide($peptide) if ($peptide->{sequence});

      foreach my $mod (@{$peptide->{modified_residues}}) {

        $self->writeModificationHeader();
        $self->writeModification($mod);
      }
    }

  }

  my $fh = $self->getOutputFh();  
  close $fh;
}

sub writeProteinHeader {
  my ($self) = @_;

  my @header = ('# source_id',
                'description',
                'seqMolWt',
                'seqPI',
                'score',
                'percentCoverage',
                'sequenceCount',
                'spectrumCount',
                'sourcefile'
      );

  $self->printRow(\@header);
}

sub writePeptideHeader {
  my ($self) = @_;

  my @header = ('## start',
                'end',
                'observed',
                'mr_expect',
                'mr_calc',
                'delta',
                'miss',
                'sequence',
                'modification',
                'query',
                'hit',
                'ions_score',
                'spectrum_count'
      );

  $self->printRow(\@header);
}

sub writeModificationHeader {
  my ($self) = @_;

  my @header = ('## relative_position',
                'order',
                'description',
                'modification_type'
      );

  $self->printRow(\@header);
}


sub writeProtein {
  my ($self, $proteinId, $gene) = @_;

  my $sourceId = $gene ? $gene : $proteinId;

  my @row = ($sourceId,
             $proteinId,
             '',
             '',
             '',
             '',
             '',
             '',
             '',
             ''
      );

  $self->printRow(\@row);
}


sub writePeptide {
  my ($self, $peptide) = @_;

  my $sequence = $peptide->{sequence};
  my $spectrum = $peptide->{spectrum};
  my $ionScore = $peptide->{ion_score};

  my @row = ('',
             '',
             '',
             '',
             '',
             '',
             '',
             $sequence,
             '',
             '',
             '',
             $ionScore,
             $spectrum
      );

  $self->printRow(\@row);             
}

sub writeModification {
  my ($self, $mod) = @_;

  my $relativePosition = $mod->{relative_position};
  my $modificationType = $mod->{modification_type};
  my $orderNum = $mod->{order_num};

  my @row = ($relativePosition,
             $orderNum,
             '',
             $modificationType
      );

  $self->printRow(\@row);
}

sub printRow {
  my ($self, $array) = @_;

  my $fh = $self->getOutputFh();

  print $fh join("\t", @$array) . "\n";
}

1;



package ApiCommonData::Load::MassSpecTransform::Example;
use base qw(ApiCommonData::Load::MassSpecTransform);

# Example case where meaning of * character is different
sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  my $rv = {'*' => 'modified_L_leucine',
  };

  return $rv;
}

sub getReportedModificationSymbolMap {
  my ($self) = @_;

  my $rv = {
  };
 return $rv;
}

# Example case for asking if the line I'm on is a protein line
sub isProteinLine {
  my ($self, $lineString, $lineArray) = @_;

  # PUT Logic here specific to your data
  if(scalar @$lineArray == 10) {
    return 1;
  }

  return 0;
}

1;

package ApiCommonData::Load::MassSpecTransform::Gillin_Proteomics;
use base qw(ApiCommonData::Load::MassSpecTransform);

#Input files have the protein id and the peptides on the same line (e.g., gassAWB/Gillin_Proteomics)
# may need to override this 
sub isProteinLine {
  my ($self, $lineString, $lineArray) = @_;

  my $proteinIdIndex = $self->getProteinIdColumn();

  if($lineArray->[0]) {
    return 1;
  }
  return 0;
}

1;

package ApiCommonData::Load::MassSpecTransform::FlorensPIESPs;
use base qw(ApiCommonData::Load::MassSpecTransform);

# Protein line has 8 column, e.g., pfal3D7/Florens_PIESPs
sub isProteinLine {
  my ($self, $lineString, $lineArray) = @_;

  # PUT Logic here specific to your data
  if(scalar @$lineArray == 8) {
    return 1;
  }

  return 0;
}

1;

package ApiCommonData::Load::MassSpecTransform::Ratner_DTASelect_filter;
use base qw(ApiCommonData::Load::MassSpecTransform);

# Protein line starts with an alphanumeric character, e.g., gassAWB/Ratner_DTASelect-filter
sub isProteinLine {
  my ($self, $lineString, $lineArray) = @_;

  if($lineString=~/\[MASS=.*\]/) {
    return 1;
  }
  return 0;
}

1;



package ApiCommonData::Load::MassSpecTransform::IgnoreArtifacts;
use base qw(ApiCommonData::Load::MassSpecTransform);

sub getReportedModificationSymbolMap {
  my ($self) = @_;

  return {};
}

sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  return {'*' => 'modified_L_cysteine',
          '#' => 'modified_L_methionine',
          '%' => 'modified_L_methionine',
  };
}

1;

package ApiCommonData::Load::MassSpecTransform::ProteinLineStartsWithNonDigit;
use base qw(ApiCommonData::Load::MassSpecTransform);

# Protein line starts with an alphanumeric character, e.g., tbruTREU927/Hill_Flagellum_Surface_And_Matrix_Proteomes
sub isProteinLine {
  my ($self, $lineString, $lineArray) = @_;
  return ($lineString=~/^\D/ && !$lineString=~/\-/); 
}

1;

package ApiCommonData::Load::MassSpecTransform::ProteinLineStartsWithWordChar;
use base qw(ApiCommonData::Load::MassSpecTransform);

# Protein line starts with an alphanumeric character, e.g., tbruTREU927/Hill_Flagellum_Surface_And_Matrix_Proteomes
sub isProteinLine {
  my ($self, $lineString, $lineArray) = @_;

  if($lineString=~/^\w/) {
    return 1;
  }
  return 0;
}

1;

package ApiCommonData::Load::MassSpecTransform::ProteinLineStartsWithLetter;
use base qw(ApiCommonData::Load::MassSpecTransform);

# Protein line starts with an alphanumeric character, e.g., tbruTREU927/Hill_Flagellum_Surface_And_Matrix_Proteomes
sub isProteinLine {
  my ($self, $lineString, $lineArray) = @_;

  if($lineString=~/^[a-zA-Z]/) {
    return 1;
  }
  return 0;
}

1;

package ApiCommonData::Load::MassSpecTransform::ProteinLineStartsWithWordCharPhospo;
use base qw(ApiCommonData::Load::MassSpecTransform::ProteinLineStartsWithWordChar);

sub getReportedModificationSymbolMap {
  my ($self) = @_;

  return { '*' => 'phosphorylation_site',
  };
}

sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  return {};
}

1;

package ApiCommonData::Load::MassSpecTransform::dobbelaere;
use base qw(ApiCommonData::Load::MassSpecTransform);

# every line is the peptide line except the headLines,
# as well as the protein lines also includes the peptide line
sub isPeptideLine {
  my ($self, $lineString, $lineArray) = @_;

  if($self->isHeaderLine($lineString, $lineArray)) {
    return 0;
  }
  return 1;
}

1;




package ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLine;
use base qw(ApiCommonData::Load::MassSpecTransform);

#Input files have the protein id and the peptides on the same line (e.g., pberANKA/Kappe_Sprotozoite)
sub isPeptideLine {
  my ($self, $lineString, $lineArray) = @_;

  return $self->isProteinLine($lineString, $lineArray);

}

1;

package ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLineIgnoreArtifacts;
use base qw(ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLine);

sub getReportedModificationSymbolMap {
  my ($self) = @_;

  return {};
}

sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  return {'*' => 'modified_L_cysteine',
          '#' => 'modified_L_methionine',
          '%' => 'modified_L_methionine',
  };
}

1;

package ApiCommonData::Load::MassSpecTransform::ProteinLineWithNineColumns;
use base qw(ApiCommonData::Load::MassSpecTransform);

# Protein line has 9 column, e.g., tgonME49/Boothroyd_Bowyer_oocyst_sporozoite
 sub isProteinLine {
   my ($self, $lineString, $lineArray) = @_;
   # PUT Logic here specific to your data
   if(scalar @$lineArray == 9 ) {
    return 1;
   }
   return 0;
}

1;

package ApiCommonData::Load::MassSpecTransform::ProteinLineWithLessThanTenColumns;
use base qw(ApiCommonData::Load::MassSpecTransform);

# Protein line has 8 columns,
 sub isProteinLine {
   my ($self, $lineString, $lineArray) = @_;
   # PUT Logic here specific to your data
   if(scalar @$lineArray < 10 ) {
    return 1;
   }
   return 0;
}

1;


package ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLineUbiquitin;
use base qw(ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLine);

sub getReportedModificationSymbolMap {
  my ($self) = @_;

  return { '*' => 'binding_site',
  };
}

sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  return {};
}

1;

package ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLinePhospo;
use base qw(ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLine);

sub getReportedModificationSymbolMap {
  my ($self) = @_;

  return { '*' => 'phosphorylation_site',
  };
}

sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  return {};
}

1;

package ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLineIgnorePhospo;
use base qw(ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLine);

sub getReportedModificationSymbolMap {
  my ($self) = @_;

  return {};
}

sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  return {'*' => 'phosphorylation_site',
  };
}

1;

package ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLineAcetylation;
use base qw(ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLine);

sub getReportedModificationSymbolMap {
  my ($self) = @_;

  return { '*' => 'acetylation_site',
  };
}

sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  return {};
}

1;

package ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLineMethionine;
use base qw(ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLine);

sub getReportedModificationSymbolMap {
  my ($self) = @_;

  return { '*' => 'modified_L_methionine',
  };
}

sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  return {};
}

1;

package ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLinePromastigote;
use base qw(ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLine);

sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  return { '*' => 'modified_L_cysteine',
           '+' => 'modified_L_tryptophan',
           '#' => 'modified_L_methionine',
  };
}

sub getReportedModificationSymbolMap {
  my ($self) = @_;

  my $rv = {
  };
 return $rv;
}

1;

package ApiCommonData::Load::MassSpecTransform::EveryLineIsPeptideLine;
use base qw(ApiCommonData::Load::MassSpecTransform);

#Input files have the protein id and the peptides on the same line (e.g., pberANKA/Kappe_Sprotozoite)
sub isPeptideLine {
  my ($self, $lineString, $lineArray) = @_;

  return 1;

}

1;


package ApiCommonData::Load::MassSpecTransform::ProteinLineNotContainSpecChar;
use base qw(ApiCommonData::Load::MassSpecTransform);

# Protein line not contain a specific char, e.g. tcruCLBrener/Reservosomes_SubCellular 
sub isProteinLine {
  my ($self, $lineString, $lineArray) = @_;

  if($lineString !~ /esn\d+/) {
    return 1;
  }
  return 0;
}

1;

package ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLineMethylarginine;
use base qw(ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLine);

sub getReportedModificationSymbolMap {
  my ($self) = @_;

  return { '*' => 'monomethylarginine',
           '#' => 'dimethylarginine',
           '@' => 'asymmetric_dimethylarginine',
           '+' => 'symmetric_dimethylarginine',
  };
}

sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  return {};
}

1;

package ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLinePhospoandAcetyl;
use base qw(ApiCommonData::Load::MassSpecTransform::PeptideLineIsProteinLine);

sub getReportedModificationSymbolMap {
  my ($self) = @_;

  return { '*' => 'phosphorylation_site',
	   '^' => 'acetylation_site',
  };
}

sub getIgnoredModificationSymbolMap {
  my ($self) = @_;

  return {};
}

1;


package ApiCommonData::Load::MassSpecTransform::PeptideLineAndProteinLineStartWithSpecCharBS;
use base qw(ApiCommonData::Load::MassSpecTransform);

# a package to parse a file, protineLine starts with B when peptide line starts with S
# e.g. PiroplasmaDB/bmicRI/massSpec/Whole_Blood_Prot

sub isProteinLine {
  my ($self, $lineString, $lineArray) = @_;

  if($lineString =~ /^B/) {
    return 1;
  }
  return 0;
}

sub isPeptideLine {
  my ($self, $lineString, $lineArray) = @_;

  if($lineString =~ /^S/) {
    return 1;
  }
  return 0;
}


1;

package ApiCommonData::Load::MassSpecTransform::PeptideLineAndProteinLineStartWithSpecCharSqtFromPride;
use base qw(ApiCommonData::Load::MassSpecTransform);

# a package to parse a sqt file from pride
# the protein line starts with L
# the peptide line starts with M
# in the prop.config file skipLines=0, headerRegex=^H
# e.g. tgonME49/massSpec/Extracellular_Vesicles

sub isProteinLine {
  my ($self, $lineString, $lineArray) = @_;

  if($lineString =~ /^L/) {
    return 1;
  }
  return 0;
}

sub isPeptideLine {
  my ($self, $lineString, $lineArray) = @_;

  if($lineString =~ /^M/) {
    return 1;
  }
  return 0;
}

sub readFile {
  my ($self) = @_;

  my $file = $self->getInputFile();
  my $delimiter = $self->getDelimiter();

  open(FILE, $file) or die "Cannot open file $file for reading: $!";

  my $currentPeptideLine;
  my $peptideCount = 0;

  my $printOnly = $self->hasMissingRequiredColumnInfo();
  unless(defined $self->getPeptideSpectrumColumn()) {
    print STDERR "SEVERE WARNING:  YOU DIDN'T PROVIDE A SPECTRUM COUNT COLUMN FOR PEPTIDES!!  FIX AND RERUN IF YOUR INPUT FILE CONTAINS THIS INFORMATION\n";
  }

  while (my $line = <FILE>) {
    chomp($line);
    next unless ($line); ## skip empty lines

    if ($line =~ /^H/) { ## skip header lines
      print STDERR "Skipping header line: $line\n" if ($self->debug());
      next
    }

    my @a = split($delimiter, $line);

    foreach my $i (0..$#a) {
      $a[$i] =~ s/^\s+//g;
      $a[$i] =~ s/\s+$//g;
    }

    if ($printOnly) {
      $self->printXmlConfig();
    }

    if ($line =~ /^S/) {
      ## spectrum match line
    } elsif ($line =~ /^M/) {  ## peptide line
      $currentPeptideLine = $line;
      $currentPeptideLine =~ s/\(.+\)//;  ## remove the value within () and ()
      $peptideCount++;
    } elsif ($line =~ /^L/) {  ## protein ID line
      my $currentProteinId = $a[$self->getProteinIdColumn()];
      $currentProteinId  =~ s/^Reverse_//;  ## remove the Reverse_ at the begin of proteinId

      my $geneId;
      if (defined $self->getGeneSourceIdColumn()) {
	$geneId = $a[$self->getGeneSourceIdColumn()];
      }
      $geneId =~ s/^Reverse_//; ## remove the Reverse_ at the begin of geneId

      $self->{data}->{$currentProteinId}->{gene} = $geneId;

      my @pepA = split($delimiter, $currentPeptideLine);
      $self->addPeptide($currentProteinId, \@pepA);

      last if ($self->debug && $peptideCount == 2);

    } else {
      print STDERR "Found unusual line: \n$line\n";
    }
  }
  close FILE;
}

1;
