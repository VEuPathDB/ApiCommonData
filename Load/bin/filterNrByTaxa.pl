#!/usr/bin/perl

use strict;


use lib $ENV{GUS_HOME} . "/lib/perl";

use Getopt::Long;

use DBI;
use DBD::Oracle;

use CBIL::Util::PropertySet;

use Data::Dumper;

my ($help, $nrFile, $gusConfigFile, $taxaFilter, $outputFile);

&GetOptions('help|h' => \$help,
#            'gi2taxidFile=s' => \$gi2taxidFile,
            'nrFile=s' => \$nrFile,
            'gusConfigFile=s' => \$gusConfigFile,
            'taxaFilter=s' => \$taxaFilter,
            'outputFile=s' => \$outputFile, 
            );

##Create db handle
if(!$gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
}

die "Config file $gusConfigFile does not exist." unless -e $gusConfigFile;

die "nr file does not exist" unless -e $nrFile;

die "must filter by some taxon" unless $taxaFilter;


open(OUTPUT, ">$outputFile") or die "Cannot open file $outputFile for writing: $!";

my @properties;
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $dbiDsn = $gusconfig->{props}->{dbiDsn};
my $dbiUser = $gusconfig->{props}->{databaseLogin};
my $dbiPswd = $gusconfig->{props}->{databasePassword};

my $dbh = DBI->connect($dbiDsn, $dbiUser, $dbiPswd) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

$taxaFilter =~ s/\'//g;
my $formattedTaxa = join(",", map {"'" . $_ . "'" } split(/\s?,\s?/, $taxaFilter));

my $taxonSql = "select tn.name
from sres.taxon t, sres.taxonname tn
where t.taxon_id = tn.taxon_id
and tn.name_class = 'scientific name'
start with t.taxon_id in (select distinct taxon_id from sres.taxonname where name in ($formattedTaxa))
connect by prior t.taxon_id = t.parent_id";

# my $taxonSql = "select ncbi_tax_id
# from sres.taxon t
# start with taxon_id in (select distinct taxon_id from sres.taxonname where name in ($formattedTaxa))
# connect by prior taxon_id = parent_id";

my %taxa;

my $sh = $dbh->prepare($taxonSql);
$sh->execute();
while(my ($taxname) = $sh->fetchrow_array()) {
  $taxa{$taxname} = 1;
}
$sh->finish();
$dbh->disconnect();

# if ($gi2taxidFile =~ m/\.gz$/) {
#   open(GI2TAXID, "gunzip -c $gi2taxidFile |") or die $!;
# }
# else {
#   open(GI2TAXID, "<$gi2taxidFile") or die $!;
# }

# my %keep;
# my $count;
# while (<GI2TAXID>) {
#   chomp;
#   my ($gi, $ncbiTaxonId) = split(/\t/, $_, 2);

#   if($taxa{$ncbiTaxonId}) {
#     $keep{$gi} = 1;
#     $count++;
#   }
# }
# close GI2TAXID;
# print "Counted $count gi lines with taxa matching the filter\n";

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


1;
