package ApiCommonData::Load::RetrieveAppNodeCharacteristics;

use strict;

use Getopt::Long;

use File::Basename;

use Tie::IxHash;

use Data::Dumper;

use DBI;

use lib "$ENV{GUS_HOME}/lib/perl";

# my ($source_table);

# source_table= "ApidbTuning.AppNodeCharacteristics"

sub getCategoriesAndValues {
  my ($source_table,$dbh) = @_;
  my $selectStatement =  <<SQL;
							Select distinct type, category, ontology_term_source_id 
							from $source_table
							order by type
SQL
	
  my $selectRow = $dbh->prepare($selectStatement);
  $selectRow->execute() or die $dbh->errstr;
  
  my $appNodeCategories;
  
  my $getValuesSql =  <<SQL;
                                                      	Select distinct name, value
							from APPNODECHARACTERISTICS
							where type = ?
							and (     
                                                                 ontology_term_source_id = ? 
                                                                 or ( 
                                                                      category = ? and ontology_term_source_id is null
                                                                     ) 
                                                               )
SQL

  my $vh = $dbh->prepare($getValuesSql);
  
  my $allValuesHash = {};
  

  while(my ($type, $category, $ot_source_id) = $selectRow->fetchrow_array()) {
    my $valueHash = {};
    my $cleanCategory = cleanAttr($type,$category);

    if (exists ($appNodeCategories->{$type})) {
      my $categories = $appNodeCategories->{$type}->{'raw'};
      my $ot_source_ids = $appNodeCategories->{$type}->{'ot_source_id'};
      unless (grep( /^$category$/, @$categories )) {
        my $cleanCategories = $appNodeCategories->{$type}->{'clean'};
        next unless $cleanCategory=~/\w/;
        push (@$cleanCategories, $cleanCategory);
        push (@$categories,$category);
        push (@$ot_source_ids,$ot_source_id);
      }
    }
    else {
      print $category."raw \n";
      my $cleanCategory = cleanAttr($type,$category);
      print $cleanCategory."clean \n";
      $appNodeCategories->{$type}->{'raw'} = [ $category ];
      $appNodeCategories->{$type}->{'clean'} = [ $cleanCategory ];
      $appNodeCategories->{$type}->{'ot_source_id'} = [ $ot_source_id ] 
    }
    $vh->execute($type,$ot_source_id,$category) or die $dbh->errstr;
    my $values = [];
    my ($name, $value);
    while (($name,$value) = $vh->fetchrow_array()) {
      next unless ($name=~/\w/);
      if (exists ($allValuesHash->{$type}->{$name}->{$category} )){
        $values = $allValuesHash->{$type}->{$name}->{$category};
        push @$values, $value;
        if ($ot_source_id =~/^\W$/) {
          $values = $allValuesHash->{$type}->{$name}->{$ot_source_id} ;
          push @$values, $value;  
        }

      }
      else {
        $allValuesHash->{$type}->{$name}->{'name'} = $name;
        $allValuesHash->{$type}->{$name}->{$category} = [ $value ];
        $allValuesHash->{$type}->{$name}->{$ot_source_id} = [ $value ] if ($ot_source_id =~/^\W$/);
      }
    }
  }

  $selectRow->finish();
  $vh->finish();
          #print STDERR Dumper ($appNodeCategories);

          #print STDERR Dumper ($allValuesHash);
  return ($appNodeCategories,$allValuesHash);
}

sub cleanAttr {
  my ($type,$attribute) = @_;
  $attribute =~ s/'/''/g;
  $attribute =~ s/ /_/g;
  $attribute =~ s/-/_/; 
  $attribute =~ s/^\#/num/;
  $attribute =~ s/\W+/_/g;
  $attribute =~ s/_+/_/g;
  $attribute =~ s/^sum_number_of_female_anophele/sum_female_A/;
  $attribute =~ s/^average_asexual_parasite_density_of_a_participant_with/avg_parasite_density_/;
  $attribute =~ s/^average_number_of_clinical_visits_with/avg_annual_visits_with_/;
  $attribute =~ s/^number_of_clinical_visits_resulting_in/num_visits_with_/;
  $attribute =~ s/^number_of_/num_/;

  # my $old_parent_id_string = "parent_id";
  # my $parent_id_string = "parent_id";
  # if ($type=~/person/i) {
  #   $parent_id_string = "hhid";
  # }
  # if ($type=~/clinical.?visit/i) {
  #   $parent_id_string = "participant_id";
  # }
  # elsif ($type=~/light.?trap/i) {
  #   $parent_id_string = "hhid";
  # }
  # $attribute=~ s/^$attribute$/$parent_id_string/i if $attribute=~$old_parent_id_string;
  if (length($attribute) > 29) {
    $attribute = substr($attribute, 0, 29);
  }
  return $attribute
}

1; 
