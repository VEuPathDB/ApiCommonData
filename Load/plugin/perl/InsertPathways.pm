package ApiCommonData::Load::Plugin::InsertPathways;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";
use Data::Dumper;
use GUS::PluginMgr::Plugin;

use GUS::Supported::MetabolicPathway;

sub getArgsDeclaration {
  my $argsDeclaration  =
    [   
     stringArg({ name => 'pathwaysFileDir',
                 descr => 'full path to xml files',
                 constraintFunc=> undef,
                 reqd  => 1,
                 isList => 0,
                 mustExist => 1,
                }),

     enumArg({ name           => 'format',
               descr          => 'The file format for pathways (KEGG, MPMP, BioCyc, Other)',
               constraintFunc => undef,
               reqd           => 1,
               isList         => 0,
               enum           => 'KEGG, MPMP, BioCyc, Reactome'
             }),
        
     stringArg({ name => 'extDbRlsSpec',
             descr => 'External Database Release Name|version',
             isList    => 0,
             reqd  => 1,
             constraintFunc => undef,
           }),


    ];

  return $argsDeclaration;
}

sub getDocumentation {
  my $purposeBrief = "Inserts pathways from a set of KGML, JSON (MPMP) or biopax (BioCyc) files into Pathway schema.";

  my $purpose =  "Inserts pathways from a set of KGML, JSON  (MPMP) or biopax (BioCyc) files into Pathway schema.";

  #TODO
  my $tablesAffected = [[]];

  my $tablesDependedOn = [['Core.TableInfo',  'To store a reference to tables that have Node records (ex. EC Numbers, Coumpound IDs']];

  my $howToRestart = "No restart";

  my $failureCases = "";

  my $notes = "";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

  return $documentation;
}

#--------------------------------------------------------------------------------

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 4.0,
                        cvsRevision => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };

  $self->initialize($configuration);

  return $self;
}

#######################################################################
# Main Routine
#######################################################################

sub run {
  my ($self) = @_;

  my $dbiDb = $self->getDb();
  $dbiDb->setMaximumNumberOfObjects(100000);

  my $inputFileDir = $self->getArg('pathwaysFileDir');
  die "$inputFileDir directory does not exist\n" if !(-d $inputFileDir); 

  my $pathwayFormat = $self->getArg('format');
  my $extension = ($pathwayFormat eq 'MPMP') ? 'cyjs' 
                : ($pathwayFormat eq 'BioCyc') ? 'biopax'
                : ($pathwayFormat eq 'Reactome') ? 'json'
                : 'xml';

  my @pathwayFiles = <$inputFileDir/*.$extension>;
  die "No $extension files found in the directory $inputFileDir\n" if not @pathwayFiles;

  my $ontologyTerms = $self->queryForOntologyTermIds();

  my $tables = $self->queryForTableIds();
  my $ids = $self->queryForIds();

  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);

  my $verbose = $self->getArg('verbose') ? 1 : 0;

  foreach my $file (@pathwayFiles) {
    my $metabolicPathwayClass = "ApiCommonData::Load::${pathwayFormat}MetabolicPathway";

    eval "require $metabolicPathwayClass";

    my $metabolicPathway = eval {
      $metabolicPathwayClass->new($file, $ontologyTerms, $tables, $ids, $extDbRlsId, $extDbRlsSpec, $verbose);
    };

    if($@) {
      $self->error($@);
    }

    $metabolicPathway->makeGusObjects();
    
    my $pathway = $metabolicPathway->getPathway();

    foreach my $reaction (@{$metabolicPathway->getReactions()}) {
      $pathway->addToSubmitList($reaction);
    }

    foreach my $node (@{$metabolicPathway->getNodes()}) {
      $node->setParent($pathway);
    }

    foreach my $relationship (@{$metabolicPathway->getRelationships()}) {
      $pathway->addToSubmitList($relationship);
    }

    $pathway->submit();
    $self->undefPointerCache();
  }
}

sub queryForOntologyTermIds {
  my ($self) = @_;

  my $dbh = $self->getQueryHandle();
  my $query = "select ontology_term_id, name from sres.ontologyterm  where name in ('enzyme', 'molecular entity', 'metabolic process', 'gene')";

  my $sh = $dbh->prepare($query);
  $sh->execute();

  my %terms;
  while(my ($id, $name) = $sh->fetchrow_array()) {
    $terms{$name} = $id;
  }
  $sh->finish();

  return \%terms;
}


sub queryForTableIds {
  my ($self) = @_;

  my $dbh = $self->getQueryHandle();
  my $query = "select table_id
    , di.name || '::' || ti.name 
    from core.tableinfo ti
    , core.databaseinfo di 
    where ((ti.name in ('EnzymeClass', 'Compounds', 'Pathway') AND di.name != 'DoTS') OR ti.name = 'GeneFeature')
    and ti.database_id = di.database_id"; 

  my $sh = $dbh->prepare($query);
  $sh->execute();

  my %tables;
  while(my ($id, $name) = $sh->fetchrow_array()) {
    $tables{$name} = $id;
  }
  $sh->finish();

  return \%tables;
}

sub queryForIds {
  my ($self) = @_;
 
  my $dbh = $self->getQueryHandle();
  my $sql = "select 'SRes::EnzymeClass' tbl, ec_number as accession, enzyme_class_id as id from sres.enzymeclass
union
select 'SRes::Pathway', source_id, pathway_id from sres.pathway
union
select 'DoTS::GeneFeature', source_id, na_feature_id from dots.genefeature
union
select 'chEBI::Compounds', chebi_accession, nvl(parent_id, id) from chebi.compounds
union
select 'chEBI::Compounds', da.accession_number as accession, nvl(c.parent_id, c.id)
from chebi.database_accession da
   , chebi.compounds c
where c.id = da.compound_id
and da.type = 'KEGG COMPOUND accession'
";
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $rv = {};
  while(my ($table, $sourceId, $id) = $sh->fetchrow_array()) {
    $rv->{$table}->{$sourceId} = $id;
  }
  $sh->finish();

  return $rv;
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.PathwayReactionRel',
          'SRes.PathwayRelationship',
## TODO: Figure out a way to undo rxs re-used across datasets ##
#          'ApiDB.PathwayReaction',
          'SRes.PathwayNode',
          'SRes.Pathway',
	 );
}


1;
