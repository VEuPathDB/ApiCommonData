package ApiCommonData::Load::MBioResultsTable::AsGus;
use strict;
use warnings;

use base qw/ApiCommonData::Load::MBioResultsTable/;

use List::Util qw/all/;

$ApiCommonData::Load::MBioResultsTable::AsGus::dataTypeInfo = {
  ampliconTaxa => {
    valueToGus => \&valueToGusTaxa,
  },
  wgsTaxa => {
    valueToGus => \&valueToGusTaxa,
  },
  wgsFunctions => {
    valueToGus => sub {
      my ($dti, $panId, $row, $sd, $rd, $v) = @_;
      return 'GUS::Model::Results::FunctionalUnitAbundance', {
        PROTOCOL_APP_NODE_ID => $panId,
        %{$rd},
        unit_type => $dti->{unitType},
        abundance_cpm => $v,
      };
    },
  },
  wgsPathways => {
    valueToGus => sub {
      my ($dti, $panId, $row, $sd, $rd, $v) = @_;
      my ($abundance, $coverage) = @$v;
      return 'GUS::Model::Results::FunctionalUnitAbundance', {
        PROTOCOL_APP_NODE_ID => $panId,
        %{$rd},
        unit_type => "pathway",
        abundance_cpm => $abundance,
        coverage_fraction => $coverage
      };
    },
  },
};

sub submitToGus {
  my ($self, $setMaxObjects, $undefPointerCache, $submit, $protocolAppNodeIdsForSamples) = @_;

  $setMaxObjects->(scalar @{$self->{rows}});

  SAMPLE:
  for my $sample (@{$self->{samples}}){
    my $panId = $protocolAppNodeIdsForSamples->{$sample};
    die "Missing ProtocolAppNode id for sample: $sample" unless $panId;
    ROW:
    for my $row (@{$self->{rows}}){
	my $value = $self->{data}{$sample}{$row};
        next ROW unless ref $value eq 'ARRAY' ? all {$_} @{$value} : $value;
	$submit->($self->{valueToGus}->($self, $panId, $row, $self->{sampleDetails}{$sample}, $self->{rowDetails}{$row}, $value));
    }
    $undefPointerCache->();
  }
}

sub valueToGusTaxa {
  my ($dti, $panId, $row, $sd, $rd, $v) = @_;

  return 'GUS::Model::Results::LineageAbundance', {
    PROTOCOL_APP_NODE_ID => $panId,
    lineage => $row,
    raw_count => $v,
    relative_abundance => sprintf("%.6f", $v / $sd->{totalCount})
  };
}
