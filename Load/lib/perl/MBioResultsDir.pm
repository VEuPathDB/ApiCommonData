package ApiCommonData::Load::MBioResultsDir;

use strict;
use warnings;
use ApiCommonData::Load::MBioResultsTable;
use CBIL::ISA::StudyAssayEntity;
use JSON qw/encode_json/;

sub new {
  my ($class, $dir, $fileExtensions, $nodeTypes) = @_;
  return bless {
    dir => $dir,
    fileExtensions => $fileExtensions,
    nodeTypes => $nodeTypes,
  }, $class;
}

#<dataset>.<node name>.<file extension>
sub tablePath {
  my ($self, $datasetName, $nodeName, $suffix) = @_;
  return $self->{dir} . "/" . join(".", $datasetName, $nodeName, $self->{fileExtensions}{$suffix});
}

sub ampliconTaxa {
  my ($self, $datasetName, $nodeName) = @_;
  my $path = $self->tablePath($datasetName, $nodeName, 'ampliconTaxa');
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable->ampliconTaxa($path);
}

sub wgsTaxa {
  my ($self, $datasetName, $nodeName) = @_;
  my $path = $self->tablePath($datasetName, $nodeName, 'wgsTaxa');
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable->wgsTaxa($path);
}

sub level4ECs {
  my ($self, $datasetName, $nodeName) = @_;
  my $path = $self->tablePath($datasetName, $nodeName, 'level4ECs');
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable->wgsFunctions('level4EC', $path);
}

sub pathways {
  my ($self, $datasetName, $nodeName) = @_;
  my $pathA = $self->tablePath($datasetName, $nodeName, 'pathwayAbundances');
  my $pathC = $self->tablePath($datasetName, $nodeName, 'pathwayCoverages');
  return unless -f $pathA && -f $pathC;
  return ApiCommonData::Load::MBioResultsTable->wgsPathways($pathA, $pathC);
}

sub tablesForNodeName {
  my ($self, $datasetName, $nodeType, $nodeName) = @_;
  my @tables = $nodeType eq $self->{nodeTypes}{amplicon} ? (
      $self->ampliconTaxa($datasetName, $nodeName)
      )
    : $nodeType eq $self->{nodeTypes}{wgs} ? (
      $self->wgsTaxa($datasetName, $nodeName),
      $self->level4ECs($datasetName, $nodeName),
      $self->pathways($datasetName, $nodeName),
      )
    : ();
  return [grep {$_} @tables];
}
sub tablesBySuffixForStudy {
  my ($self, $studyXml) = @_;
  die "Not supported for MBio: studyXmls without datasets" unless @{$studyXml->{dataset}};
  die "Not supported for MBio, yet: studyXmls with more datasets than one" unless @{$studyXml->{dataset}} == 1;
  my $datasetName = $studyXml->{dataset}[0];
  $datasetName =~ s{otuDADA2_(.*)_RSRC}{$1};
  
  my %result;
  for my $nodeName (keys %{$studyXml->{node}}){
    my $suffix = $studyXml->{node}{$nodeName}{suffix};
    next unless $suffix;
    my $tables = $self->tablesForNodeName(
      $datasetName,
      $studyXml->{node}{$nodeName}{type},
      $nodeName
    );
    $result{$suffix} = $tables;
  }
  return \%result;
}

sub toGetAddMoreData {
  my ($self) = @_;
  return sub {
    my ($studyXml) = @_;

    my $tablesBySuffix = $self->tablesBySuffixForStudy($studyXml);

    my $datasetName = $studyXml->{dataset}[0];
    warn "No tables found for dataset: $datasetName" unless map {@$_} values %$tablesBySuffix;
    return sub {
      my ($node) = @_;
      die "Unexpected argument: $node" unless blessed $node && $node->isa('CBIL::ISA::StudyAssayEntity');
      my ($sample, $suffix) = $node->getValue =~ m{^(.*) \((.*)\)$};
      return {} unless $sample && $suffix;
      my $valuesHash = {};
      for my $table (@{$tablesBySuffix->{$suffix} // []}){
        my %h = %{$table->entitiesForSample($sample)//{}};
        while(my ($k, $o) = each %h){ 
          $valuesHash->{$k} = [$o];
        }
      }
      return $valuesHash;
    };
  };
}
1;
