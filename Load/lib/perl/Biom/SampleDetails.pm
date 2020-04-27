use strict;
use warnings;
# Prepares data for apidbUserDatasets.ud_Property and apidbUserDatasets.ud_SampleDetail 
# Guesses parents and tries to assign types / number / date / string
package ApiCommonData::Load::Biom::SampleDetails;

use List::Util qw/uniq min max/;
use Scalar::Util qw/looks_like_number/;
use Date::Parse qw/strptime/;
use POSIX qw(strftime);

sub expandSampleDetailsByName {
  my %sampleDetailsByName = %{$_[0]};

  for my $sampleName (keys %sampleDetailsByName){
    $sampleDetailsByName{$sampleName} = {"Unannotated sample" => $sampleName}
      unless $sampleDetailsByName{$sampleName} and %{$sampleDetailsByName{$sampleName}};
  }

  my @properties = uniq map {keys %$_} values %sampleDetailsByName;

  my %propertyDetails = map {
    my $property = $_;
    my @values = map {$sampleDetailsByName{$_}{$property} } keys %sampleDetailsByName;
    $property => propertyDetails ($property, \@values);
  } @properties;

  my %sampleDetails = map {
    my $sampleName = $_;

    my @sampleDetailsAnnotated = map {
      my $property = $_;
      my $value = $sampleDetailsByName{$sampleName}{$property};
      {
        property => $property,
        date_value => $propertyDetails{$property}{type} eq "date" ? strftime ("%Y-%m-%d", map {$_//0} strptime($value)) : undef,
        number_value => $propertyDetails{$property}{type} eq "number" ? $value : undef,
        string_value => $value,
      }
    } grep {$sampleDetailsByName{$sampleName}{$_}} @properties;

    $sampleName => \@sampleDetailsAnnotated
  } keys %sampleDetailsByName;
  return \%propertyDetails, \%sampleDetails;
}

sub looks_like_date {
  my ($ss,$mm,$hh,$day,$month,$year,$zone) = strptime(shift); 
  defined $day and defined $month and defined $year
}
sub propertyDetails {
  my ($property, $values) = @_;
  my $numBlankValues;
  my %h;
  for my $value (@{$values}){
    if ($value){
      $h{$value}++;
    } else {
      $numBlankValues++;
    }
  }
  my @distinctValues = keys %h;
  my @valuesThatAreNumbers = grep {looks_like_number $_} @distinctValues;
  my @valuesThatAreNotNumbers = grep {not (looks_like_number $_)} @distinctValues;

  my @valuesThatAreDates = grep {looks_like_date $_} @distinctValues;
  my @valuesThatAreNotDates = grep {not (looks_like_date $_)} @distinctValues;

  # heuristic, tries to skip empty values and outliers
  my $isProbablyADate = $property ne "Unannotated sample" && @valuesThatAreDates && @valuesThatAreNotDates < 5;
  my $isProbablyANumber = $property ne "Unannotated sample" && @valuesThatAreNumbers && @valuesThatAreNotNumbers < 5;

  my $type = $isProbablyADate ? "date" : $isProbablyANumber ? "number" : "string";

  my $numDistinctValues = @distinctValues;
  my $filter;
  my ($valuesSummary, $propertyType, $propertyTypeOntologyTerm);
  if (@distinctValues == 1 and not $numBlankValues){
    $propertyTypeOntologyTerm = "NCIT_C64359";
    $propertyType = "Common value";
    $valuesSummary =  $distinctValues[0];
    $filter = "membership";
  } elsif (@distinctValues < 10 and (@valuesThatAreNumbers < 2) and (@valuesThatAreDates < 2)){
    $propertyTypeOntologyTerm = "wojtek_made_up_categorical_value";
    $propertyType = "Categorical value";
    $valuesSummary =  join (", ", sort @distinctValues);
    $filter = "membership";
  } elsif ($isProbablyADate){
    $propertyTypeOntologyTerm =  "wojtek_made_up_date_value";
    $propertyType = "Date value";
    $valuesSummary = sprintf("%s different dates", scalar @valuesThatAreDates);
    $valuesSummary = join (", ", sort @valuesThatAreNotDates).", $valuesSummary" if @valuesThatAreNotDates;
    $filter = "range";
  } elsif ($isProbablyANumber){
    $propertyTypeOntologyTerm = "NCIT_C81274";
    $propertyType = "Numeric value";
    $valuesSummary = sprintf("%s to %s", min(@valuesThatAreNumbers), max(@valuesThatAreNumbers));
    $valuesSummary = join (", ", sort @valuesThatAreNotNumbers).", $valuesSummary" if @valuesThatAreNotNumbers;
    $filter = "range";
  } else {
    $propertyTypeOntologyTerm = "wojtek_made_up_text_value";
    $propertyType = "Text value";
    $valuesSummary =  sprintf("%s different values", scalar @distinctValues);
    $filter = "membership";
  }
  # filter,distinct_values,type as in apidbtuning.propertytype
  # apidbtuning.propertytype also contains property_source_id: the ontology term used
  # parent, parent_source_id, description: not sure yet
  return {
    filter => $filter,
    distinct_values => $numDistinctValues,
    type => $type,
    parent => $propertyType,
    parent_source_id => $propertyTypeOntologyTerm,
    description => "$property: $valuesSummary",
  };
}
1;
