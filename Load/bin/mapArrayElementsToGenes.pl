#!/usr/bin/perl

use strict;
use Getopt::Long;
use IO::File;
use DBI;
use CBIL::Util::PropertySet;

#--Usage/Example---------------------------
#-   perl   mapArrayElementsToGenes.pl    --aefExtDbRlsId 2241   --exonExtDbRlsId 361
#-----------------------------------------


#------- Uid, Password and dsn ..these are fetched from the gus.config file----------

my ($gusConfigFile);
$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless(-e $gusConfigFile) {
  print STDERR "gus.config file not found! \n";
  exit;
}


my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};
my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;

#----------------------------------------------------------------------------
        
my ($exonExtDbRlsId,$aefExtDbRlsId);

&GetOptions('aefExtDbRlsId=s' => \$aefExtDbRlsId,
            'exonExtDbRlsId=s' => \$exonExtDbRlsId,
	   );

die "ERROR: Please provide a valid External Database Release ID for the Array Element Features"  unless ($aefExtDbRlsId);
die "ERROR: Please provide a valid External Database Release ID for Exon Features" unless ($exonExtDbRlsId);

my $sql = "select ga.source_id as gene_source_id,  apidb.tab_to_string(CAST(COLLECT(aef.source_id) AS apidb.varchartab), ', ') as array_features
from dots.exonfeature ef, DOTS.arrayelementfeature aef, apidb.featurelocation fl,apidb.geneattributes ga
where ef.external_database_release_id = $exonExtDbRlsId
and aef.external_database_release_id = $aefExtDbRlsId
and aef.na_feature_id = fl.na_feature_id
and aef.na_sequence_id = ef.na_sequence_id
and ef.parent_id = ga.na_feature_id
and ((ga.is_reversed = 0 and (fl.start_min < ef.coding_end and fl.end_max > ef.coding_start)) 
     or (ga.is_reversed = 1 and (fl.start_min < ef.coding_start and fl.end_max > ef.coding_end))
    )
group by ga.source_id";

my $sth = $dbh->prepare($sql);

$sth->execute || die "Could not execute SQL statement!";
   
   while( my ($gene,$aefList) = $sth->fetchrow_array() ){
           print("$gene\t$aefList\n"); 
   }



