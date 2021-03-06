use strict;
use warnings;

package ApiCommonData::Load::Biom;

use GUS::ObjRelP::DbiDatabase;

use ApiCommonData::Load::Biom::Lineages;
use ApiCommonData::Load::Biom::NcbiTaxons;
use ApiCommonData::Load::Biom::SampleDetails;
use ApiCommonData::Load::Biom::UserDatasetsStorage; 


use File::Find;
use File::Basename;
use List::Util qw/sum uniq/;

use JSON qw/decode_json/;

use Log::Log4perl;
my $log = Log::Log4perl->get_logger(__PACKAGE__);

sub new {
  my ($class, $db) = @_;
  return bless {
    ncbiTaxons => ApiCommonData::Load::Biom::NcbiTaxons->new($db->getQueryHandle(0)), 
    userDatasetsStorage => ApiCommonData::Load::Biom::UserDatasetsStorage->new($db),
  }, $class;
}
sub deleteDataForUserDatasetId {
  my ($self, $userDatasetId) = @_;
  $log->info("deleteDataForUserDatasetId $userDatasetId");
  $self->{userDatasetsStorage}->deleteUserDataset($userDatasetId);
}
sub storeFileUnderUserDatasetId {
  my ($self, $biomPath, $dataPath, $userDatasetId) = @_;

  $log->info("storeFileUnderUserDatasetId $biomPath, $dataPath, $userDatasetId");

  $self->{userDatasetsStorage}->storeUserDataset(
    $userDatasetId,
    biomFileContentsLazy(sub {$self->{ncbiTaxons}->findTaxonForLineage(@_)}, $biomPath, $dataPath)
  );
}

# This sub has a callback instead of $self so as not to depend on the database 
# Used for the unit test
sub biomFileContents {

  my($datasetSummary, $propertyDetailsByName, $sampleNamesInOrder, $sampleDetailsByName, $getAbundancesByIndex)
   = biomFileContentsLazy(@_);

  my %abundancesBySampleName;
  my %aggregatedAbundancesBySampleName;

  for my $ix (0 .. $#$sampleNamesInOrder) {
    my $sampleName = $sampleNamesInOrder->[$ix];
    my ($abundances, $aggregatedAbundances) = $getAbundancesByIndex->($ix);
    $abundancesBySampleName{$sampleName} = $abundances;
    $aggregatedAbundancesBySampleName{$sampleName} = $aggregatedAbundances;
  }
  
  return $datasetSummary, $propertyDetailsByName, $sampleNamesInOrder, $sampleDetailsByName, \%abundancesBySampleName, \%aggregatedAbundancesBySampleName;
}
sub biomFileContentsLazy {
  my ($findTaxonForLineageCb, $biomPath, $dataPath) = @_;

  our $unassignedLevel = "unassigned";
  our @levelNames = qw/kingdom phylum class order family genus species/;

  my $lineages = ApiCommonData::Load::Biom::Lineages->new($unassignedLevel, \@levelNames, 200);

  open my $fh, '<', $biomPath or die "Can't open file $!: $biomPath";
  my $doc = decode_json(do{local $/;<$fh>});
  close $fh;

  $log->info("read doc from $biomPath");

  our %dataByColumnIndexThenRowIndex;
  if ($dataPath) {
    open my $fh2, '<', $dataPath or die "Can't open file $!: $dataPath";
    while(<$fh2>){
      chomp;
      my ($r, $c, $v) = split "\t";
      $dataByColumnIndexThenRowIndex{$c}{$r} = $v;
    }
    $log->info("read data from TSV $dataPath");
  } else {
    $log->logdie("The installer is only supporting sparse JSON") if $doc->{matrix_type} eq "dense";
    my $dataSparse = $doc->{data} or $log->logdie("No data path and doc $biomPath also missing data?");
    for my $t (@{$dataSparse}){
      my ($r, $c, $v)  =@{$t};
      $dataByColumnIndexThenRowIndex{$c}{$r} = $v;
    }
    $log->info("read data from doc");
  }

  our @rows = @{$doc->{rows}};
  our %rowMetadataByName = map {
    (
      $_->{id} => ($_->{metadata} // {})
    )x!!$_->{id}
  } @rows;

  $log->info(sprintf ("%s / %s rows have metadata for taxonomy info", (scalar @rows), (scalar keys %rowMetadataByName)));

  our %lineages;
  our %levels;
  for my $taxonName (sort keys %rowMetadataByName){
    my $terms = $lineages->getTermsFromObject($taxonName, $rowMetadataByName{$taxonName});
    my $lineage = delete $terms->{lineage};
    $lineages{$taxonName} = $lineage;
    $levels{$lineage} = $terms;
  }
  
  my @lineagesThatMightHaveTaxons = keys %levels;
  our %ncbiTaxonsByLineage;
  for my $i (0..$#lineagesThatMightHaveTaxons){
    $log->info("Checked $i / $#lineagesThatMightHaveTaxons lineages against NCBI")
      if $i && ! $i %1000;
    my $lineage = $lineagesThatMightHaveTaxons[$i];

    $ncbiTaxonsByLineage{$lineage} = $findTaxonForLineageCb->($lineage);
  }
  $log->info(sprintf("Found ncbi taxa for %s / %s lineages checked", (scalar grep {$_} values %ncbiTaxonsByLineage), (scalar @lineagesThatMightHaveTaxons)));

  our @columns = @{$doc->{columns}};
  my %columnMetadataByName = map {
    (
      $_->{id} => ($_->{metadata} // {})
    )x!!$_->{id}
  } @columns;
 
  $log->info(sprintf ("%s / %s columns have metadata for sample details", (scalar @columns), (scalar keys %columnMetadataByName)));

  my ($propertyDetailsByName, $sampleDetailsByName) = ApiCommonData::Load::Biom::SampleDetails::expandSampleDetailsByName(\%columnMetadataByName);

  my @sampleNamesInOrder = map {$columns[$_]->{id}}  0..$#columns;
  sub getAbundancesByIndex {
    my ($columnIndex) = @_; 

    my $sampleName = $columns[$columnIndex]->{id};

    my $totalCountForSample = sum values %{$dataByColumnIndexThenRowIndex{$columnIndex}};
    my %counts;
    for my $rowIndex (sort keys %{$dataByColumnIndexThenRowIndex{$columnIndex}}){
      my $taxonName = $rows[$rowIndex]->{id};
      my $lineage = $lineages{$taxonName};
      my $count = $dataByColumnIndexThenRowIndex{$columnIndex}{$rowIndex};
      $counts{$lineage}+=$count;
    }
    my @abundances;
    for my $lineage (sort keys %counts){
      my @levels = map {$levels{$lineage}{$_}} @levelNames;
      my $hasLevels = grep {$_} @levels;
      push @abundances, {
         lineage => $lineage,
         ($hasLevels ? (levels  =>\@levels) : ()),
         ncbi_taxon_id => $ncbiTaxonsByLineage{$lineage},
	 absolute_abundance => $counts{$lineage},
	 relative_abundance =>  $counts{$lineage} / $totalCountForSample,
      }; 
    }
    return \@abundances, aggregateAbundances($unassignedLevel, \@levelNames, \@abundances);
  }

  # samples/observations are BIOM2 verbiage
  my $datasetSummary = sprintf("Dataset with %s %s in %s sample%s", (scalar @rows),(@rows == 1 ? "taxon" : "different taxa"),(scalar @columns), (@columns==1 ? "": "s"));

  return $datasetSummary, $propertyDetailsByName, \@sampleNamesInOrder, $sampleDetailsByName, \&getAbundancesByIndex;
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
       push @{$groups{join(";", map {$abundance->{levels}[$_] // ""} 0..$taxonLevel)}}, $abundance;
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
