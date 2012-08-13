#!/usr/bin/perl
use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;

my $gusConfigFile;

&GetOptions( "gusConfigFile=s" => \$gusConfigFile);

die "usage: getValueFromTable --gusConfigFile [\$GUS_CONFIG_FILE]\n" unless $gusConfigFile;

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        0,0,1,
                                        $gusconfig->getCoreSchemaName());

my $dbh = $db->getQueryHandle();

my $sql =<<EOL;
SELECT ga.source_id ,
       ga.na_sequence_id ,
       fl.start_min ,
       fl.end_max ,
       ga.product , 
       ga.so_term_name, 
       ga.is_deprecated,
       ga.organism, 
       ga.is_pseudo,
       ga.gene_type,
       ga.ec_numbers,
       ga.name
FROM   ApidbTuning.GeneAttributes ga, 
       ApidbTuning.FeatureLocation fl
WHERE  fl.na_feature_id = ga.na_feature_id
ORDER BY fl.start_min
EOL

my $sth = $dbh->prepareAndExecute($sql);

while(my $arr = $sth->fetchrow_arrayref()){
   my($id, $na_seq_id, $start, $end, $product, $so, $deprecated, $organism, $pseudo, $genetype, $ec_number, $name) = @$arr;
   
   my $product_type = 'P';

   if($genetype =~ /rRNA encoding/i) {
     $product_type = 'RRNA';
   } elsif($genetype =~ /tRNA encoding/i) {
     $product_type = 'TRNA';
   } elsif($genetype =~ /non protein coding/i) {
     $product_type = 'P';
   } elsif($genetype =~ /snRNA encoding/i) {
     $product_type = 'MISC-RNA';
   } elsif($genetype =~ /protein coding/i) {
     $product_type = 'P';
   } elsif($genetype =~ /snoRNA encoding/i) {
     $product_type = 'MISC-RNA';
   }

   $product_type = 'PSEUDO' if $pseudo;

   my $pf =<<EOL;
ID:\t$id
NAME:\t$name
STARTBASE:\t$start
ENDBASE:\t$end
FUNCTION:\t$product
PRODUCT-TYPE:\t$genetype
EC:\t$ec_number
GO:\t$so
EOL

  print $pf;

}

$sth->finish();
$dbh->disconnect();
