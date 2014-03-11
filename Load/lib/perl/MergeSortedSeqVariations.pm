package ApiCommonData::Load::MergeSortedSeqVariations;
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

sub getSequenceIndex { return 0 }
sub getLocationIndex { return 1 }
sub getStrainIndex { return 2 }

# @OVERRIDE
sub wantFirstLine {
  my ($self) = @_;

  my $sequenceIndex = $self->getSequenceIndex();
  my $locationIndex = $self->getLocationIndex();;

  my @a = @{$self->getFirstLineAsArray()};
  my @b = @{$self->getSecondLineAsArray()};

  return $a[$sequenceIndex] lt $b[$sequenceIndex] || ($a[$sequenceIndex] eq $b[$sequenceIndex] && $a[$locationIndex] <= $b[$locationIndex])
}

# @OVERRIDE
sub skipLine {
  my ($self, $line, $lineAsArray, $fh) = @_;

  return 1 unless($line);
  return 0 if($self->readingFile1Fh($fh));

  my $strainIndex = $self->getStrainIndex();

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

  my @rv;

  my $sequenceIndex = $self->getSequenceIndex();
  my $locationIndex = $self->getLocationIndex();

  my $isSameGroup = 1;

  while($isSameGroup) {
    last unless($self->hasNext());

    my @a = $self->nextLine();
    my @b = $self->getPeek();

    my $sequenceId = $a[$sequenceIndex];
    my $peekSequenceId = $b[$sequenceIndex];

    my $location = $a[$locationIndex];
    my $peekLocation = $b[$locationIndex];

    unless($sequenceId eq $peekSequenceId && $peekLocation == $location) {
      $isSameGroup = 0;
    }

    my $variation = $self->variation(\@a);

    push @rv, $variation;
  }
  return \@rv;
}


sub variation {
  my ($self, $lineAsArray) = @_;

  my ($sequenceId, $location, $strain, $base, $coverage, $percent, $quality, $pvalue, $externalDatabaseReleaseId, $matchesReference, $product, $positionInCds, $positionInProtein, $naSequenceId, $refNaSequenceId, $snpExternalDatabaseReleaseId) = @$lineAsArray;

  my $rv = {'sequence_source_id' => $sequenceId,
            'location' => $location,
            'strain' => $strain,
            'base' => $base,
            'coverage' => $coverage,
            'percent' => $percent,
            'quality' => $quality,
            'pvalue' => $pvalue,
            'external_database_release_id' => $externalDatabaseReleaseId,
            'matches_reference' => $matchesReference,
            'product' => $product,
            'position_in_cds' => $positionInCds,
            'position_in_protein' => $positionInProtein,
            'na_sequence_id' => $naSequenceId,
            'ref_na_sequence_id' => $refNaSequenceId,
            'snp_external_database_release_id' => $snpExternalDatabaseReleaseId,
  };
  return $rv;
}


1;
