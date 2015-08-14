package ApiCommonData::Load::Plugin::InsertIsolateVocabMapping;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | fixed
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
@ISA = qw(GUS::PluginMgr::Plugin);
 
use strict;

use File::Basename;
use GUS::PluginMgr::Plugin;

use GUS::Model::Study::Characteristic;

$| = 1;


my $argsDeclaration =
[


   fileArg({name => 'inFile',
	    descr => 'tab del mapping file of string value to ontology term',
	    reqd => 1,
	    mustExist => 1,
	    format => '',
	    constraintFunc => undef,
	    isList => 0,
	   }),

     enumArg({ name           => 'qualifierType',
               descr          => 'The qualifier type',
               constraintFunc => undef,
               reqd           => 1,
               isList         => 0,
               enum           => 'location,host,source'
             }),

 ];


my $purposeBrief = <<PURPOSEBRIEF;
Insert Characteristics 
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
insert characteristics for app nodes where existing characteristics do not map to an ontology
PLUGIN_PURPOSE

my $tablesAffected = [
['Study.Characteristic', 'One row is added to this table for each vocab term mapped to an isolate']
];

my $tablesDependedOn = ['Study.Characteristic', 'SRes.TaxonName', 'SRes.OntologyTerm'];

my $howToRestart = <<PLUGIN_RESTART;
This plugin cannot be restarted.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
unknown
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;

PLUGIN_NOTES

my $documentation = {purposeBrief => $purposeBrief,
		     purpose => $purpose,
		     tablesAffected => $tablesAffected,
		     tablesDependedOn => $tablesDependedOn,
		     howToRestart => $howToRestart,
		     failureCases => $failureCases,
		     notes => $notes
		    };


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self, $class);

    $self->initialize({requiredDbVersion => 3.6,
		       cvsRevision =>  '$Revision$',
		       name => ref($self),
		       argsDeclaration   => $argsDeclaration,
		       documentation     => $documentation
		      });

    return $self;
}

sub run {
    my ($self) = @_;

    my $charCount;

    my $inFile = $self->getArg('inFile');
    my $qualifierType = $self->getArg('qualifierType');

    my %qualifierTypeToOntologyTermMap = ( 'host' => 'host',
                                           'source' => 'isolation_source',
                                           'location' => 'country'
        );

    my $ontologyTerm = $qualifierTypeToOntologyTermMap{$qualifierType};

    my $dbh = $self->getQueryHandle();
    my $sql = $self->getSqlByQualifierType($qualifierType);
    my $sh = $dbh->prepare($sql);
    $sh->execute($ontologyTerm, $ontologyTerm);

    my %toMap ;
    my $ontologyTermId;
    while(my ($pan, $oe, $value) = $sh->fetchrow_array()) {
      push @{$toMap{$value}}, $pan;
      $ontologyTermId = $oe;
    }
    $sh->finish();

    open(IN, $inFile) or die "Cannot open input file $inFile for reading:$!";
    <IN>; # remove the header
    while(<IN>) {
      chomp;
      my ($term, $category, $termURI, $label) = split(/\t/, $_);

      next unless($toMap{$term});

      my $termSourceId = basename $termURI;

      foreach my $pan(@{$toMap{$term}}) {
        # NOTE: Using the termsourceid here so we can tell apart from other characteristics
        my $gusCharacteristic = GUS::Model::Study::Characteristic->new({protocol_app_node_id => $pan, ontology_term_id => $ontologyTermId, value => $termSourceId});
        $gusCharacteristic->submit();
        $charCount++;
      }
      $self->undefPointerCache();
    }
    return("Added $charCount Study.Characteristic Rows");
}

sub getSqlByQualifierType {
  my ($self, $qualifierType) = @_;

  if($qualifierType eq 'host') {
    return "select c.protocol_app_node_id, c.ontology_term_id, c.value
from study.characteristic c
   , sres.ontologyterm o
where c.ontology_term_id = o.ontology_term_id
and o.name = ?
minus
select c.protocol_app_node_id, c.ontology_term_id, c.value
from study.characteristic c
   , sres.ontologyterm o
   , sres.taxonname tn
where c.ontology_term_id = o.ontology_term_id
and tn.name = c.value
and o.name = ?";
  }


return "select c.protocol_app_node_id, c.ontology_term_id, c.value
from study.characteristic c
   , sres.ontologyterm o
where c.ontology_term_id = o.ontology_term_id
and o.name = ?
minus
select c.protocol_app_node_id, c.ontology_term_id, c.value
from study.characteristic c
   , sres.ontologyterm o
   , sres.ontologyterm ot
where c.ontology_term_id = o.ontology_term_id
and ot.name = c.value
and o.name = ?
and (ot.source_id like 'UBERON_%' 
 or  ot.source_id like 'ENVO_%' 
 or  ot.source_id like 'GAZ_%'
 )
";

}


sub undoTables {
  my ($self) = @_;

  return ( 'Study.Characteristic'
      );
}


1;
