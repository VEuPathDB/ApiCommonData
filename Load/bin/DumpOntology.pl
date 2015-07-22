#!/usr/bin/perl

use strict;

use warnings;

use Getopt::Long;

use File::Basename;

use Data::Dumper;

use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;

use List::MoreUtils qw(uniq);

use GUS::PluginMgr::Plugin;

use Date::Parse;

my ($inFile, $configFile, $outFile, $help);

&GetOptions('help|h' => \$help,
            'configFile=s' => \$configFile,
           );

#&usage() if($help);
#&usage("Input dir containing csv files is required") unless(-e $inDir);
#&usage("Output file name is required") unless($outFile);

my $mapHash = {};




my $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};
my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;

my $valuesSql =<<SQL;

select distinct category, value from apidbtuning.appNodeCharacteristics

SQL

my $sh = $dbh->prepare($valuesSql);
$sh->execute();

my $valuesArray= $sh->fetchall_arrayref();

$sh->finish();

my $parentsSql =<<SQL;

select distinct parent_term,term from apidbtuning.preferredParentTerms

SQL

my $ph = $dbh->prepare($parentsSql);
$ph->execute();

my $parentsArray= $ph->fetchall_arrayref();

$ph->finish();


my $valuesHash = {};
foreach my $row (sort(@$valuesArray)) {
  my $category =$row->[0];
  my $value = $row->[1];
  if (defined $value && $value =~ /\w/){
    if (exists $valuesHash->{$category} ) {
      push @{$valuesHash->{$category}}, $value;
    }
    else {
      $valuesHash->{$category} = [$value];
    }
  }
}
my $parentHash;
foreach my $row (sort(@$parentsArray)) {
  my $parent =$row->[0];
  my $term = $row->[1];
  $parentHash->{$term} = $parent;
}

my $output;
foreach my $category (keys %$valuesHash) {
  my @values = @{$valuesHash->{$category}};
  my @NonNumericValues =Dumper grep { $_=~ /[a-zA-Z]/ } @values;

  
  my $value_string;
  if (scalar (@NonNumericValues) == 0) {

    my ($min, $max);
    for (@values) {
      $min = $_ if !$min || $_ < $min;
      $max = $_ if !$max || $_ > $max;
    }
    $value_string = "$min - $max";
  }
  else {
    $value_string = join(" , " , @values);
  }
  $output->{$category} = $value_string;
}
my $hierarchy = {};

foreach my $term (keys %$valuesHash) {
  $hierarchy = getParents($term,$parentHash,$hierarchy);
  
}
#print STDERR Dumper $valuesOutput;

exit;

sub getParents {
  my ($term, $parentHash, $hierarchy) = @_;
  my $parent=undef;
  if (exists $parentHash->{$term}) {
    $parent = $parentHash->{$term};
    print STDERR "parent : $parent, term : $term\n";
    if (exists $hierarchy->{$parent}) {
      $hierarchy->{$parent}->{$term} = undef;
     # print STDERR Dumper $hierarchy;
      return ($parent,$hierarchy);
    }
    ($parent,$hierarchy) = getParents($parent, $parentHash, $hierarchy);
  }
  else {
    print STDERR $term."\n";
    print STDERR Dumper $hierarchy;
    $hierarchy->{$term} = undef;
    return ("top", $hierarchy);
  }
}
