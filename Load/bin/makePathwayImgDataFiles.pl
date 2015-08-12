#!/usr/bin/perl
## To make the xgmml data files for pathway images, drawn via Cytoscape Web

use strict;
use DBI;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::PropertySet;
use Getopt::Long;
use XML::Writer;
use IO::File;

my ($outDir, $pathwayList, $extDbRlsId,
    $gusConfigFile, $debug, $verbose, $projectId);

&GetOptions("outputDir=s" => \$outDir,
            "pathwayList=s" => \$pathwayList,
            "verbose!" => \$verbose,
            "extDbRlsId=i" => \$extDbRlsId,
            "gusConfigFile=s" => \$gusConfigFile,
	   );

if (!$outDir || (!$pathwayList && !$extDbRlsId) || ($pathwayList && $extDbRlsId)) {
  die ' USAGE: makePathwayImgDataFiles.pl -outputDir <outputDir> [-pathwayList=s]  (required when extDbRlsId not specified)"'
      .  "[--extDbRlsId=i] (required when pathwayList not specified)"
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
}
elsif($pathwayList) {
    @pids = split(",", $pathwayList);
}
else {
    die "an external database release id must be provided\n" unless defined ($extDbRlsId);
    @pids = &getPathwayIdsFromSource($extDbRlsId);
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

  while (my ($id, $display, $x, $y, $type,
	     $primaryId, $altId, $primaryName, $altName) = $sth->fetchrow_array()) {
    $validFlag = 1;

    $node{$id}->{display} = $display;
    $node{$id}->{type} = $type;
    $node{$id}->{x} = $x;
    $node{$id}->{y} = $y;
    $node{$id}->{primaryId} = $primaryId;
    $node{$id}->{alternativeId} = $altId;
    $node{$id}->{primaryName} = $primaryName;
    $node{$id}->{alternativeName} = $altName;

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
	if (  $node{$k}->{type} eq 'metabolic process' ) {
	  $writer->startTag("node", "label" =>  $node{$k}->{primaryName} , "id" => $k);
	} else {
	  $writer->startTag("node", "label" => $node{$k}->{display} , "id" => $k);
	}

	$writer->startTag("att", "name"=>"Type", "value"=>$node{$k}->{type}, "type"=>"string");
	$writer->endTag("att");


	if (  $node{$k}->{type} eq 'enzyme' ) {
	  $writer->startTag("att", "name"=>"Description", "value"=>$node{$k}->{primaryName}, "type"=>"string");
	  $writer->endTag("att");
	} elsif (  $node{$k}->{type} eq 'molecular entity') {
	  $writer->startTag("att", "name"=>"Description", "value"=>$node{$k}->{primaryName}, "type"=>"string");
	  $writer->endTag("att");
	  $writer->startTag("att", "name"=>"CID", "value"=>$node{$k}->{primaryId}, "type"=>"string");
	  $writer->endTag("att");
	  $writer->startTag("att", "name"=>"SID", "value"=>$node{$k}->{alternativeId}, "type"=>"string");
	  $writer->endTag("att");

	} elsif (  $node{$k}->{type} eq 'metabolic process') {
	  $writer->startTag("att", "name"=>"Description", "value"=>$node{$k}->{display}, "type"=>"string");
	  $writer->endTag("att");
	}

	if (  $node{$k}->{type} eq 'enzyme' ) {
	  $writer->startTag("att", "name"=>"Organisms", "value"=>$node{$k}->{ecOrgs}, "type"=>"string");
	  $writer->endTag("att");
	  $writer->startTag("att", "name"=>"OrganismsInferredByOthoMCL", "value"=>$node{$k}->{ecOrgsOrthomcl}, "type"=>"string");
	  $writer->endTag("att");

	}

    if (defined($node{$k}->{x}) && defined($node{$k}->{y})) {
        $writer->startTag("graphics", 
                  "x" => $node{$k}->{x},
                  "y" => $node{$k}->{y}
                 );
        $writer->endTag("graphics");
    }
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
  my $sql = "SELECT source_id FROM sres.pathway";
  my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
  $sth->execute() ||  die "Couldn't execute statement: " . $sth->errstr;

  my @ids;
  while (my ($id) = $sth->fetchrow_array()) {
    push (@ids, $id);
  }
  return @ids;
}

#gets all pathway ids by extDbRlsId
sub getPathwayIdsFromSource {
    my $extDbRlsId = shift;
    my $sql = "SELECT source_id FROM sres.pathway WHERE external_database_release_id = $extDbRlsId";
    my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
    $sth->execute() || die "Couldn't execute statement: " . $sth->errstr;

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
select pn.pathway_node_id
    , pn.display_label
    , pn.x
    , pn.y
    , ot.name
    , c.chebi_accession as identifier
    , cn.compound_id as alternative_identifier
    , cn.name as name
    , c.name as alternative_name
from sres.pathway p
    , sres.pathwaynode pn
        LEFT OUTER JOIN chebi.compounds c on pn.row_id = c.id
        LEFT OUTER JOIN (select n.compound_id
                                , listagg(n.name, ';') within group (order by n.compound_id) as name from chebi.names n
                                where n.source = 'IUPAC'
                                and n.type = 'IUPAC NAME'
                                group by n.compound_id) cn on pn.row_id = cn.compound_id
    , sres.ontologyterm ot
where p.source_id = '$pathwayId'
and p.pathway_id = pn.pathway_id
and pn.pathway_node_type_id = ot.ontology_term_id
and ot.name = 'molecular entity'
union
select n.pathway_node_id
    , n.display_label
    , n.x
    , n.y
    , ot.name
    , to_char(ec.enzyme_class_id) as identifier
    , null as alternative_identifier
    , ec.description as name
    , null as alternative_name
from sres.pathway p
    , sres.pathwaynode n LEFT OUTER JOIN sres.enzymeclass ec on n.row_id = ec.enzyme_class_id
    , sres.ontologyterm ot
where p.source_id = '$pathwayId'
and p.pathway_id = n.pathway_id
and n.pathway_node_type_id = ot.ontology_term_id
and ot.name = 'enzyme'
union
select n.pathway_node_id
    , n.display_label
    , n.x
    , n.y
    , ot.name
    , to_char(m.pathway_id) as identifier
    , null as alternative_identifier
    , m.name as name
    , null as alternative_name
from sres.pathway p
    , sres.pathwaynode n LEFT OUTER JOIN sres.pathway m on n.display_label = m.source_id
    ,sres.ontologyterm ot
where p.source_id = '$pathwayId'
and p.pathway_id = n.pathway_id
and n.pathway_node_type_id = ot.ontology_term_id
and ot.name = 'metabolic process'
";
#"
#select n.pathway_node_id
#     , n.display_label
#     , n.x
#     , n.y
#     , ot.name
#     , s.substance_id as identifier
#     , cpd.compound_id as alternative_identifier
#     , cpd.iupac_name as name 
#     , s.name as alternative_name
#from sres.pathwaynode n
#   , sres.pathway p
#   , sres.ontologyterm ot
#   , (select s.substance_id, c.compound_id, c.iupac_name
#      from apidb.pubchemsubstance s, apidbtuning.compoundattributes c
#      where s.property = 'CID'
#      and s.value = c.compound_id) cpd
#   , (select substance_id, listagg(value, ';') within group (order by substance_id) as name
#      from apidb.pubchemsubstance
#      where property != 'CID'
#      group by substance_id) s
#where p.source_id = '$pathwayId'
#and  n.pathway_id = p.pathway_id
#and n.pathway_node_type_id = ot.ontology_term_id
#and ot.name = 'molecular entity'
#and n.row_id = cpd.substance_id (+)
#and n.row_id = s.substance_id (+)
#union
#select n.pathway_node_id
#     , n.display_label
#     , n.x
#     , n.y
#     , ot.name
#     , ec.enzyme_class_id as identifier
#     , null as alternative_identifier
#     , ec.description as name 
#     , null as alternative_name
#from sres.pathway p
#   , sres.pathwaynode n
#   , sres.ontologyterm ot
#   , sres.enzymeclass ec
#where p.source_id = '$pathwayId'
#and p.pathway_id = n.pathway_id
#and n.pathway_node_type_id =ot.ontology_term_id
#and ot.name = 'enzyme'
#and n.row_id = ec.enzyme_class_id (+)
#union
#select n.pathway_node_id
#     , n.display_label
#     , n.x
#     , n.y
#     , ot.name
#     , m.pathway_id as identifier
#     , null as alternative_identifier
#     , m.name as name 
#     , null as alternative_name
#from sres.pathway p
#   , sres.pathwaynode n
#   , sres.ontologyterm ot
#   , sres.pathway m
#where p.source_id = '$pathwayId'
#and p.pathway_id = n.pathway_id
#and n.pathway_node_type_id =ot.ontology_term_id
#and ot.name = 'metabolic process'
#and n.display_label = m.source_id (+)
#";
    return $sql;
}

#getOrganisms query with cpd_name AND gene_orgs
sub getOrganismsQuery {
    my ($ecNum, $sqlNot) = @_;
    my $sql = 
"select apidb.tab_to_string(set(cast(collect(distinct substr( tn.name , 1, 1) || '. ' ||  substr(tn.name , instr(tn.name, ' ', 1, 1) +1)) as apidb.varchartab))) 
  from sres.taxonname tn
         , dots.aasequenceenzymeclass asec
         , dots.aasequence s
         , sres.enzymeclass ec
   where asec.enzyme_class_id = ec.enzyme_class_id
    and asec.aa_sequence_id = s.aa_sequence_id
    and s.taxon_id = tn.taxon_id
    and tn.name_class = 'scientific name'
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
    return ("select n.pathway_node_id as source
     , a.pathway_node_id as target
     , decode(r.is_reversible, 1, 'Reversible', 0, 'Irreversible', 'Unknown') as direction
from sres.pathway p
   , sres.pathwaynode n
   , sres.pathwaynode a
   , sres.pathwayrelationship r
where r.node_id = n.pathway_node_id
and r.associated_node_id = a.pathway_node_id
and a.pathway_id = p.pathway_id
and n.pathway_id = p.pathway_id
and p.source_id = '$pathwayId'
");
}


