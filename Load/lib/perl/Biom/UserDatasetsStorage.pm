use strict;
use warnings;
package ApiCommonData::Load::Biom::UserDatasetsStorage;
use DBI;

sub new {
  my ($class, $dbh) = @_;
  my $self = {};
  $self->{getNextProfileSetIdSth} = $dbh->prepare(<<SQL) or die $dbh->errstr;
    select ApiDBUserDatasets.ud_ProfileSet_sq.nextval from dual
SQL
  $self->{insertProfileSetSth} = $dbh->prepare(<<SQL) or die $dbh->errstr;
    insert into ApiDBUserDatasets.ud_ProfileSet
      (user_dataset_id, profile_set_id, name)
    values (?,?,?)
SQL
  $self->{getNextSampleIdSth} = $dbh->prepare(<<SQL) or die $dbh->errstr;
    select ApiDBUserDatasets.ud_Sample_sq.nextval from dual
SQL
  $self->{insertSampleNameSth} = $dbh->prepare(<<SQL) or die $dbh->errstr;
    insert into ApiDBUserDatasets.ud_Sample
      (profile_set_id, sample_id, name, display_name)
    values (?,?,?,?)
SQL
  $self->{getNextPropertyIdSth} = $dbh->prepare(<<SQL) or die $dbh->errstr;
    select ApiDBUserDatasets.ud_Property_sq.nextval from dual
SQL
  $self->{insertPropertySth} = $dbh->prepare(<<SQL) or die $dbh->errstr;
    insert into apidbUserDatasets.ud_Property
       (profile_set_id, property_id, property, type, filter, distinct_values, parent, parent_source_id, description)
    values (?,?,?,?,?,?,?,?,?)
SQL
  $self->{insertSampleDetailSth} = $dbh->prepare(<<SQL) or die $dbh->errstr;
    insert into ApiDBUserDatasets.ud_SampleDetail
      (profile_set_id, sample_id, property_id, date_value, number_value, string_value)
    values (?,?,?,?,?,?)
SQL
  $self->{insertAbundanceSth} = $dbh->prepare(<<SQL) or die $dbh->errstr;
    insert into apidbUserDatasets.ud_Abundance
       (profile_set_id, sample_id, lineage, relative_abundance, absolute_abundance, ncbi_tax_id, kingdom, phylum, class, rank_order, family, genus, species)
    values (?,?,?,?,?,?,?,?,?,?,?,?,?)
SQL

  $self->{insertAggregatedAbundanceSth} = $dbh->prepare(<<SQL) or die $dbh->errstr;
    insert into apidbUserDatasets.ud_AggregatedAbundance
       (profile_set_id, sample_id, taxon_level_name, taxon_level, taxon_name, lineage, relative_abundance, absolute_abundance)
    values (?,?,?,?,?,?,?,?)
SQL
  $self->{selectProfileSetIdSth} = $dbh->prepare(<<SQL) or die $dbh->errstr;
    select profile_set_id from ApiDBUserDatasets.ud_ProfileSet where user_dataset_id = ?
SQL
  $self->{deleteForProfileSetIdSths} = [map {
    $dbh->prepare("delete from apidbUserDatasets.$_ where profile_set_id=?") or die $dbh->errstr
  } reverse qw/ud_ProfileSet ud_Sample ud_Property ud_SampleDetail ud_Abundance ud_AggregatedAbundance ud_AggregatedAbundance/];
  return bless $self, $class;
}

# We're reusing the schema which also has a name required
# We have one profile set per user dataset, I guess it's not the worst
# Store dataset summary in the otherwise redundant name field, to conveniently show it on sample page - this is a hack
sub insertProfileSet {
  my ($self, $userDatasetId, $datasetSummary) = @_;

  $self->{getNextProfileSetIdSth}->execute;
  my ($profileSetId) = $self->{getNextProfileSetIdSth}->fetchrow_array;

  $self->{insertProfileSetSth}
    ->execute($userDatasetId, $profileSetId, $datasetSummary);
  return $profileSetId;
}
sub insertSampleName {
  my ($self, $profileSetId, $sampleGloballyUniqueName, $sampleDisplayName) = @_;
  
  $self->{getNextSampleIdSth}->execute;
  my ($sampleId) = $self->{getNextSampleIdSth}->fetchrow_array;

  $self->{insertSampleNameSth}
    ->execute($profileSetId, $sampleId, $sampleGloballyUniqueName, $sampleDisplayName);

  return $sampleId;
}
sub insertProperty {
  my ($self, $profileSetId, $propertyName, $propertyDetails) = @_;
  my %propertyDetails = %{$propertyDetails};

  $self->{getNextPropertyIdSth}->execute;
  my ($propertyId) = $self->{getNextPropertyIdSth}->fetchrow_array;

  $self->{insertPropertySth}
    ->execute($profileSetId, $propertyId, $propertyName, @propertyDetails{qw/type filter distinct_values parent parent_source_id description/});

  return $propertyId;
}
sub insertSampleDetail {
  my ($self, $profileSetId, $sampleId, $propertyId, $sampleDetail) = @_;
  my %sampleDetail = %{$sampleDetail};
  $self->{insertSampleDetailSth}
    ->execute($profileSetId, $sampleId, $propertyId, @sampleDetail{qw/date_value number_value string_value/});
}

sub insertAbundance {
  my ($self, $profileSetId, $sampleId, $abundance) = @_;
  my %abundance = %{$abundance};
  my $ls = $abundance{levels};
  my @levels = $ls ? @{$ls} : map {undef} 1..7; 
  $self->{insertAbundanceSth}
    ->execute($profileSetId, $sampleId, @abundance{qw/lineage relative_abundance absolute_abundance ncbi_taxon_id/}, @levels);
}

sub insertAggregatedAbundance {
  my ($self, $profileSetId, $sampleId, $aggregatedAbundance) = @_;
  my %aggregatedAbundance = %{$aggregatedAbundance};

  $self->{insertAggregatedAbundanceSth}
    ->execute($profileSetId, $sampleId, @aggregatedAbundance{qw/taxon_level_name taxon_level taxon_name lineage relative_abundance absolute_abundance/});
       
}

sub storeUserDataset {
  my ($self, $userDatasetId, $datasetSummary, $propertyDetailsByName, $sampleNamesInOrder, $sampleDetailsByName, $abundancesBySampleName, $aggregatedAbundancesBySampleName) = @_;

  # Clean up any previous runs
  $self->deleteUserDataset($userDatasetId);

  my $profileSetId = $self->insertProfileSet($userDatasetId, $datasetSummary);
  my %propertyIdsByName;
  for my $propertyName (keys %{$propertyDetailsByName}){
    $propertyIdsByName{$propertyName} = $self->insertProperty($profileSetId, $propertyName, $propertyDetailsByName->{$propertyName});
  }
  for my $sampleName (@{$sampleNamesInOrder}){
    
    my $sampleId = $self->insertSampleName($profileSetId, "$userDatasetId-$sampleName", $sampleName);
    for my $sampleDetail (@{$sampleDetailsByName->{$sampleName}}){
      $self->insertSampleDetail($profileSetId, $sampleId, $propertyIdsByName{$sampleDetail->{property}}, $sampleDetail);
    }
    for my $abundance (@{$abundancesBySampleName->{$sampleName}}){
      $self->insertAbundance ($profileSetId, $sampleId, $abundance);
    }
    for my $aggregatedAbundance (@{$aggregatedAbundancesBySampleName->{$sampleName}}){
      $self->insertAggregatedAbundance ($profileSetId, $sampleId, $aggregatedAbundance);
    }
  } 
}


sub deleteUserDataset {
  my ($self, $userDatasetId) = @_;
  $self->{selectProfileSetIdSth}->execute($userDatasetId);
  my $profileSetId;
  $self->{selectProfileSetIdSth}->bind_col(1, \$profileSetId);
  while($self->{selectProfileSetIdSth}->fetch and $profileSetId){
    $_->execute($profileSetId) for @{$self->{deleteForProfileSetIdSths}};
  }
}
1;
