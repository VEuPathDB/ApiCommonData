package ApiCommonData::Load::MBioResultsDir;

use strict;
use warnings;
use ApiCommonData::Load::MBioResultsTable::AsEntities;
use CBIL::ISA::StudyAssayEntity;
use JSON qw/encode_json/;
use feature 'say';

sub new {
  my ($class, $dir, $fileExtensions, $nodeTypes) = @_;
  die "node type for amplicon?" unless $nodeTypes->{amplicon};
  die "node type for wgs?" unless $nodeTypes->{wgs};
  return bless {
    dir => $dir,
    fileExtensions => $fileExtensions,
    nodeTypes => $nodeTypes,
  }, $class;
}

#<dataset>.<node name>.<file extension>
sub mbioResultTablePath {
  my ($self, $datasetName, $nodeName, $suffix) = @_;
  return $self->{dir} . "/" . join(".", $datasetName, $nodeName, $self->{fileExtensions}{$suffix});
}

sub ampliconTaxa {
  my ($self, $datasetName, $nodeName) = @_;
  my $path = $self->mbioResultTablePath($datasetName, $nodeName, 'ampliconTaxa');
  say STDERR "MBioResultsDir: Does $datasetName have ampliconTaxa? Trying path: $path";
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable::AsEntities->ampliconTaxa($path);
}

sub wgsTaxa {
  my ($self, $datasetName, $nodeName) = @_;
  my $path = $self->mbioResultTablePath($datasetName, $nodeName, 'wgsTaxa');
  say STDERR "MBioResultsDir: Does $datasetName have wgsTaxa? Trying path: $path";
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable::AsEntities->wgsTaxa($path);
}

sub level4ECs {
  my ($self, $datasetName, $nodeName) = @_;
  my $path = $self->mbioResultTablePath($datasetName, $nodeName, 'level4ECs');
  say STDERR "MBioResultsDir: Does $datasetName have level4ECs? Trying path: $path";
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable::AsEntities->wgsFunctions('level4EC', $path);
}

sub pathways {
  my ($self, $datasetName, $nodeName) = @_;
  my $pathA = $self->mbioResultTablePath($datasetName, $nodeName, 'pathwayAbundances');
  my $pathC = $self->mbioResultTablePath($datasetName, $nodeName, 'pathwayCoverages');
  say STDERR "MBioResultsDir: Does $datasetName have pathways? Trying paths: $pathA $pathC";
  return unless -f $pathA && -f $pathC;
  return ApiCommonData::Load::MBioResultsTable::AsEntities->wgsPathways($pathA, $pathC);
}

sub mbioResultTablesForNodeName {
  my ($self, $datasetName, $nodeType, $nodeName) = @_;
  my @mbioResultTables = $nodeType eq $self->{nodeTypes}{amplicon} ? (
      $self->ampliconTaxa($datasetName, $nodeName)
      )
    : $nodeType eq $self->{nodeTypes}{wgs} ? (
      $self->wgsTaxa($datasetName, $nodeName),
      $self->level4ECs($datasetName, $nodeName),
      $self->pathways($datasetName, $nodeName),
      )
    : ();
  return [grep {$_} @mbioResultTables];
}
sub mbioResultTablesBySuffixForStudy {
  my ($self, $studyXml) = @_;
  die "Not supported for MBio: studyXmls without datasets" unless @{$studyXml->{dataset}};
  die "Not supported for MBio, yet: studyXmls with more datasets than one" unless @{$studyXml->{dataset}} == 1;
  my $datasetName = $studyXml->{dataset}[0];
  $datasetName =~ s{otuDADA2_(.*)_RSRC}{$1};
  
  my %result;
  for my $nodeName (keys %{$studyXml->{node}}){
    my $suffix = $studyXml->{node}{$nodeName}{suffix};
    next unless $suffix;
    my $mbioResultTables = $self->mbioResultTablesForNodeName(
      $datasetName,
      $studyXml->{node}{$nodeName}{type},
      $nodeName
    );
    $result{$suffix} = $mbioResultTables;
  }
  return \%result;
}

sub toGetAddMoreData {
  my ($self) = @_;
  return sub {
    my ($studyXml) = @_;

    my $mbioResultTablesBySuffix = $self->mbioResultTablesBySuffixForStudy($studyXml);

    my $datasetName = $studyXml->{dataset}[0];
    warn "No mbioResultTables found for dataset: $datasetName" unless map {@$_} values %$mbioResultTablesBySuffix;
    return sub {
      my ($node) = @_;
      die "Unexpected argument: $node" unless blessed $node && $node->isa('CBIL::ISA::StudyAssayEntity');
      my ($sample, $suffix) = $node->getValue =~ m{^(.*) \((.*)\)$};
      return {} unless $sample && $suffix;
      my $valuesHash = {};
      for my $mbioResultTable (@{$mbioResultTablesBySuffix->{$suffix} // []}){
        my %h = %{$mbioResultTable->entitiesForSample($sample)//{}};
        while(my ($k, $o) = each %h){ 
          $valuesHash->{$k} = [$o];
        }
      }
      return $valuesHash;
    };
  };
}
1;
