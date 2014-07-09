#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | broken
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | broken
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use DBI;
use Bio::Tools::GFF;
use Bio::SeqFeature::Gene::Exon;
use CBIL::Util::PropertySet;
use Getopt::Long;

#----------------Get UID and PWD/ database handle---------------

my ($verbose,$gusConfigFile,$outputDir,$organism,$outputFile,$tuningTablePrefix);

&GetOptions("verbose!" => \$verbose,
            "outputDir=s" => \$outputDir,
            "gusConfigFile=s" => \$gusConfigFile,
            "organism=s" => \$organism,
	    "tuningTablePrefix=s" => \$tuningTablePrefix,
	    "outputFile=s" => \$outputFile);


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


my ($species,$GFFFile,$GFFString);


#------------------------------


my $TaxonQuery = &GetTaxonQuery($organism);
my %SpeciesHash = &GetTaxonID(\$dbh,$TaxonQuery);

my $count;
foreach my  $Taxon_ID (keys (%SpeciesHash)) {

  $species = $SpeciesHash{$Taxon_ID};
  $species =~ s/ /_/g;

  if($outputFile){
      $GFFFile = "$outputFile";
  }else{
      $GFFFile = "$outputDir/$species.gff";
  }

  $GFFString = new  Bio::Tools::GFF(-file => ">$GFFFile",  -gff_version => 3);

  print("Preparing to export exons for $species...\n");
  my $ExonQuery = &GetExonQuery($Taxon_ID);
  &ExportToGFF(\$dbh,$ExonQuery);

  print("Finished exporting exons for $species...preparing to export CDS for $species\n");
  my $CDSQuery = &GetCDSQuery($Taxon_ID);
  
  &ExportToGFF(\$dbh,$CDSQuery);
  print("Finsihed exporting CDS for $species..\n");
  close($GFFFile);
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

  print ("0 rows were returned by the query to find Taxon IDs:\n $query \n") unless $rowcount > 0;

  return %TaxonHash;
}




#----Execute Query  and send results to GFF-----#
sub ExportToGFF {

  my ($handle,$query) = @_;
  my $rowcount = 0;

  my $sth = $$handle->prepare($query) || die "Couldn't prepare the SQL statement: " . $$handle->errstr;
  $sth->execute ||  die "Failed to  execute statement: " . $sth->errstr;
 
  $rowcount = &WriteGFF(\$sth,$species);

  print ("0 rows were returned by the query:\n $query \n") unless $rowcount > 0;
}




#---------Write information in GFF format-------
sub WriteGFF {

  my ($StatementHandle) = @_;

  my $rowcount = 0;

  while (my  @Recordrow = $$StatementHandle->fetchrow_array) {
    my $SequenceFeature = Bio::SeqFeature::Gene::Exon->new(-seq_id       => $Recordrow[0],
                                                           -start        => $Recordrow[3], 
                                                           -end          => $Recordrow[4],
                                                           -strand       => $Recordrow[6], 
                                                           -frame        => $Recordrow[7],
                                                           -primary      => $Recordrow[2],
                                                           -source_tag   => $Recordrow[1],
                                                           -display_name => $Recordrow[8],
                                                           -score        => $Recordrow[5],
                                                           -tag          => {ID => $Recordrow[8], parent => $Recordrow[9]}
                                                          );

    $GFFString->write_feature($SequenceFeature);
    $rowcount++;
  }
   
  $$StatementHandle->finish;


  return($rowcount);
}



#--------QUERIES-----------------#

sub GetTaxonQuery {
    
    my($organism) = @_;

  my $sql = "SELECT distinct ga.organism as organism, nas.taxon_id as taxon_id
           FROM   ApidbTuning.${tuningTablePrefix}GeneAttributes ga,dots.nasequence nas
           WHERE  ga.na_sequence_id = nas.na_sequence_id";

    if($organism){

	$sql .= " AND ga.organism = '$organism'";
    }
  
  return ($sql);
}


sub GetExonQuery {

  my ($TaxonID) = @_;

  return ("SELECT ns.source_id as gff_seqname,
                  'ApiDB' as gff_source,
                  'exon' as gff_feature,
                  least(nl.start_min, nl.end_max) as gff_start,
                  greatest(nl.start_min, nl.end_max) as gff_end,
                  '.' as gff_score,
                  decode(nl.is_reversed, 1, '-', '+') as gff_strand,
                  '.' as gff_frame,
                  ef.source_id as feature_id,
                  regexp_replace(ef.source_id, '-[[:digit:]]+\$', '') as gene_source_id
           FROM   DoTS.ExonFeature ef,
                  ApidbTuning.${tuningTablePrefix}FeatureLocation nl,
                  ApidbTuning.${tuningTablePrefix}GeneAttributes ga,
                  DoTS.NaSequence ns
           WHERE  ef.na_feature_id = nl.na_feature_id
           AND    nl.is_top_level = 1
           AND    nl.na_sequence_id = ns.na_sequence_id
           AND    ns.taxon_id in ($TaxonID)
           AND    nl.parent_id=ga.na_feature_id
           AND    ga.gene_type='protein coding'
           ORDER BY ef.source_id,ef.order_number");
}

sub GetCDSQuery {

  my ($TaxonID) = @_;

  return ("SELECT ns.source_id as gff_seqname,
                  'ApiDB' as gff_source,
                  'CDS' as gff_feature, 
                   least(nl.coding_start, nl.coding_end) as gff_start,
                   greatest(nl.coding_start, nl.coding_end) as gff_end,
                   '.' as gff_score,
                   decode(nl.is_reversed, 1, '-', '+') as gff_strand,
                   mod(3 - mod((select nvl(sum(greatest(ef2.coding_start, ef2.coding_end)
                                               - least(ef2.coding_start, ef2.coding_end) +1
                                               ), 0)
                        from dots.ExonFeature ef2
                        where parent_id = ef.parent_id
                          and order_number < ef.order_number), 3), 3) as gff_frame,
                  ef.source_id as feature_id,
                  gf.source_id as gene_source_id
           FROM   DoTS.GeneFeature gf,
                  DoTS.Transcript rna,
                  DoTS.ExonFeature ef,
                  ApidbTuning.${tuningTablePrefix}FeatureLocation nl,
                  DoTS.NaSequence ns,
                  sres.SequenceOntology so,
                  dots.RnaFeatureExon rfe
           WHERE  gf.na_feature_id = rna.parent_id
           AND    rna.na_feature_id = rfe.rna_feature_id
           AND    ef.na_feature_id = rfe.exon_feature_id
           AND    ef.na_feature_id = nl.na_feature_id
           AND    nl.is_top_level = 1
           AND    nl.na_sequence_id = ns.na_sequence_id
           AND    ef.coding_start is not null
           AND    ef.coding_start != -1
           AND    ef.coding_end is not null
           AND    ef.coding_end != -1
           AND    gf.sequence_ontology_id = so.sequence_ontology_id
           AND    so.term_name in ('protein_coding', 'repeat_region')
           AND    ns.taxon_id in ($TaxonID)
           ORDER BY ef.source_id,ef.order_number");
}
