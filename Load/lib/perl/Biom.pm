use strict;
use warnings;

package ApiCommonData::Load::Biom;
use ApiCommonData::Load::Biom::Lineages;
use ApiCommonData::Load::Biom::NcbiTaxons;
use ApiCommonData::Load::Biom::SampleDetails;
use ApiCommonData::Load::Biom::UserDatasetsStorage; 


use File::Find;
use File::Basename;
use List::Util qw/sum/;

use Bio::Community::IO;
use YAML; 

sub new {
  my ($class, $dbh) = @_;
  return bless {
    ncbiTaxons => ApiCommonData::Load::Biom::NcbiTaxons->new($dbh), 
    userDatasetsStorage => ApiCommonData::Load::Biom::UserDatasetsStorage->new($dbh),
  }, $class;
}
sub deleteDataForUserDatasetId {
  my ($self, $userDatasetId) = @_;
  $self->{userDatasetsStorage}->deleteUserDataset($userDatasetId);
}
sub storeFileUnderUserDatasetId {
  my ($self, $biomPath, $userDatasetId, $datasetSummary) = @_;

  $self->{userDatasetsStorage}->storeUserDataset(
    $userDatasetId, $datasetSummary,
    biomFileContents(sub {$self->{ncbiTaxons}->findTaxonForLineage(@_)}, $biomPath)
  );
}
# This sub has a callback instead of $self so as not to depend on the database 
sub biomFileContents {
  my ($findTaxonForLineageCb, $biomPath) = @_;

  my $unassignedLevel = "unassigned";
  my @levelNames = qw/kingdom phylum class order family genus species/;

  my $lineages = ApiCommonData::Load::Biom::Lineages->new($unassignedLevel, \@levelNames, 200, 250);

  my $in = Bio::Community::IO->new(
	-file   =>  $biomPath,
	-format => 'biom',
	-ab_type => 'fraction', # does nothing?
     );

  # https://metacpan.org/release/Bio-Community/source/lib/Bio/Community/IO/Driver/biom.pm#L374
  # doesn't quite cut the cheese for the one file which said Taxonomy instead of taxonomy

  my @communities;
  while(my $community = $in->next_community){
    push @communities, $community;
  }
  my %rowMetadataByName = map {
    (
      $_->{id} => ($_->{metadata} // {})
    )x!!$_->{id}
  } @{$in->_get_json()->{rows}};


  my %columnMetadataByName = map {
    (
      $_->{id} => ($_->{metadata} // {})
    )x!!$_->{id}
  } @{$in->_get_json()->{columns}};
  my ($propertyDetailsByName, $sampleDetailsByName) = ApiCommonData::Load::Biom::SampleDetails::expandSampleDetailsByName(\%columnMetadataByName);

  my @sampleNamesInOrder;
  my %abundancesBySampleName;
  my %aggregatedAbundancesBySampleName;

  my %lineages;
  my %ncbiTaxons;

  for my $community (@communities){
    push @sampleNamesInOrder, $community->name;
    my @abundances;
    while(my $member = $community->next_member()){

      $lineages{$member->id} //= $lineages->getTermsFromObject($member->id, $rowMetadataByName{$member->id});

      $ncbiTaxons{$member->id} //= $findTaxonForLineageCb->($lineages{$member->id}{lineage});

      my @ls = map {$lineages{$member->id}{$_}} @levelNames;
      push @abundances, {
         lineage => $lineages{$member->id}{lineage},
         ((grep {$_} @ls) ? (levels  =>\@ls) : ()),
         ncbi_taxon_id => $ncbiTaxons{$member->id},
	 absolute_abundance => $community->get_count($member),
	 relative_abundance =>  $community->get_rel_ab($member)/100,
      }; 
    }
    $abundancesBySampleName{$community->name} = \@abundances;
    $aggregatedAbundancesBySampleName{$community->name} = aggregateAbundances($unassignedLevel, \@levelNames, \@abundances);
  }
  return $propertyDetailsByName, \@sampleNamesInOrder, $sampleDetailsByName, \%abundancesBySampleName, \%aggregatedAbundancesBySampleName;
}

sub aggregateAbundances {
  my ($unassignedLevel, $levelNames, $abundances) = @_;
  my @levelNames = @{$levelNames};
  my @abundances = @{$abundances};
  my @result;
  my @abundancesWithLevels = grep {$_->{levels}} @abundances;
  my @abundancesWithoutLevels = grep {not $_->{levels}} @abundances;
  for my $taxonLevel ((0..$#levelNames)){
    my %groups;
    for my $abundance (@abundancesWithLevels){
       my $l = join(";", map {$abundance->{levels}[$_] // ""} 0..$taxonLevel);
       push @{$groups{$l}}, $abundance;
    }
    push @result, aggregateAbundanceGroups($taxonLevel, $levelNames[$taxonLevel], \%groups);
  }
  my %groupsWithoutLevels;
  push @{$groupsWithoutLevels{$_->{lineage}}}, $_ for @abundancesWithoutLevels;
  push @result,  aggregateAbundanceGroups(scalar @levelNames, $unassignedLevel, \%groupsWithoutLevels);
  return \@result;
}

sub aggregateAbundanceGroups {
  my ($taxonLevel, $taxonLevelName, $abundancesByLineage) = @_;
  my @result;
  while(my ($lineage, $abundances) = each %{$abundancesByLineage}){
    my ($taxonName) =reverse split ";", $lineage; 
    push @result, {
      taxon_level => $taxonLevel,
      taxon_level_name => $taxonLevelName,
      taxon_name => $taxonName,
      lineage => $lineage,
      absolute_abundance => sum (map {$_->{absolute_abundance}} @{$abundances}),
      relative_abundance => sum (map {$_->{relative_abundance}} @{$abundances}),
    };
  }
  return @result;
}
1;
