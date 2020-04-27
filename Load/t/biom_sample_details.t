use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use ApiCommonData::Load::Biom::SampleDetails;
use Test::More;

sub propertyDetails {
  my ($pd, $sd) = ApiCommonData::Load::Biom::SampleDetails::expandSampleDetailsByName(@_);
#  diag explain $pd;
  return $pd;
}
sub sampleDetails {
  my ($pd, $sd) = ApiCommonData::Load::Biom::SampleDetails::expandSampleDetailsByName(@_);
#  diag explain $sd;
  return $sd;
}
my $exampleDate = "1991-11-17"; # Wojtek's birthday

is_deeply(propertyDetails({}), {}, "Null case property details");
is_deeply(sampleDetails({}), {}, "Null case sample details");

is_deeply(propertyDetails({s1 => {}}),
{
  'Unannotated sample' => {
    'description' => 'Unannotated sample: s1',
    'distinct_values' => 1,
    'filter' => 'membership',
    'parent' => 'Common value',
    'parent_source_id' => 'NCIT_C64359',
    'type' => 'string'
  }
}, "Default values property details");
is_deeply(sampleDetails({s1 => {}}),{
  's1' => [
    {
      'date_value' => undef,
      'number_value' => undef,
      'property' => 'Unannotated sample',
      'string_value' => 's1'
    }
  ]
}, "Default values sample details");
is_deeply(sampleDetails({"123" => {}})->{123}[0]{number_value}, undef, "Default values sample detail is never a number");
is_deeply(sampleDetails({$exampleDate => {}})->{$exampleDate}[0]{date_value}, undef, "Default values sample detail is never a date");
is_deeply(propertyDetails({s1 => {p=>1}}), {p => {
     'description' => 'p: 1',
     'distinct_values' => 1,
     'filter' => 'membership',
     'parent' => 'Common value',
     'parent_source_id' => 'NCIT_C64359',
     'type' => 'number'
}}, "One value number pd");

is_deeply(propertyDetails({s1 => {p=>"v"}}), {p => {
     'description' => 'p: v',
     'distinct_values' => 1,
     'filter' => 'membership',
     'parent' => 'Common value',
     'parent_source_id' => 'NCIT_C64359',
     'type' => 'string'
}}, "One value string pd");

is_deeply(propertyDetails({s1 => {p=>$exampleDate}}), {p => {
     'description' => "p: $exampleDate",
     'distinct_values' => 1,
     'filter' => 'membership',
     'parent' => 'Common value',
     'parent_source_id' => 'NCIT_C64359',
     'type' => 'date'
}}, "One value date pd");

is_deeply(sampleDetails({s1 => {p=>"v"}}), {s1 => [{
  'date_value' => undef,
  'number_value' => undef,
  'property' => 'p',
  'string_value' => 'v'
}]}, "One value string sd");

is_deeply(sampleDetails({s1 => {p=>1}}), {s1 => [{
  'date_value' => undef,
  'number_value' => 1,
  'property' => 'p',
  'string_value' => '1'
}]}, "One value number sd");

is_deeply(sampleDetails({s1 => {p=>"$exampleDate"}}), {s1 => [{
  'date_value' => "$exampleDate",
  'number_value' => undef,
  'property' => 'p',
  'string_value' => $exampleDate
}]}, "One value date sd");

is_deeply(propertyDetails({s1 => {p=>1, p2=>2}})->{"p"}, propertyDetails({s1 => {p=>1}})->{"p"}, "properties don't collide");

is_deeply(propertyDetails({s1 => {p=>1}, s2 => {p=>1}})->{"p"}, propertyDetails({s1 => {p=>1}})->{"p"}, "properties merge");

is_deeply(propertyDetails({s1 => {p=>1}, s2 => {p=>2}})->{"p"}, {
  'description' => 'p: 1 to 2',
  'distinct_values' => 2,
  'filter' => 'range',
  'parent' => 'Numeric value',
  'parent_source_id' => 'NCIT_C81274',
  'type' => 'number'
}, "Two values example");

is_deeply(propertyDetails({s1 => {p=>"2001-01-01"}, s2 => {p=>"2002-02-02"}})->{"p"}{"parent"}, "Date value", "Two values date");
is_deeply(propertyDetails({s1 => {p=>"v1"}, s2 => {p=>"v2"}})->{"p"}{"parent"}, "Categorical value", "Two values text is a categorical value");
is_deeply(propertyDetails({s1 => {p=>"v1"}, s2 => {}})->{"p"}{"parent"}, "Categorical value", "One value and one missing text is a categorical value");
is_deeply(propertyDetails({s1 => {p=>1}, s2 => {}})->{"p"}{"parent"}, "Categorical value", "One value and one missing number is a categorical value");
my %h = map {("s$_" => {p => "v$_"})} 0..1000;
is_deeply(propertyDetails(\%h)->{"p"}{"parent"}, "Text value", "Lots of values text is a Text value");

done_testing;
