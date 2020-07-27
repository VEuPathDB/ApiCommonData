use strict;
use warnings;
# Prepares data for apidbUserDatasets.ud_Property and apidbUserDatasets.ud_SampleDetail 
# Guesses parents and tries to assign types / number / date / string
package ApiCommonData::Load::Biom::SampleDetails;

use List::Util qw/uniq min max/;
use Scalar::Util qw/looks_like_number/;
use Date::Parse qw/strptime/;
use POSIX qw(strftime);

sub looks_nonblank {
  my ($v) = @_;
  return 1 if $v eq 0;
  return 0 if not $v;
  return 0 if $v =~ /na|n\/a/i;
  return 1;
}
sub looks_like_date {
  my ($ss,$mm,$hh,$day,$month,$year,$zone) = strptime(shift); 
  defined $day && defined $month && defined $year
}

sub expandSampleDetailsByName {
  my %sampleDetailsByName = %{$_[0]};

  for my $sampleName (keys %sampleDetailsByName){
    $sampleDetailsByName{$sampleName} = {"Unannotated sample" => $sampleName}
      unless $sampleDetailsByName{$sampleName} && %{$sampleDetailsByName{$sampleName}};
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
        date_value => $propertyDetails{$property}{type} eq "date" && looks_nonblank($value) ? strftime ("%y-%m-%d", map {$_//0} strptime($value)) : undef,
        number_value => $propertyDetails{$property}{type} eq "number" && looks_nonblank($value) ? $value : undef,
        string_value => $value,
      }
    } grep {defined $sampleDetailsByName{$sampleName}{$_}} @properties;

    $sampleName => \@sampleDetailsAnnotated
  } keys %sampleDetailsByName;
  return \%propertyDetails, \%sampleDetails;
}

sub propertyDetails {
  my ($property, $values) = @_;
  my $numAllValues = scalar @{$values};
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
  my @valuesThatAreNotBlanksOrNumbers = grep { looks_nonblank($_) && not (looks_like_number $_)} @distinctValues;

  my @valuesThatAreDates = grep {looks_like_date $_} @distinctValues;
  my @valuesThatAreNotBlanksOrDates = grep {looks_nonblank($_) && not (looks_like_date $_)} @distinctValues;

  # heuristic, tries to skip empty values
  my $isProbablyADate = $property ne "Unannotated sample" && @valuesThatAreDates && not @valuesThatAreNotBlanksOrDates;
  my $isProbablyANumber = $property ne "Unannotated sample" && @valuesThatAreNumbers && not @valuesThatAreNotBlanksOrNumbers;

  my $type = $isProbablyADate ? "date" : $isProbablyANumber ? "number" : "string";

  my $numDistinctValues = @distinctValues;
  my $filter;
  my ($valuesSummary, $propertyType, $propertyTypeOntologyTerm);
  if (@distinctValues == 1 && not $numBlankValues){
    $propertyTypeOntologyTerm = "NCIT_C64359";
    $propertyType = "Common value";
    $valuesSummary =  $distinctValues[0];
    $filter = "membership";
  } elsif (@distinctValues < 10 && (@valuesThatAreNumbers < 2) && (@valuesThatAreDates < 2)){
    $propertyTypeOntologyTerm = "OT_categorical_value";
    $propertyType = "Categorical value";
    $valuesSummary =  join (", ", sort @distinctValues);
    $filter = "membership";
  } elsif ($isProbablyADate){
    $propertyTypeOntologyTerm =  "OT_date_value";
    $propertyType = "Date value";
    $valuesSummary = sprintf("%s different dates", scalar @valuesThatAreDates);
    $valuesSummary .= ", no data for $numBlankValues/$numAllValues samples" if $numBlankValues;
    $filter = "range";
  } elsif ($isProbablyANumber){
    $propertyTypeOntologyTerm = "NCIT_C81274";
    $propertyType = "Numeric value";
    $valuesSummary = sprintf("%s to %s", min(@valuesThatAreNumbers), max(@valuesThatAreNumbers));
    $valuesSummary .= ", no data for $numBlankValues/$numAllValues samples" if $numBlankValues;
    $filter = "range";
  } else {
    $propertyTypeOntologyTerm = "OT_text_value";
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
