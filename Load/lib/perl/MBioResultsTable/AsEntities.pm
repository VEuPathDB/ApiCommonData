package ApiCommonData::Load::MBioResultsTable::AsEntities;
use strict;
use warnings;

use base qw/ApiCommonData::Load::MBioResultsTable/;
use List::Util qw/sum/;

use Digest::SHA1 qw(sha1_hex);

# needs to make a column for a wide table
my $MAX_PROPERTY_NAME_LENGTH = 110;

$ApiCommonData::Load::MBioResultsTable::AsEntities::dataTypeInfo = {
  ampliconTaxa => {
    entitiesForSample => sub {
      my ($self, $sample) = @_;
      return entitiesForSampleTaxa($self->{data}{$sample}, $self->{isRelativeAbundance});
    }
  },
  wgsTaxa => {
    entitiesForSample => sub {
      my ($self, $sample) = @_;
      return entitiesForSampleTaxa($self->{data}{$sample}, 1);
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
  },
  massSpec => {
    entitiesForSample => sub {
      my ($self, $sample) = @_;
      return entitiesForSampleFunctions($self->{data}{$sample}, $self->{rowDetails}, "mass spectrometry assay", undef, undef, undef); 
    }
  },
};

sub entitiesForSample {
  my ($self, $sample) = @_;
  return $self->{entitiesForSample}->($self, $sample);
}
sub entitiesForSampleTaxa {
  my ($data, $isRelativeAbundance) = @_;
  my @values = values %${data};
  return {} unless @values;
  return {
    %{entitiesForSampleAbundances($data, $isRelativeAbundance)}
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

my $levelNamesRelative = [qw/
eupath_0009251
eupath_0009252
eupath_0009253
eupath_0009254
eupath_0009255
eupath_0009256
eupath_0009257/];

my $levelNamesAbsolute = [qw/
eupath_0009351
eupath_0009352
eupath_0009353
eupath_0009354
eupath_0009355
eupath_0009356
eupath_0009357/];


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

    if(not $y) {
      $key = substr(sha1_hex($x), 0, 16);
    }
    else {
    # short source_id
    $key = $x . "_" . substr(sha1_hex($y), 0, 16);
    }
  }
  $key =~ s{[^A-Za-z_0-9]+}{_}g;

  return $key, $displayName;
}

sub entitiesForSampleAbundances {
  my ($data, $isRelativeAbundance) = @_;
  my @rows = keys %{$data};
  my @abundances = values %{$data};
  my $normalizingFactor= sum values %{$data};
  my %result;

  for my $taxonLevel ((0..$#$levelNamesRelative)){
    my $maxKeyLength = $MAX_PROPERTY_NAME_LENGTH - length($levelNamesRelative->[$taxonLevel]) - 1;
    my %groups;
    for my $i (0..$#rows){
      my @ls = split ";", $rows[$i];
      my $l = join ";", map {$_ // ""} @ls[0..$taxonLevel];
      push @{$groups{$l}}, $abundances[$i];
    }
    while(my ($groupKey, $as) = each %groups){
      my ($key, $displayName) = abundanceKeyAndDisplayName($groupKey, $maxKeyLength);
      if($isRelativeAbundance){
        my $relvalue = sprintf("%.6f", (sum @{$as} ) / $normalizingFactor);
        $result{$levelNamesRelative->[$taxonLevel]}{$key} = [$displayName, $relvalue];
      }
      else {
        my $relvalue = sprintf("%.6f", (sum @{$as} ) / $normalizingFactor);
        $result{$levelNamesRelative->[$taxonLevel]}{$key} = [$displayName, $relvalue];
        my $absvalue = sprintf("%.6f", sum @{$as});
        $result{$levelNamesAbsolute->[$taxonLevel]}{$key} = [$displayName, $absvalue];
      }
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
