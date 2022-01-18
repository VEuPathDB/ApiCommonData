package ApiCommonData::Load::MBioResultsDir;

use strict;
use warnings;
use ApiCommonData::Load::MBioResultsTable::AsEntities;
use CBIL::ISA::StudyAssayEntity;
use JSON qw/encode_json/;
use feature 'say';

sub new {
  my ($class, $dir, $fileExtensions) = @_;
  return bless {
    dir => $dir,
    fileExtensions => $fileExtensions,
  }, $class;
}

#<dataset>.<suffix>.<file extension>
sub mbioResultTablePath {
  my ($self, $datasetName, $suffix, $fileType) = @_;
  my $ext = $self->{fileExtensions}{$fileType};
  die "What's the file extension for fileType $fileType?" unless $ext;
  return $self->{dir} . "/" . join(".", $datasetName, $suffix, $ext);
}

sub ampliconTaxa {
  my ($self, $datasetName, $suffix) = @_;
  my $path = $self->mbioResultTablePath($datasetName, $suffix, 'ampliconTaxa');
  say STDERR "MBioResultsDir: Does $datasetName have ampliconTaxa? -f $path = " . (-f $path ? 1 : 0);
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable::AsEntities->ampliconTaxa($path);
}

sub eukdetectCpms {
  my ($self, $datasetName, $suffix) = @_;
  my $path = $self->mbioResultTablePath($datasetName, $suffix, 'eukdetectCpms');
  say STDERR "MBioResultsDir: Does $datasetName have eukdetectCpms? -f $path = " . (-f $path ? 1 : 0);
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable::AsEntities->eukdetectCpms($path);
}

sub wgsTaxa {
  my ($self, $datasetName, $suffix) = @_;
  my $path = $self->mbioResultTablePath($datasetName, $suffix, 'wgsTaxa');
  say STDERR "MBioResultsDir: Does $datasetName have wgsTaxa? -f $path = " . (-f $path ? 1 : 0);
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable::AsEntities->wgsTaxa($path);
}

sub level4ECs {
  my ($self, $datasetName, $suffix) = @_;
  my $path = $self->mbioResultTablePath($datasetName, $suffix, 'level4ECs');
  say STDERR "MBioResultsDir: Does $datasetName have level4ECs? -f $path = " . (-f $path ? 1 : 0);
  return unless -f $path;
  return ApiCommonData::Load::MBioResultsTable::AsEntities->wgsFunctions('level4EC', $path);
}

sub pathways {
  my ($self, $datasetName, $suffix) = @_;
  my $pathA = $self->mbioResultTablePath($datasetName, $suffix, 'pathwayAbundances');
  my $pathC = $self->mbioResultTablePath($datasetName, $suffix, 'pathwayCoverages');
  say STDERR "MBioResultsDir: Does $datasetName have pathways? Trying paths: $pathA $pathC";
  return unless -f $pathA && -f $pathC;
  return ApiCommonData::Load::MBioResultsTable::AsEntities->wgsPathways($pathA, $pathC);
}

sub mbioResultTablesForSuffix {
  my ($self, $datasetName, $suffix) = @_;
  my @maybeTables = (
      $self->ampliconTaxa($datasetName, $suffix),
      $self->eukdetectCpms($datasetName, $suffix),
      $self->wgsTaxa($datasetName, $suffix),
      $self->level4ECs($datasetName, $suffix),
      $self->pathways($datasetName, $suffix),
      );
  return [grep {$_} @maybeTables];
}
sub mbioResultTablesBySuffixForStudy {
  my ($self, $studyXml) = @_;
  die "Not supported for MBio: studyXmls without datasets" unless @{$studyXml->{dataset}};
  die "Not supported for MBio, yet: studyXmls with more datasets than one" unless @{$studyXml->{dataset}} == 1;
  my $datasetName = $studyXml->{dataset}[0];
  $datasetName =~ s{otuDADA2_(.*)_RSRC}{$1};
  $datasetName =~ s{MicrobiomeStudyEDA_(.*)_RSRC}{$1};
  
  my %result;
  for my $nodeName (keys %{$studyXml->{node}}){
    my $suffix = $studyXml->{node}{$nodeName}{suffix};
    next unless $suffix;
    my $mbioResultTables = $self->mbioResultTablesForSuffix(
      $datasetName,
      $suffix,
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
