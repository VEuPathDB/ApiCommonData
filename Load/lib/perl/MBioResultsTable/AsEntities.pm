package ApiCommonData::Load::MBioResultsTable::AsEntities;
use strict;
use warnings;

use base qw/ApiCommonData::Load::MBioResultsTable/;
use List::Util qw/sum/;

$ApiCommonData::Load::MBioResultsTable::AsEntities::dataTypeInfo = {
  ampliconTaxa => {
    entitiesForSample => sub {
      my ($self, $sample) = @_;
      return entitiesForSampleTaxa($self->{data}{$sample});
    }
  },
  wgsTaxa => {
    entitiesForSample => sub {
      my ($self, $sample) = @_;
      return entitiesForSampleTaxa($self->{data}{$sample});
    }
  },
  wgsFunctions => {
    entitiesForSample => sub {
      my ($self, $sample) = @_;
      my $unitType = $self->{unitType};
      return entitiesForSampleFunctions($self->{data}{$sample}, $self->{rowDetails}, "function_${unitType}", "function_${unitType}_species", undef, undef); 
    },
  },
  wgsPathways => {
    entitiesForSample => sub {
      my ($self, $sample) = @_;
      return entitiesForSampleFunctions($self->{data}{$sample}, $self->{rowDetails},"pathway_abundance", "pathway_abundance_species", "pathway_coverage", "pathway_coverage_species");
    }
  },
  eukdetectCpms => {
    entitiesForSample => sub {
      my ($self, $sample) = @_;
      return entitiesForSampleAbundanceCpms($self->{data}{$sample});
    }
  }
};

sub entitiesForSample {
  my ($self, $sample) = @_;
  return $self->{entitiesForSample}->($self, $sample);
}
sub entitiesForSampleTaxa {
  my ($data) = @_;
  my @values = values %${data};
  return {} unless @values;
  return {
    %{entitiesForSampleRelativeAbundances($data)},
    alpha_diversity_shannon => alphaDiversityShannon(\@values),
    alpha_diversity_inverse_simpson => alphaDiversityInverseSimpson(\@values),
  };
}

sub entitiesForSampleFunctions {
  my ($data, $rowDetails, $summaryAbundanceName, $detailedAbundanceName, $summaryCoverageName, $detailedCoverageName) = @_;
  my %result;
  for my $row (keys %{$data}){
    my $key = $rowDetails->{$row}{name};
    my $displayName = $rowDetails->{$row}{description} // $key;
    my $species = $rowDetails->{$row}{species};
    my ($abundance, $coverage);
    my $x = $data->{$row};
    if( ref $x eq 'ARRAY'){
      $abundance = sprintf("%.6f",$x->[0]);
      $coverage = $x->[1];
    } else {
      $abundance = sprintf("%.6f", $x);
    }
    if($species){
      $key .= ", $species";
      $displayName .= ", $species";
    }
    $key =~ s{[^A-Za-z_.0-9]+}{_}g;
    if(length $key > 255) {
      die "Key unexpectedly long: $key";
    }
    if($abundance){
      my $n = $species ? $detailedAbundanceName : $summaryAbundanceName;
      $result{$n}{$key} = [$displayName, $abundance];
    }
    if($coverage && $summaryCoverageName && $detailedCoverageName){
      my $n = $species ? $detailedCoverageName : $summaryCoverageName;
      $result{$n}{$key} = [$displayName, $coverage];
    }
  }
  return \%result;
}

sub entitiesForSampleAbundanceCpms {
  my ($data) = @_;
  my $levelNames = [map {"abundance_cpms_${_}"} qw/k p c o f g s/];
  return entitiesForSampleAggregatedAbundance($data, $levelNames, 1);
}

sub entitiesForSampleRelativeAbundances {
  my ($data) = @_;
  my $levelNames = [map {"relative_abundance_${_}"} qw/k p c o f g s/];
  my $totalCount = sum values %{$data};
  return entitiesForSampleAggregatedAbundance($data, $levelNames, $totalCount);
}

sub entitiesForSampleAggregatedAbundance {
  my ($data, $levelNames, $normalizingFactor) = @_;
  my @rows = keys %{$data};
  my @abundances = values %{$data};
  my %result;

  for my $taxonLevel ((0..$#$levelNames)){
    my %groups;
    for my $i (0..$#rows){
      my @ls = split ";", $rows[$i];
      my $l = join ";", map {$_ // ""} @ls[0..$taxonLevel];
      push @{$groups{$l}}, $abundances[$i];
    }
    while(my ($key, $as) = each %groups){
      my $value = sprintf("%.6f", (sum @{$as} ) / $normalizingFactor);
      my $displayName;
      if($key =~m{;$}){
        $displayName = $key;
        $displayName =~ s{;*$}{};
        $displayName =~ s{.*;}{};
        $displayName = "unclassified $displayName";
      } else {
        ($displayName = $key) =~ s{.*;}{};
      }
      if ((length $key) + (length $levelNames->[$taxonLevel]) + 1 > 255){
        my ($x, $y) = split(";", $key, 2);
        $key = $x .";...".substr($y, (length $y) - (255 - 1 - (length $levelNames->[$taxonLevel]) - (length $x) - 4), length $y);
      }
      $key =~ s{[^A-Za-z_.0-9]+}{_}g;
      $result{$levelNames->[$taxonLevel]}{$key} = [$displayName, $value];
    }
  }
  return \%result;
}
sub alphaDiversityShannon {
  my ($values) = @_;
  my $totalCount = sum @{$values};
  return unless $totalCount;

  my $result = 0;
  for my $value (@{$values}){
    my $p = $value / $totalCount;
    $result += $p * log($p);
  }
  return -$result;
}

sub alphaDiversityInverseSimpson {
  my ($values) = @_;
  my $totalCount = sum @{$values};
  return unless $totalCount;

  my $result = 0;
  for my $value (@{$values}){
    my $p = $value / $totalCount;
    $result += $p * $p;
  }
  return 1 / $result;
}
1;
