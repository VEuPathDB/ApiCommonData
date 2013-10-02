package ApiCommonData::Load::MassSpecTransform;

use strict;

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

  unless(defined $self->getProteinIdColumn() && defined $self->getPeptideSequenceColumn() &&
         defined $self->getGeneSourceIdColumn() && defined $self->getPeptideSpectrumColumn() &&
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

# return a hashmap which mpas symbols to sequence_ontology_terms for residue modifications;  May need to modify or override in a subclass??
sub getModificationSymbolMap {
  my ($self) = @_;

  my $rv = {'*' => 'modified_L_methionine',
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

  my ($proteinCount, $currentProteinId, %seenPeptides, %seenProteins);

  my $printOnly = $self->hasMissingRequiredColumnInfo();

  while(my $line = <FILE>) {
    chomp($line);
    next unless($line);

    my @a = split($delimiter, $line);

    if($self->isHeaderLine($line, \@a)) {

      if($self->hasMissingColumnInfo()) {
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

    unless(defined $self->getPeptideSpectrumColumn()) {
      print "SEVERE WARNING:  YOU DIDN'T PROVIDE A SPECTRUM COUNT COLUMN FOR PEPTIDES!!  FIX AND RERUN IF YOUR INPUT FILE CONTAINS THIS INFORMATION\n";
    }


    if($self->isProteinLine($line, \@a)) {
      print STDERR "Found Protein line: $line\n" if($self->debug());
      $currentProteinId = $a[$self->getProteinIdColumn()];

      my $geneId;
      if(defined $self->getGeneSourceIdColumn()) {
        $geneId = $a[$self->getGeneSourceIdColumn()];
      }

      $self->{data}->{$currentProteinId}->{gene} = $geneId;
      if($seenProteins{$currentProteinId}) {
        die "Seen protein_id twice:  $currentProteinId";
      }

      %seenPeptides = ();

      $proteinCount++
    }

    if($self->isPeptideLine($line, \@a)) {
      print STDERR "Found Peptide line: $line\n" if($self->debug());
      $self->addPeptide($currentProteinId, \@a, \%seenPeptides);
    }

    last if($self->debug && $proteinCount == 2);
  }

  close FILE;
}


sub addPeptide {
  my ($self, $proteinId, $fields, $seenPeptides) = @_;

  my $peptideSequence = $fields->[$self->getPeptideSequenceColumn()];

  my $peptideSpectrum = 1; # default
  if(defined $self->getPeptideSpectrumColumn()) {
    $peptideSpectrum = $fields->[$self->getPeptideSpectrumColumn()];
  }

  my $peptideIonScore;
  if(defined $self->getPeptideIonScoreColumn()) {
    $peptideIonScore = $fields->[$self->getPeptideIonScoreColumn()];
  }

  my $cleanedPeptideSequence = $peptideSequence;

  if($peptideSequence =~ qr/$self->getPeptideRegex()/) {
    $cleanedPeptideSequence = $1;
  }

  my $trimmedPeptideSequence = $self->removeModifications($cleanedPeptideSequence);

  if($seenPeptides->{$cleanedPeptideSequence}) {
    print STDERR "WARN:  Same Peptide seen twice:  $cleanedPeptideSequence" if($self->debug());

    my $peptideRecord = $self->findPeptideRecord($cleanedPeptideSequence, $proteinId);
    $peptideRecord->{spectrum} = $peptideRecord->{spectrum} + $peptideSpectrum;

    $seenPeptides->{$cleanedPeptideSequence} = 1;
    return;
  }

  $seenPeptides->{$cleanedPeptideSequence} = 1;

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
  die "Could not find existing peptide record for: $cleanedPeptideSequence";
}

sub removeModifications {
  my ($self, $peptideSequence) = @_;

  my $modificationMap = $self->getModificationSymbolMap();

  my @a;
  foreach(split("", $peptideSequence)) {
    push @a, $_ unless($modificationMap->{$_});
  }

  return join("", @a);
}

sub addModifications {
  my ($self, $peptideRecord, $fullSequence) = @_;

  my $modificationMap = $self->getModificationSymbolMap();

  my @trimmedResidues = split("", $peptideRecord->{sequence});
  my @residuesAndMods = split("", $fullSequence);

  my $expectedModificationCount = scalar(@residuesAndMods) - scalar(@trimmedResidues);

  my $countMods = 0;

  for(my $i = 0; $i < scalar @residuesAndMods; $i++) {
    my $rm = $residuesAndMods[$i];
    my $tr = $trimmedResidues[$i];

    if(my $modificationType = $modificationMap->{$residuesAndMods[$i]}) {
      die "Peptide sequence cannot begin w/ a Modification:  $fullSequence" if($i ==0);

      $countMods++;

      my $relativePosition = $i - $countMods;
      my $modificationRecord = {relative_position => $relativePosition,
                                modification_type => $modificationType,
                                order_num => $countMods
      };

      push @{$peptideRecord->{modified_residues}}, $modificationRecord;
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


# TODO:
#  writeFile
#  writeProtein
#  writePeptide
#  writeModification
1;
