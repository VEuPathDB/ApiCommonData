package ApiCommonData::Load::MBioResultsTable;

use strict;
use warnings;

use List::Util qw/sum uniq/;


sub dataTypeInfo {
  my ($class, $constructorName, $oDti) = @_;
  no strict "refs";
  my $dti = ${"${class}::dataTypeInfo"} // {};
  return { %{$dti->{$constructorName} // {}} , %{$oDti // {}}};
}

sub ampliconTaxa {
  my ($class, $inputPath) = @_;
  return construct($class, dataTypeInfo($class, 'ampliconTaxa'), $inputPath, sub {
    my ($samples, $rowSampleHashPairs) = @_;
    my @rows;
    my %data;
    my %sampleDetails;
    my %rowDetails;
    P:
    for my $p (@{$rowSampleHashPairs}){
      my $row = $p->[0];
      push @rows, $row;
      $rowDetails{$row} = detailsFromRowNameTaxa($row);
      SAMPLE:
      for my $sample (@$samples){
        my $value = $p->[1]{$sample};
        next SAMPLE unless $value;
        $data{$sample}{$row} = $value;
        $sampleDetails{$sample}{totalCount}+=$value;
      }
    }
    return \@rows, \%data, \%sampleDetails, \%rowDetails;
  });
}

sub wgsTaxa {
  my ($class, $inputPath) = @_;
  return construct($class, dataTypeInfo($class, 'wgsTaxa'), $inputPath, sub {
    my ($samples, $rowSampleHashPairs) = @_;
    my @rows;
    my %data;
    my %sampleDetails;
    my %rowDetails;
    P:
    for my $p (@{$rowSampleHashPairs}){
      my $row = maybeGoodMetaphlanRow($p->[0]);
      next P unless $row;
      push @rows, $row;
      $rowDetails{$row} = detailsFromRowNameTaxa($row);
      SAMPLE:
      for my $sample (@$samples){
        my $value = $p->[1]{$sample};
        next SAMPLE unless $value;
        $data{$sample}{$row} = $value if $value;
        $sampleDetails{$sample}{totalCount}+=$value;
      }
    }
    return \@rows, \%data, \%sampleDetails, \%rowDetails;
  });
}

sub wgsFunctions {
  my ($class, $unitType, $inputPath) = @_;
  return construct($class, dataTypeInfo($class, 'wgsFunctions', {unitType => $unitType}), $inputPath, sub {
    my ($samples, $rowSampleHashPairs) = @_;
    my %rows;
    my %data;
    my %rowDetails;
    P:
    for my $p (@{$rowSampleHashPairs}){
      my $row = $p->[0];
      next P if $row =~ m{UNMAPPED|UNGROUPED|UNINTEGRATED};
      $rowDetails{$row} = detailsFromRowNameHumannFormat($row);
      $rows{$row}++;
      for my $sample (@$samples){
        my $value = $p->[1]{$sample};
        $data{$sample}{$row} = $value if $value;
      }
    }
    my @rows = sort keys %rows;
    return \@rows, \%data, {}, \%rowDetails;
  });
}

sub wgsPathways {
  my ($class, $inputPathAbundances, $inputPathCoverages) = @_;
  my $dataTypeInfo = dataTypeInfo($class, 'wgsPathways');

  my ($samplesAs, $rowHashSamplePairsAs) = parseSamplesTsv($inputPathAbundances);
  my ($samplesCs, $rowHashSamplePairsCs) = parseSamplesTsv($inputPathCoverages);
  my @samples = uniq @{$samplesAs}, @{$samplesCs};

  if (@$samplesAs < @samples || @$samplesCs < @samples){
    die "Inconsistent sample names across pathways and coverages: $inputPathAbundances, $inputPathCoverages";
  }

  my %rowsA;
  my %data;

  P:
  for my $p (@{$rowHashSamplePairsAs}) {
    my ($row, $h) = @$p;

    next P if $row =~ m{UNMAPPED|UNGROUPED|UNINTEGRATED};

    $rowsA{$row}++;
    for my $sample (@samples){
      $data{$sample}{$row} = $h->{$sample};
    } 
  }
  my $numRowsC;

  P:
  for my $p (@{$rowHashSamplePairsCs}) {
    my ($row, $h) = @{$p};
    next P if $row =~ m{UNMAPPED|UNGROUPED|UNINTEGRATED};

    die "Inconsistent rows between abundance and coverage files: row $row in the coverage file missing from the abundance file"
      unless defined $rowsA{$row};
    $numRowsC++;

    for my $sample (@samples){

      die "Inconsistent samples between abundance and coverage files: row $row, sample $sample in the coverage file missing from the abundance file"
         unless defined $data{$sample}{$row};

      $data{$sample}{$row} = [ $data{$sample}{$row}, $h->{$sample}];
    } 
  }
 
  my @rows = sort keys %rowsA;
  die sprintf("Coverage file had %s more rows than the abundance file?", $numRowsC - @rows)
    unless @rows == $numRowsC;

  my %rowDetails;
  for my $row (@rows){
    $rowDetails{$row} = detailsFromRowNameHumannFormat($row);
  }

  return new($class, $dataTypeInfo, \@samples, \@rows, \%data, {}, \%rowDetails);
}

sub construct {
  my ($class, $dataTypeInfo, $inputPath, $prepare) = @_;

  my ($samples, $rowSampleHashPairs) = parseSamplesTsv($inputPath);

  return new($class, $dataTypeInfo, $samples, $prepare->($samples, $rowSampleHashPairs)); 
}

sub new {
  my ($class, $dataTypeInfo, $samples, $rows, $data, $sampleDetails, $rowDetails) = @_;
  return bless {
    %{$dataTypeInfo},
    samples => $samples,
    sampleDetails => $sampleDetails,
    rows => $rows,
    rowDetails => $rowDetails,
    data => $data,
  }, $class;
}

sub addSampleDetails {
  my ($self, $sampleDetails) = @_;
  $self->{sampleDetails} = $sampleDetails;
}

sub value {
  my ($self, $sample, $row) = @_;
  return $self->{data}{$sample}{$row};
}

sub attributesForSample {
  my ($self, $sample) = @_;
  return $self->{data}{$sample};
}

sub parseSamplesTsv {
  my ($inputPath) = @_; 
  
  open (my $fh, "<", $inputPath) or die "$!: $inputPath";
 
  my $header = <$fh>;
  die "No header in $inputPath" unless $header;
  chomp $header;
  my ($__, @samples) = split "\t", $header;
  die "No samples in $inputPath" unless @samples;
  my @rowSampleHashPairs;
  while(my $line = <$fh>){
    chomp $line;
    my ($row, @counts) = split("\t", $line, -1);;
    die "Bad dimensions: $inputPath" unless $#counts == $#samples;
    my %h = map {
      $samples[$_] => $counts[$_]
    } 0..$#counts;
    push @rowSampleHashPairs, [$row, \%h];
  }
  die "No data rows in $inputPath" unless @rowSampleHashPairs;
  return \@samples, \@rowSampleHashPairs;
}

# Not needed for GUS loading
sub detailsFromRowNameTaxa {
  my ($row) = @_;
  (my $description = $row) =~ s{.*;}{};
  my $name = $row;
  if (length $name > 255){
    my ($x, $y) = split(";", $name, 2);
    $name = $x .";...".substr($y, length $y - (255 - length $x - 4), length $y);
  }
  return {name => $name, description => $description};
}

# Expect output in HUMAnN format
# ANAEROFRUCAT-PWY: homolactic fermentation
# ARGDEG-PWY: superpathway of L-arginine, putrescine, and 4-aminobutanoate degradation|g__Escherichia.s__Escherichia_coli
# 1.1.1.103: L-threonine 3-dehydrogenase|g__Escherichia.s__Escherichia_coli
# 1.1.1.103: L-threonine 3-dehydrogenase|unclassified
# 7.2.1.1: NO_NAME

sub detailsFromRowNameHumannFormat {
  my ($row) = @_;

  (my $name = $row) =~ s{:.*}{};

  my $description;
  $row =~ m{^.*?:\s*([^\|]+)};
  $description = $1 if $1 and $1 ne "NO_NAME";
  
  
  my ($__, $lineage) = split("\|", $row);

  my $species;
  if($row =~ m{\|}){
    $species = $row;
    $species =~ s{^.*\|}{};
    $species =~ s{^.*s__}{};
    $species = unmessBiobakerySpecies($species);
  }

  return {name => $name, description => $description, species => $species};
}

# Expect output in metaphlan format
# Skip all taxa not at species level - they are summary values
sub prepareWgsTaxa {
  my ($dataPairs) = @_;

  my @rows;
  my @dataPairsResult;
  for my $p (@{$dataPairs}) {
    my ($row, $h) = @$p;
    $row = maybeGoodMetaphlanRow($row);
    next unless $row;
    push @rows, $row;
    push @dataPairsResult, [$row, $h];
  }
  return \@rows, \@dataPairsResult;
}

# Biobakery tools use mangled species names, with space, dash, and a few others changed to underscore
# Try make them good enough again
sub unmessBiobakerySpecies {
  my ($species) = @_;
# Species with IDs
  $species =~ s{_sp_}{ sp. };

# genus, maybe a different genus in []
  $species =~ s{^(\[?[A-Z][a-z]+\]?)_}{$1 };

# last word, like "Ruminococcus gnavus group"
  $species =~ s{_([a-z]+)$}{ $1};

  $species =~ s{oral_taxon_(\d+)$}{oral taxon $1};
  return $species;
}

sub maybeGoodMetaphlanRow {
  my ($row) = @_;
  return if $row eq 'UNKNOWN';
  return unless $row =~ m{k__(.*)\|p__(.*)\|c__(.*)\|o__(.*)\|f__(.*)\|g__(.*)\|s__(.*)};
  return join(";", $1, $2, $3, $4, $5, $6, unmessBiobakerySpecies($7));
}

1;
