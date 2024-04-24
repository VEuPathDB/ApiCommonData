#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";

use Getopt::Long;

use CBIL::Util::PropertySet;

my ($help, $nrFile, $gusConfigFile, $taxaFilter, $outputFile);

&GetOptions('help|h' => \$help,
            'nrdbFile=s' => \$nrFile,
            'taxaFilter=s' => \$taxaFilter,
            'outputFile=s' => \$outputFile, 
            );

die "nr file does not exist" unless -e $nrFile;

die "must filter by some taxon" unless $taxaFilter;

open(OUTPUT, ">$outputFile") or die "Cannot open file $outputFile for writing: $!";

$taxaFilter =~ s/\'//g;
my @formattedTaxa = split(/\s?,\s?/, $taxaFilter);


my %taxa;

foreach my $taxon (@formattedTaxa) {
  my $taxonByNameEdirect = &getEdirectTaxonomyCommand("${taxon}[Scientific Name]", "TaxId");

  my $ncbiTaxId = `$taxonByNameEdirect`;
  &checkExitStatus($?, $taxonByNameEdirect);

  if($ncbiTaxId) {
    my $scientificNamesForTaxonEdirect = &getEdirectTaxonomyCommand("txid${ncbiTaxId}[Subtree]", "ScientificName");

    my $scientificNamesString = `$scientificNamesForTaxonEdirect`;
    &checkExitStatus($?, $scientificNamesForTaxonEdirect);

    my @scientificNames = split(/\n/, $scientificNamesString);

    foreach my $scientificName(@scientificNames) {
      $taxa{${scientificName}} = 1;
    }
  }
  else {
    die "No NCBI Tax ID Found for $taxon";
  }
}

if ($nrFile =~ m/\.gz$/) {
  open(NR, "gunzip -c $nrFile |") or die $!;
}
else {
  open(NR, "<$nrFile") or die $!;
}

my $okToPrint = 0;

while(my $line = <NR>) {
  if($line =~ />/) {

    my @rowTaxa = ( $line =~ /\[(.*?)\]/g );

    my $match = 0;
    foreach(@rowTaxa) {
      if($taxa{$_}) {
        $match = 1;
        last;
      }
    }
    $okToPrint = $match ? 1 : 0;
  }
  else {
    $line =~ s/J|O/X/g if ($okToPrint); #remove non standard amino acids
  }

  print OUTPUT $line if ($okToPrint);
}

close NR;


sub checkExitStatus {
  my ($e, $cmd) = @_;
  my $exit_code = $e >> 8; # right shift to get the actual exit value

  if ($exit_code != 0) {
    die "Command failed with exit code $exit_code:  $cmd\n";
  }
}

sub getEdirectTaxonomyCommand {
  my ($query, $element) = @_;

  my $edirect = "esearch -db taxonomy -query '$query' | efetch -format xml | xtract -pattern TaxaSet -block '*/Taxon' -tab '\n' -element $element";

  return "apptainer run docker://veupathdb/edirect /bin/bash -c \"${edirect}\"";

}

1;
