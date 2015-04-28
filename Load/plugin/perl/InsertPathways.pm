package ApiCommonData::Load::Plugin::InsertPathways;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

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
               enum           => 'KEGG, MPMP, TrypanoCyc'
             }),
        
 stringArg({ name => 'extDbRlsSpec',
	     descr => 'Extenral Database Release Name|version',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),


    ];

  return $argsDeclaration;
}

sub getDocumentation {
  my $purposeBrief = "Inserts pathways from a set of KGML or XGMML (MPMP) files into Pathway schema.";

  my $purpose =  "Inserts pathways from a set of KGML or XGMML (MPMP) files into Pathway schema.";

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

  my $inputFileDir = $self->getArg('pathwaysFileDir');
  die "$inputFileDir directory does not exist\n" if !(-d $inputFileDir); 

  my $pathwayFormat = $self->getArg('format');
  my $extension = ($pathwayFormat eq 'MPMP') ? 'xgmml' : 'xml';

  my @pathwayFiles = <$inputFileDir/*.$extension>;
  die "No $extension files found in the directory $inputFileDir\n" if not @pathwayFiles;

  my $ontologyTerms = $self->queryForOntologyTermIds();

  my $tables = $self->queryForTableIds();
  my $ids = $self->queryForIds();

  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);


  foreach my $file (@pathwayFiles) {
    my $metabolicPathwayClass = "ApiCommonData::Load::${pathwayFormat}MetabolicPathway";

    eval "require $metabolicPathwayClass";

    my $metabolicPathway = eval {
      $metabolicPathwayClass->new($file, $ontologyTerms, $tables, $ids, $extDbRlsId);
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

    $pathway->submit()
  }
}

sub queryForOntologyTermIds {
  my ($self) = @_;

  my $dbh = $self->getQueryHandle();
  my $query = "select ontology_term_id, name from sres.ontologyterm  where name in ('enzyme', 'molecular entity', 'metabolic process')";

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
  my $query = "select table_id, di.name || '::' || ti.name from core.tableinfo ti, core.databaseinfo di where ti.name in ('EnzymeClass', 'PubChemCompound', 'Pathway') and ti.database_id = di.database_id and di.name != 'DoTS'";

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
  my $sql = "select 'SRes::EnzymeClass', ec_number, enzyme_class_id from sres.enzymeclass
union
select 'ApiDB::PubChemCompound', value, compound_id from apidb.pubchemcompound where property = 'Synonym'
union
select 'SRes::Pathway', source_id,pathway_id from sres.pathway
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

  return ('SRes.Pathway',
          'SRes.PathwayNode',
          'SRes.PathwayRelationship',
          'ApiDB.PathwayReaction',
          'ApiDB.PathwayReactionRel',
	 );
}


1;
