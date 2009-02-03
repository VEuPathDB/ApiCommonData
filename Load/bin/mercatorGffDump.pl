#!/usr/bin/perl

use strict;
use DBI;
use Bio::Tools::GFF;
use Bio::SeqFeature::Gene::Exon;
use CBIL::Util::PropertySet;

#----------------Get UID and PWD/ database handle---------------

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

my $dbh = DBI->connect($dsn, $u, $pw) ||  die "Couldn't connect to database: " . DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

#------------------------------


my $TaxonQuery = &GetTaxonQuery;
my %SpeciesHash = &GetTaxonID(\$dbh,$TaxonQuery);

foreach my  $Taxon_ID (keys (%SpeciesHash)) {

  my $Organism = $SpeciesHash{$Taxon_ID};
  $Organism =~ s/ /_/g;

  print("Preparing to export exons for $Organism...\n");
  my $ExonQuery = &GetExonQuery($Taxon_ID);
  
  &ExportToGFF(\$dbh,$ExonQuery,$Organism);

  print("Finished exporting exons for $Organism...preparing to export CDS for $Organism\n");
  my $CDSQuery = &GetCDSQuery($Taxon_ID);
  
  &ExportToGFF(\$dbh,$CDSQuery,$Organism);
  print("Finsihed exporting CDS for $Organism..\n");
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




#----Execute Query  and send results to GFF-----#
sub ExportToGFF {

  my ($handle,$query,$species) = @_;
  my $rowcount = 0;

  my $sth = $$handle->prepare($query) || die "Couldn't prepare the SQL statement: " . $$handle->errstr;
  $sth->execute ||  die "Failed to  execute statement: " . $sth->errstr;
 
  $rowcount = &WriteGFF(\$sth,$species);

  print ("0 rows were returned by the query:\n $query \n") unless $rowcount > 0;
}




#---------Write information in GFF format-------
sub WriteGFF {

  my ($StatementHandle,$species) = @_;
  my $GFFFile = "$species.gff";
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
                                                           -tag          => {ID => $Recordrow[8]}
                                                          );
    my $GFFString = new  Bio::Tools::GFF(-file => ">>$GFFFile",  -gff_version => 1);
    $GFFString->write_feature($SequenceFeature);
    $rowcount++;
  }
   
  $$StatementHandle->finish;
  close ($GFFFile);

  return($rowcount);
}



#--------QUERIES-----------------#

sub GetTaxonQuery {

  return ("SELECT distinct ga.organism as organism, nas.taxon_id as taxon_id
           FROM   apidb.geneattributes ga,dots.nasequence nas
           WHERE  ga.na_sequence_id = nas.na_sequence_id");
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
                  ef.source_id as gff_group
           FROM   DoTS.ExonFeature ef,
                  ApiDB.FeatureLocation nl,
                  DoTS.NaSequence ns
           WHERE  ef.na_feature_id = nl.na_feature_id
           AND    nl.is_top_level = 1
           AND    nl.na_sequence_id = ns.na_sequence_id
           AND    ns.taxon_id in ($TaxonID)
           ORDER BY ef.order_number");
}

sub GetCDSQuery {

  my ($TaxonID) = @_;
  return ("SELECT ns.source_id as gff_seqname,
                  'ApiDB' as gff_source,
                  'CDS' as gff_feature, 
                  least(nl.start_min, nl.end_max) as gff_start,
                  greatest(nl.start_min, nl.end_max) as gff_end,
                  '.' as gff_score,
                  decode(nl.is_reversed, 1, '-', '+') as gff_strand,
                  '.'  as gff_frame,
                  ef.source_id as gff_group
           FROM   DoTS.GeneFeature gf,
                  DoTS.Transcript rna,
                  DoTS.ExonFeature ef,
                  apidb.FeatureLocation nl,
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
           ORDER BY ef.order_number");
}
