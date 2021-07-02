#!/usr/bin/perl

use strict;
use Getopt::Long;
use GUS::Supported::GusConfig;
use Data::Dumper;


my ($propNameToCheck, $help);

&GetOptions(
            'propNameToCheck=s' => \$propNameToCheck,
            'help|h' => \$help
            );

&usage() if ($help);
#&usage("Missing a Required Argument") unless (defined $propNameToCheck);

my %xmlFiles = (
		       AmoebaDB => 'AmoebaDB.xml',
		       CryptoDB => 'CryptoDB.xml',
		       FungiDB => 'FungiDB.xml',
		       GiardiaDB => 'GiardiaDB.xml',
		       HostDB => 'HostDB.xml',
		       MicrosporidiaDB => 'MicrosporidiaDB.xml',
		       PiroplasmaDB => 'PiroplasmaDB.xml',
		       PlasmoDB => 'PlasmoDB.xml',
		       SchistoDB => 'SchistoDB.xml',
		       ToxoDB => 'ToxoDB.xml',
		       TrichDB => 'TrichDB.xml',
		       TriTrypDB => 'TriTrypDB.xml',
		       VectorBase => 'VectorBase.xml'
);

my %propValues;

my @propNames = ($propNameToCheck) ? ($propNameToCheck) : qw(organismAbbrev ncbiTaxonId orthomclAbbrev);

foreach my $propName (@propNames) {
  print STDERR "checking prop name: $propName ...\n";

  foreach my $k (sort keys %xmlFiles) {
    print STDERR "  processing $xmlFiles{$k} " if ($propNameToCheck);

#    my $xmlFile = "\$PROJECT_HOME\/ApiCommonDatasets\/Datasets\/lib\/xml\/datasets\/".$xmlFiles{$k};
    my $xmlFile = $xmlFiles{$k};

    my $inClass = 0;
    open (IN, "$xmlFile") || die "can not open $xmlFile to read\n";
    while (<IN>) {
      if ($_ =~ /<dataset class=\"organism\">/) {
	$inClass = 1;
      } elsif ($_ =~ /<\/dataset>/) {
	$inClass = 0;
      }

      if ($_ =~ /<prop name=\"$propName\">(\S+?)<\/prop>/ && $inClass == 1) {
	my $v = $1;
	if ($propValues{$v}) {
	  print STDERR "ERROR ... duplicated value found for $propName at $xmlFiles{$k} for '$v'\n";
	} else {
	  print STDERR ".";
	  $propValues{$v} = 1;
	}
      }
    }
    close IN;
    print STDERR "\n";
  }
}



############

sub usage {
  die
"
A script to check if the prop organismAbbrev, ncbiTaxonId, or orthomclAbbrev is unique in the dataset xml file

Usage: perl checkDatasetsXmlUniqueProp.pl --propNameToCheck orthomclAbbrev
please run the script under the dir: ApiCommonDatasets/Datasets/lib/xml/datasets/

where:
  --propNameToCheck: optional. e.g. organismAbbrev, ncbiTaxonId, or orthomclAbbrev
                     default is for organismAbbrev, ncbiTaxonId and orthomclAbbrev

";
}
