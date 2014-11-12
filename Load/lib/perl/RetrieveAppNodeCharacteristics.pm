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
							Select distinct type, category 
							from $source_table
							order by type
SQL
	
	my $selectRow = $dbh->prepare($selectStatement);
	$selectRow->execute() or die $dbh->errstr;
	
	my $appNodeCategories;

	my $getValuesSql =  <<SQL;
							Select distinct source_id, name, value
							from $source_table
							where type = ?
							and category = ?
SQL

	my $vh = $dbh->prepare($getValuesSql);

	my $allValuesHash = {};


	while(my ($type, $category) = $selectRow->fetchrow_array()) {
		my $valueHash = {};
		my $cleanCategory = cleanAttr($category);
		if (exists ($appNodeCategories->{$type})) {
			my $categories = $appNodeCategories->{$type}->{'raw'};
			unless (grep( /^$category$/, @$categories )) {
				my $cleanCategories = $appNodeCategories->{$type}->{'clean'};
				push (@$cleanCategories, $cleanCategory);
				push (@$categories,$category);
			}
		}
		else {
			my $cleanCategory = cleanAttr($category);
			$appNodeCategories->{$type}->{'raw'} = [ $category ];
			$appNodeCategories->{$type}->{'clean'} = [ $cleanCategory ];
		}
		$vh->execute($type,$category) or die $dbh->errstr;
		my $values = [];
		my ($source_id, $name, $value);
		while (($source_id,$name,$value) = $vh->fetchrow_array()) {
			if (exists ($allValuesHash->{$type}->{$source_id}->{$category} )){
				$values = $allValuesHash->{$type}->{$source_id}->{$category};
				push @$values, $value;
			}
			else {
				$allValuesHash->{$type}->{$source_id}->{'name'} = $name;
				$allValuesHash->{$type}->{$source_id}->{$category} = [ $value ];
			}
		}
	}

	$selectRow->finish();
	$vh->finish();
	return ($appNodeCategories,$allValuesHash);
}

sub cleanAttr {
  my ($attribute) = @_;
  $attribute =~ s/'/''/g;
  $attribute =~ s/ /_/g;
  $attribute =~ s/-/_/; 
  $attribute =~ s/\W+/_/g;
  if (length($attribute) > 29) {
    $attribute = substr($attribute, 0, 29);
  }
  return $attribute
}
     
1; 
