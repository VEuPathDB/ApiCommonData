#!/usr/bin/perl

use strict;
use DBI;
use Bio::SeqFeature::Gene::Exon;
use CBIL::Util::PropertySet;
use Getopt::Long;

#----------------Get UID and PWD/ database handle---------------

my ($verbose,$gusConfigFile,$outputDir,$organism,$fileNamePrefix);

&GetOptions("verbose!" => \$verbose,
            "outputDir=s" => \$outputDir,
            "gusConfigFile=s" => \$gusConfigFile,
            "organism=s" => \$organism,
	    "file_name_prefix=s" => \$fileNamePrefix,
	    );


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

my $dbh = DBI->connect($dsn, $u, $pw) ||  die "Couldn't connect to database: " . DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;


my ($species,$indexFile,$geneFastaFile,$seqFastaFile);


#------------------------------


my $TaxonQuery = &GetTaxonQuery($organism);
my %SpeciesHash = &GetTaxonID(\$dbh,$TaxonQuery);

foreach my  $Taxon_ID (keys (%SpeciesHash)) {

  $species = $SpeciesHash{$Taxon_ID};
  $species =~ s/ /_/g;

  if($fileNamePrefix){
      $indexFile = "$outputDir/$fileNamePrefix.txt";
      $geneFastaFile = "$outputDir/${fileNamePrefix}_gene.fsa";
      $seqFastaFile = "$outputDir/${fileNamePrefix}_seq.fsa";

  }else{
      $indexFile = "$outputDir/$species.txt";
      $geneFastaFile = "$outputDir/$species.fsa";
      $seqFastaFile = "$outputDir/$species.fsa";

  }

   open(OUTINDX,">$indexFile");
   open(OUTGENE,">$geneFastaFile");
   open(OUTSEQ,">$geneFastaFile");


  print("Preparing to export genes for $species...\n");

  my $GeneQuery = &GetGeneQuery($Taxon_ID);

      my $handle;
  my $sth = $$handle->prepare($GeneQuery) || die "Couldn't prepare the SQL statement: " . $$handle->errstr;  
  $sth->execute ||  die "Couldn't execute statement: " . $sth->errstr;


  while (my  $resultset = $sth->fetchrow_hashref) {

      print OUTINDX $resultset->{SEQUENCE_ID}."\t".$resultset->{STRAND}."\t".$resultset->{START_MIN}."\t".$resultset->{END_MAX}."\t".$resultset->{EXON_COUNT}."\t";

      my $ExonQuery = &GetExonQuery($resultset->{NA_FEATURE_ID});
  
      my $handle2;
       my $sth2 = $$handle2->prepare($ExonQuery) || die "Couldn't prepare the SQL statement: " . $$handle2->errstr;  
      $sth2->execute ||  die "Couldn't execute statement: " . $sth2->errstr;


      my ($exonStarts,$exonEnds);
      while (my  $resultset2 = $sth2->fetchrow_hashref) {
	  $exonStarts .= $resultset2->{START_MIN}.",";
	  $exonEnds .= $resultset2->{END_MAX}.",";
      }

      print OUTINDX "$exonStarts\t$exonEnds\t".$resultset->{SOURCE_ID}."\n";

  }

      close(OUTINDX);

 
}

$dbh->disconnect;



#----------SUBROUTINES------------------#


#-----Fetch taxon ID for each organism-----------#
sub GetTaxonID { 

  my ($handle,$query) = @_;
  my %TaxonHash;
  my $rowcount =0;

  my $sth = $$handle->prepare($query) || die "Couldn't prepare the SQL statement: " . $$handle->errstr;  
  $sth->execute ||  die "Couldn't execute statement: " . $sth->errstr;


  while (my  $resultset = $sth->fetchrow_hashref) {   
    $TaxonHash {$resultset->{TAXON_ID}} = $resultset->{ORGANISM};
    $rowcount++; 
  }
   
  $sth->finish;

  print ("0 rows were returned by the query:\n $query \n") unless $rowcount > 0;

  return %TaxonHash;
}




#


#--------QUERIES-----------------#

sub GetTaxonQuery {
    
    my($organism) = @_;

  my $sql = "SELECT distinct ga.organism as organism, nas.taxon_id as taxon_id
           FROM   apidb.geneattributes ga,dots.nasequence nas
           WHERE  ga.na_sequence_id = nas.na_sequence_id";

    if($organism){

	$sql .= " AND ga.organism = '$organism'";
    }
  
  return ($sql);
}



sub GetGeneQuery {

  my ($TaxonID) = @_;

  return ("SELECT sequence_id,
                  source_id,
                  na_feature_id,
                  start_min -1,
                  end_max,
                  decode(nl.is_reversed, 1, '-', '+') as strand, 
                  exon_count

           FROM   ApiDB.GeneAttributes,
                 
           WHERE  
                   taxon_id in ($TaxonID)
           ORDER BY chromosome_order_num,sequence_id,start_min,end_max,source_id");
  


}
sub GetExonQuery {

  my ($parentID) = @_;

  return ("SELECT 
                  start_min,
                  end_max
           FROM   ApiDB.FeatureLocation

           WHERE  feature_type='ExonFeature'
           AND parent_id in ($parentID)
           ORDER BY start_min,end_max");
}




sub extractGenomeNaSequences {
  my ($taxonId, $table, $sequenceOntology) = @_;


  $table = "Dots." . $table;


=pod
  foreach my $genome (@{$mgr->{genomeNaSequences}->{$species}}) {
    my $dbName =  $genome->{name};
    my $dbVer =  $genome->{ver};

    my $name = $dbName;
    $name =~ s/\s/\_/g;

    my $dbRlsId = &getDbRlsId($mgr,$dbName,$dbVer);

    my $genomeFile = "$mgr->{dataDir}/seqfiles/${name}GenomeNaSequences.fsa";

    my $logFile = "$mgr->{myPipelineDir}/logs/$signal.log";

    my $sql = "select x.na_sequence_id, x.description,
            'length='||x.length,x.sequence
             from $table x, sres.sequenceontology s
             where x.taxon_id = $taxonId
             and x.external_database_release_id = $dbRlsId
             and x.sequence_ontology_id = s.sequence_ontology_id
             and lower(s.term_name) = '$sequenceOntology'";

    my $cmd = "gusExtractSequences --outputFile $genomeFile --idSQL \"$sql\" --verbose 2>> $logFile";

    $mgr->runCmd($cmd);
=cut

}
