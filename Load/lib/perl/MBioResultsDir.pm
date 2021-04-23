package ApiCommonData::Load::MBioResultsDir;

use strict;
use warnings;
use ApiCommonData::Load::MBioResultsTable;
use JSON qw/encode_json/;

sub new {
  my ($class, $dir, $suffixes) = @_;
  return bless {
    dir => $dir,
    suffixes => $suffixes,
  }, $class;
}

sub tablePath {
  my ($self, $dataset, $suffix) = @_;
   $dataset =~ s{otuDADA2_(.*)_RSRC}{$1};
  return $self->{dir} . "/" . $dataset . $self->{suffixes}{$suffix};
}

sub ampliconTaxa {
  my ($self, $dataset) = @_;
  my $path = $self->tablePath($dataset, 'ampliconTaxa');
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable->ampliconTaxa($path);
}

sub wgsTaxa {
  my ($self, $dataset) = @_;
  my $path = $self->tablePath($dataset, 'wgsTaxa');
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable->wgsTaxa($path);
}

sub level4ECs {
  my ($self, $dataset) = @_;
  my $path = $self->tablePath($dataset, 'level4ECs');
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable->wgsFunctions('level4EC', $path);
}

sub pathways {
  my ($self, $dataset) = @_;
  my $pathA = $self->tablePath($dataset, 'pathwayAbundances');
  my $pathC = $self->tablePath($dataset, 'pathwayCoverages');
  return unless -f $pathA && -f $pathC;
  return ApiCommonData::Load::MBioResultsTable->wgsPathways($pathA, $pathC);
}

sub allTablesForDataset {
  return grep {$_} (ampliconTaxa(@_), wgsTaxa(@_), level4ECs(@_), pathways(@_));
}

# TODO:
# - use a function call here
# - aggregates at different levels
sub toGetAddMoreData {
  my ($self) = @_;
  return sub {
    my ($studyXml) = @_;
    my $dataset = $studyXml->{dataset}[0];
    my @tables = $self->allTablesForDataset($dataset);
    warn "No tables found for dataset: $dataset" unless @tables;
    return sub {
      my ($valuesHash) = @_;
      my $sample = $valuesHash->{name}[0];
      for my $table (@tables){
        my ($k, $o) = $table->entitiesForSample($sample);
        if($k and $o){
          $valuesHash->{$k} = [$o];
        }
      }
      return $valuesHash;
    };
  };
}
1;
