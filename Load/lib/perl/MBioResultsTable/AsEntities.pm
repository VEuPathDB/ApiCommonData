package ApiCommonData::Load::MBioResultsTable::AsEntities;
use strict;
use warnings;

use base qw/ApiCommonData::Load::MBioResultsTable/;
use List::Util qw/sum/;

# needs to make a column for a wide table
my $MAX_PROPERTY_NAME_LENGTH = 110;

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
      die "Go get an ontology term for this unit: $unitType" unless $unitType =~ /4.*ec.*/i;
      return entitiesForSampleFunctions($self->{data}{$sample}, $self->{rowDetails}, "4th level ec metagenome abundance data", undef, undef, undef); 
    },
  },
  wgsPathways => {
    entitiesForSample => sub {
      my ($self, $sample) = @_;
      return entitiesForSampleFunctions($self->{data}{$sample}, $self->{rowDetails},"metagenome enzyme pathway abundance data", undef, "metagenome enzyme pathway coverage data", undef);
    }
  },
  eukdetectCpms => {
    entitiesForSample => sub {
      my ($self, $sample) = @_;
      return entitiesForSampleGroupedAbundancesEukCpms($self->{data}{$sample});
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
    %{entitiesForSampleRelativeAbundances($data)}
  };
}

sub entitiesForSampleFunctions {
  my ($data, $rowDetails, $summaryAbundanceName, $detailedAbundanceName, $summaryCoverageName, $detailedCoverageName) = @_;
  my %result;
  for my $row (keys %{$data}){
    my $key = $rowDetails->{$row}{name};
    my $displayName = $rowDetails->{$row}{description} ? join(": ", $key, $rowDetails->{$row}{description}) : $key;
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
    $key =~ s{[^A-Za-z_0-9]+}{_}g;
    if(length $key > $MAX_PROPERTY_NAME_LENGTH) {
      die "Key unexpectedly long: $key";
    }
    if($abundance){
      my $n = $species ? $detailedAbundanceName : $summaryAbundanceName;
      $result{$n}{$key} = [$displayName, $abundance] if $n;
    }
    if($coverage){
      my $n = $species ? $detailedCoverageName : $summaryCoverageName;
      $result{$n}{$key} = [$displayName, $coverage] if $n;
    }
  }
  return \%result;
}
my $levelNamesTxt = <<EOF;
kingdom
phylum
class
order
family
genus
species
EOF
my $levelNames = [grep {$_} split("\n", $levelNamesTxt)];


sub abundanceKeyAndDisplayName {
  my ($key, $maxLength) = @_;
  my $displayName;
  if($key =~m{;$}){
    $displayName = $key;
    $displayName =~ s{;*$}{};
    $displayName =~ s{.*;}{};
    $displayName = "unclassified $displayName";
  } else {
    ($displayName = $key) =~ s{.*;}{};
  }
  if ((length $key) > $maxLength){
    my ($x, $y) = split(";", $key, 2);
    die $key if not $y;
    $key = $x .";...".substr($y, (length $y) - ($maxLength - 4), length $y);
  }
  $key =~ s{[^A-Za-z_0-9]+}{_}g;

  return $key, $displayName;
}

sub entitiesForSampleRelativeAbundances {
  my ($data) = @_;
  my @rows = keys %{$data};
  my @abundances = values %{$data};
  my $normalizingFactor= sum values %{$data};
  my %result;

  for my $taxonLevel ((0..$#$levelNames)){
    my $maxKeyLength = $MAX_PROPERTY_NAME_LENGTH - length($levelNames->[$taxonLevel]) - 1;
    my %groups;
    for my $i (0..$#rows){
      my @ls = split ";", $rows[$i];
      my $l = join ";", map {$_ // ""} @ls[0..$taxonLevel];
      push @{$groups{$l}}, $abundances[$i];
    }
    while(my ($groupKey, $as) = each %groups){
      my $value = sprintf("%.6f", (sum @{$as} ) / $normalizingFactor);
      my ($key, $displayName) = abundanceKeyAndDisplayName($groupKey, $maxKeyLength);
      $result{$levelNames->[$taxonLevel]}{$key} = [$displayName, $value];
    }
  }
  return \%result;
}

sub parentTermForEuks {
  my ($kingdom) = @_;
  return $kingdom eq "Viridiplantae" ? 'plant taxon detected by sequence match'
    : $kingdom eq "Metazoa" ? 'animal taxon detected by sequence match'
    : $kingdom eq "Fungi" ? 'fungal taxon detected by sequence match'
    : "protist taxon detected by sequence match"; 
}

sub entitiesForSampleGroupedAbundancesEukCpms {
  my ($data) = @_;
  my @rows = keys %{$data};
  my @abundances = values %{$data};
  my %result;
  for my $i (0..$#rows){
    my ($x1, $x2) = split(";", $rows[$i], 2);
    my $parent = parentTermForEuks($x1);
    my $maxKeyLength = $MAX_PROPERTY_NAME_LENGTH - length($parent) - 1;
    my ($key, $displayName) = abundanceKeyAndDisplayName($x2, $maxKeyLength);
    my $value = $abundances[$i];
    $result{$parent}{$key} = [$displayName, "Y"];
    $result{"normalized number of taxon-specific sequence matches"}{$key} = [$displayName, $value];
  }
  return \%result;
}
1;
