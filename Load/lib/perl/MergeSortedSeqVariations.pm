package ApiCommonData::Load::MergeSortedSeqVariations;
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
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
use base qw(ApiCommonData::Load::MergeSortedFiles);

=pod

=head2 ApiCommonData::Load::MergeSortedFiles

=over 4

=item Description

Merge seq var files.  Can ask for the nextLine Or the nextSNP (array of  variations at a given location);  Filters array is a list of strains.  Any row in $file2 (BIG CACHE) for one of the filter strains will be skipped;  

=item Usage

my $reader = ApiCommonData::Load::MergeSortedSeqVariations->new($file, $file2, $filters, $delimiter);

while($reader->hasNext()) {
    my $line = $reader->nextLine() ; 
    my $peek = $reader->nextPeek() ; 

    # OR if you'd like these as lists; (line split on delimiter)
    #    my @lineArray = $reader->nextLine();
    #    my @peek = $reader->getPeek();

    # OR if you want an array of variations for each location
    # my $variations = $reader->nextSNP() ; 
    ...
}

=back

=cut

use strict;
use locale;  # Use this because the input files have been sorted by unix sort (otherwise perl's default string comparison will give weird results

use ApiCommonData::Load::SnpUtils  qw(sequenceIndex locationIndex strainIndex variationFileColumnNames isSameSNP);

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  my $columnNames = &variationFileColumnNames();
  $self->setDictionaryNames($columnNames);

  return $self;
}


# @OVERRIDE
sub wantFirstLine {
  my ($self) = @_;

  my $sequenceIndex = &sequenceIndex();
  my $locationIndex = &locationIndex();;

  my @a = @{$self->getFirstLineAsArray()};
  my @b = @{$self->getSecondLineAsArray()};

#  print STDERR "A:  $a[$sequenceIndex]\t$a[$locationIndex]\n";
 # print STDERR "B:  $b[$sequenceIndex]\t$b[$locationIndex]\n";

  return $a[$sequenceIndex] lt $b[$sequenceIndex] || ($a[$sequenceIndex] eq $b[$sequenceIndex] && $a[$locationIndex] <= $b[$locationIndex]);
}

# @OVERRIDE
sub skipLine {
  my ($self, $line, $lineAsArray, $fh) = @_;

  return 1 unless($line);
  return 0 if($self->readingFile1Fh($fh));

  my $strainIndex = &strainIndex();

  my $filters = $self->getFilters();


  foreach(@$filters) {
    if($lineAsArray->[$strainIndex] eq $_) {
      return 1;
    }
  }
  return 0;
}


sub nextSNP {
  my ($self) = @_;

  $self->readNextGroupOfLines();
}

# @OVERRIDE
sub isSameGroup {
  my ($self, $a, $b) = @_;

  return &isSameSNP($a, $b);
}



1;
