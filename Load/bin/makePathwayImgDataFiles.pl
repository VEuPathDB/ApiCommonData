#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | broken
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | broken
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | broken
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

## To make the xgmml data files for pathway images, drawn via Cytoscape Web

use strict;
use DBI;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::PropertySet;
use Getopt::Long;
use XML::Writer;
use IO::File;

my ($outDir, $pathwayList,
    $gusConfigFile, $debug, $verbose, $projectId);

&GetOptions("outputDir=s" => \$outDir,
            "pathwayList=s" => \$pathwayList,
	    "verbose!" => \$verbose,
            "gusConfigFile=s" => \$gusConfigFile,
	   );

if (!$outDir || !$pathwayList) {
  die ' USAGE: makePathwayImgDataFiles.pl -outputDir <outputDir> -pathwayList <pathwayList | ALL> '
      . " [--verbose] [--debug]"
      . " [--gusConfigFile  <config (default=\$GUS_HOME/config/gus.config)>]\n";
}

$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless(-e $gusConfigFile) {
  print STDERR "gus.config file not found! \n";
  exit;
}

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $usr = $gusconfig->{props}->{databaseLogin};
my $pwd = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

print "Establishing dbi login\n" if $verbose;
my $dbh = DBI->connect($dsn, $usr, $pwd) ||  die "Couldn't connect to database: " . DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;


# pathwayList param could be 'ALL' in which case all pathway files are to be made. Else it may be a
# comma-separated list of pathway Ids for which the files are needed.

my @pids; # pathway IDs
my $validFlag = 0;
if ($pathwayList eq 'ALL') {
  @pids =&getPathwayIds();
} else {
  @pids = split(",", $pathwayList);
}

print "Size of array of Pathway IDs is ".( $#pids +1)  . "\n\n" if $verbose;

foreach my $pathwayId (@pids) {
  print "Working for Pathway IDs: $pathwayId\n" if $verbose;
  $validFlag = 0;
  my $sql = &getNodesQuery($pathwayId);
  my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
  $sth->execute() ||  die "Couldn't execute statement: " . $sth->errstr;

  my %node;
  my %edge;

  while (my ($id, $display, $type, $glyph_type_id, $x, $y, $width, 
	     $cpdName, $cpdCID, $cpdSID, $ecDescription, $pathName) = $sth->fetchrow_array()) {
    $validFlag = 1;
    $node{$id}->{display} = $display;
    $node{$id}->{type} = $type;
    $node{$id}->{x} = $x;
    $node{$id}->{y} = $y;
    $node{$id}->{cpdName} = $cpdName;
    $node{$id}->{cpdCID} = $cpdCID;
    $node{$id}->{cpdSID} = $cpdSID;
    $node{$id}->{ecDescription} = $ecDescription;
    $node{$id}->{pathName} = ($pathName)? $pathName : $display; # $display needed if pathway not loaded in db (as for MPMP)

    if ($type eq 'enzyme') {
      print "Getting orgs for enzyme: $display\n" if $verbose;
      $node{$id}->{ecOrgs} = &getOrganismsQuery($display, "NOT");
      $node{$id}->{ecOrgsOrthomcl} = &getOrganismsQuery($display, "");
      print "Got orgs for enzyme: $display\n" if $verbose;
    }
  }

  my $sql = &getEdgesQuery($pathwayId);
  my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
  $sth->execute() ||  die "Couldn't execute statement: " . $sth->errstr;

  while (my ($source, $target, $direction) = $sth->fetchrow_array()) {
      $edge{$source. $target}->{source} = $source;
      $edge{$source. $target}->{target} = $target;
      $edge{$source. $target}->{dir} = $direction;
  }

  my $output = IO::File->new("> ".$outDir ."/".  $pathwayId . ".xgmml");
  my $writer = XML::Writer->new(OUTPUT => $output, DATA_MODE => "true", DATA_INDENT =>2);

  if ($validFlag ) {
      $writer->startTag("graph", "label"=>"Demo",
			"xmlns:dc"=>"http://purl.org/dc/elements/1.1/",
			"xmlns:xlink"=>"http://www.w3.org/1999/xlink",
			"xmlns:rdf"=>"http://www.w3.org/1999/02/22-rdf-syntax-ns#",
			"xmlns:cy"=>"http://www.cytoscape.org",
			"xmlns"=>"http://www.cs.rpi.edu/XGMML",
			"directed"=>"1"
	  );

      ## nodes
      for my $k (keys(%node) ){
	if (  $node{$k}->{type} eq 'map' ) {
	  $writer->startTag("node", "label" =>  $node{$k}->{pathName} , "id" => $k);
	} else {
	  $writer->startTag("node", "label" => $node{$k}->{display} , "id" => $k);
	}

	$writer->startTag("att", "name"=>"Type", "value"=>$node{$k}->{type}, "type"=>"string");
	$writer->endTag("att");


	if (  $node{$k}->{type} eq 'enzyme' ) {
	  $writer->startTag("att", "name"=>"Description", "value"=>$node{$k}->{ecDescription}, "type"=>"string");
	  $writer->endTag("att");
	} elsif (  $node{$k}->{type} eq 'compound') {
	  $writer->startTag("att", "name"=>"Description", "value"=>$node{$k}->{cpdName}, "type"=>"string");
	  $writer->endTag("att");
	  $writer->startTag("att", "name"=>"CID", "value"=>$node{$k}->{cpdCID}, "type"=>"string");
	  $writer->endTag("att");
	  $writer->startTag("att", "name"=>"SID", "value"=>$node{$k}->{cpdSID}, "type"=>"string");
	  $writer->endTag("att");

	} elsif (  $node{$k}->{type} eq 'map') {
	  $writer->startTag("att", "name"=>"Description", "value"=>$node{$k}->{display}, "type"=>"string");
	  $writer->endTag("att");
	}

	if (  $node{$k}->{type} eq 'enzyme' ) {
	  $writer->startTag("att", "name"=>"Organisms", "value"=>$node{$k}->{ecOrgs}, "type"=>"string");
	  $writer->endTag("att");
	  $writer->startTag("att", "name"=>"OrganismsInferredByOthoMCL", "value"=>$node{$k}->{ecOrgsOrthomcl}, "type"=>"string");
	  $writer->endTag("att");

	}

	$writer->startTag("graphics", 
			  "x" => $node{$k}->{x},
			  "y" => $node{$k}->{y}
			 );
	$writer->endTag("graphics");
	$writer->endTag("node");
      }

      ## edges
      my $ct =0;
      for my $k (keys(%edge) ){
	$writer->startTag("edge", "label"=>$ct,  "source" => $edge{$k}->{source}, 
			  "target" => $edge{$k}->{target} );
	if ( $edge{$k}->{dir} ) {
	  $writer->startTag("att", "name"=>"direction", "value"=>$edge{$k}->{dir}, "type"=>"string");
	  $writer->endTag("att");
	}
	$ct++;

	$writer->startTag("graphics",
			  "width"=>"1",
			  "fill"=>"#000000",
			  "cy:sourceArrow"=>"0",
			  "cy:targetArrow"=>"3"
			 );
	$writer->endTag("graphics");
	$writer->endTag("edge");
      }

      $writer->endTag("graph");

      $writer->end();
      $output->close();
    } # if ($validFlag )
  else {
    my $outFile = $outDir ."/".  $pathwayId . ".xgmml";
    system ("/bin/rm $outFile");
  }
}

$dbh->disconnect;


# get ALL the pathway Ids
sub getPathwayIds {
  my $sql = "SELECT source_id FROM APIDB.pathway";
  my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
  $sth->execute() ||  die "Couldn't execute statement: " . $sth->errstr;

  my @ids;
  while (my ($id) = $sth->fetchrow_array()) {
    push (@ids, $id);
  }
  return @ids;
}

# getNodes query with cpd_name AND gene_orgs
sub getNodesQuery {
    my $pathwayId = shift;
    my $sql = "
SELECT  distinct nn.identifier, pn.display_label, 
         CASE WHEN pathway_node_type_id =1 THEN 'enzyme' 
                    WHEN  pathway_node_type_id =2 THEN 'compound' 
                    ELSE 'map' END AS type, 
        glyph_type_id, x, y, width,
        cpdTable.cmpd_name, cpdTable.CID, substTable.SID,
        enzy.description, map.name
FROM APIDB.pathwaynode pn, APIDB.pathway p, apidb.NetworkNode nn,
    ( SELECT s2.value, ca.preferred_name AS cmpd_name,  ca.compound_id as CID
	      FROM APIDB.pubchemsubstance s1, APIDB.pubchemsubstance s2, ApidbTuning.CompoundAttributes ca
	      WHERE s1.property = 'CID'
             AND s1.value = ca.compound_id
	      AND s1.substance_id = s2.substance_id
	      AND NOT s2.property = 'CID'
 ) cpdTable,
       ( SELECT substance_id AS SID, value
	      FROM APIDB.pubchemsubstance 
	      WHERE property = 'Synonym'
 ) substTable,
             (SELECT ec_number, description FROM sres.enzymeClass) enzy,
             (SELECT name, source_id FROM apidb.pathway) map
WHERE pn.parent_id = p.pathway_id
AND p.source_id= '$pathwayId' 
AND pn.row_id = nn.network_node_id
AND  pn.display_label = cpdTable.value (+) 
AND  pn.display_label = substTable.value (+) 
AND pn.display_label = enzy.ec_number(+)
AND pn.display_label = map.source_id (+)
AND nn.identifier NOT LIKE '%_X:_Y:'";
    return $sql;
}

#getOrganisms query with cpd_name AND gene_orgs
sub getOrganismsQuery {
    my ($ecNum, $sqlNot) = @_;
    my $sql = 
"SELECT apidb.tab_to_string(set(cast(COLLECT(DISTINCT SUBSTR( gf.organism , 1, 1) || '. ' ||  SUBSTR(gf.organism , INSTR(gf.organism, ' ', 1, 1) +1)) AS apidb.varchartab))) 
            FROM apidbtuning.geneattributes gf, ApidbTuning.GenomicSequence gs,
                 dots.Transcript t, dots.translatedAaFeature taf,
                 dots.aaSequenceEnzymeClass asec, sres.enzymeClass ec,ApidbTuning.GeneAttributes ga
            WHERE gs.na_sequence_id = gf.na_sequence_id
              AND ga.source_id = gf.source_id
              AND gf.na_feature_id = t.parent_id
              AND t.na_feature_id = taf.na_feature_id
              AND taf.aa_sequence_id = asec.aa_sequence_id
              AND asec.enzyme_class_id = ec.enzyme_class_id
              AND  $sqlNot asec.evidence_code = 'OrthoMCLDerived'
              AND ec.ec_number LIKE REPLACE(REPLACE(REPLACE(REPLACE(lower( '$ecNum'),' ',''),'-', '%'),'*','%'),'any','%')";

  my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
  $sth->execute() ||  die "Couldn't execute statement: " . $sth->errstr;

  my $orgs;
  while (my ($id) = $sth->fetchrow_array()) {
    $orgs = $id;
  }
  return $orgs;
}


sub getEdgesQuery {
    my $pathwayId = shift;
    return ("SELECT n1.identifier AS source, n2.identifier AS target,
             CASE WHEN  nrc.source_node = 0 THEN 'Reversible'
               ELSE 'Irreversible' END AS direction
FROM APIDB.network n, APIDB.networkrelcontextlink nrcl,
  APIDB.networkrelcontext nrc, APIDB.networkcontext nc,
  APIDB.networkrelationship nr,
  APIDB.networknode n1, APIDB.networknode n2
WHERE  n.name like  'Metabolic Pathways%'
  AND n.network_id = nrcl.network_id
  AND nrcl.network_rel_context_id = nrc.network_rel_context_id
  AND nc.network_context_id = nrc.network_context_id
  AND nc.name = '$pathwayId'
  AND nrc.network_relationship_id = nr.network_relationship_id
  AND nr.node_id = n1.network_node_id
  AND nr.associated_node_id = n2.network_node_id
  AND n1.identifier like '%_X:%'   AND n2.identifier like '%_X:%'
  AND n1.identifier NOT LIKE '%_X:_Y:' AND n2.identifier NOT LIKE '%_X:_Y:' 
ORDER BY nr.network_relationship_id");
}


