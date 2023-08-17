##
## InsertOntologyFromTabDelim Plugin
## $Id: InsertOntologyFromTabDelim.pm manduchi $
##

package GUS::Supported::Plugin::InsertOntologyFromTabDelimUD;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use IO::File;
use CBIL::Util::Disp;
use GUS::PluginMgr::Plugin;

use GUS::Model::ApidbUserDatasets::OntologyTerm;
use GUS::Model::ApidbUserDatasets::OntologySynonym;
use GUS::Model::ApidbUserDatasets::OntologyRelationship;


# ----------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------

sub getArgumentsDeclaration {
  my $argumentDeclaration  =
    [
     fileArg({name => 'termFile',
	      descr => 'The full path of the file containing the ontology terms. .',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0,
	      mustExist => 1,
	      format => 'See the NOTES for the format of this file'
	     }),
     fileArg({name => 'relFile',
	      descr => 'The full path of the file containing the relationships. .',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0,
	      mustExist => 1,
	      format => 'See the NOTES for the format of this file'
	     }),
     stringArg({ name  => 'extDbRlsSpec',
		  descr => "The ExternalDBRelease specifier for this Ontology. Must be in the format 'name|version', where the name must match an name in ApidbUserDatasets::ExternalDatabase and the version must match an associated version in ApidbUserDatasets::ExternalDatabaseRelease.",
		  constraintFunc => undef,
		  reqd           => 1,
		  isList         => 0 }),
     stringArg({ name  => 'relTypeExtDbRlsSpec',
		  descr => "The ExternalDBRelease specifier for the relationship types. Must be in the format 'name|version', where the name must match an name in ApidbUserDatasets::ExternalDatabase and the version must match an associated version in ApidbUserDatasets::ExternalDatabaseRelease.",
		  constraintFunc => undef,
		  reqd           => 0,
		  isList         => 0 }),
     enumArg({name => 'isPreferred',
                 descr => 'set the name and definition in ontologyterm; mark ontologysynonym as is_preferred; value must be either true or false',
                 reqd           => 0,
                 isList         => 0,
                 enum => "true,false",
		  constraintFunc => undef,
               }),



    ];
  return $argumentDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------


sub getDocumentation {
  my $purposeBrief = 'Loads data from two tab-delimited text files into the tables OntologyTerm, OntologySynonym and OntologyRelationship in ApidbUserDatasets.';

  my $purpose = "This plugin populates the Ontology tables in ApidbUserDatasets.";

  my $tablesAffected = [['ApidbUserDatasets::OntologyTerm', 'Enters a row for each term'], ['ApidbUserDatasets::OntologySynomym', 'Enters rows linking each entered term to its Synonyms'], ['ApidbUserDatasets::OntologyRelationship', 'Links related terms']];

  my $tablesDependedOn = [['ApidbUserDatasets::ExternalDatabaseRelease', 'The release of the Ontology']];

  my $howToRestart = "No restart. Delete entries (can use Undo.pm) and rerun.";

  my $failureCases = "";

  my $notes = "

=head1 AUTHOR

Written by Elisabetta Manduchi

=head1 COPYRIGHT

Copyright Elisabetta Manduchi, Trustees of University of Pennsylvania 2012.

=head1 Ontology Term File Format

Tab delimited text file with the following header (order matters): id, name, def, synonyms (comma-separated), uri, is_obsolete [true/false]

=head1 Relationship File Format

A 3-column file with: subject_term_child, relationship_id, object_term_id 
The ids should match those listed in the Ontology Term File.

";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases, notes=>$notes};

  return $documentation;
}

# ----------------------------------------------------------------------
# create and initalize new plugin instance.
# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  my $documentation = &getDocumentation();
 my $argumentDeclaration    = &getArgumentsDeclaration();

  $self->initialize({requiredDbVersion => 4.0,
		     cvsRevision => '$Revision$',
		     name => ref($self),
		     revisionNotes => '',
		     argsDeclaration => $argumentDeclaration,
		     documentation => $documentation
		    });
  return $self;
}

# ----------------------------------------------------------------------
# run method to do the work
# ----------------------------------------------------------------------

sub run {
  my ($self) = @_;

  $self->logAlgInvocationId();
  $self->logCommit();
  $self->logArgs();

  my $termFile = $self->getArg('termFile');

  my $extDbRls = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));
  my $relFile = $self->getArg('relFile');

  my $resultDescr = $self->insertTerms($termFile, $extDbRls);
  if ($relFile) {
    $resultDescr .= $self->insertRelationships($relFile, $extDbRls);
  }

  $self->setResultDescr($resultDescr);
  $self->logData($resultDescr);
}


sub insertTerms {
  my ($self, $file, $extDbRls) = @_;  
  my $fh = IO::File->new("<$file");
  my $countTerms = 0;
  my $countSyns = 0;

  my $isPreferred = $self->getArg('isPreferred') eq 'true' ? 1 : 0;

  my $line = <$fh> if($self->getArg('hasHeader'));
  while ($line=<$fh>) {
    next if ($line =~ /^#|^\s*$/);
    chomp($line);
    my ($id, $name, $definition, $synonyms, $uri, $isObsolete) = split(/\t/, $line);
    $isObsolete = $isObsolete =~/^false$/i ? 0 : 1;

    my $ontologyTerm = GUS::Model::ApidbUserDatasets::OntologyTerm->new({source_id => $id });
    
    if($ontologyTerm->retrieveFromDB()) {
      if($isPreferred) {
        my $dbName = $ontologyTerm->getName();
        my $dbDef = $ontologyTerm->getDefinition();

        $ontologyTerm->setName($name);
        $ontologyTerm->setDefinition($definition);
        print STDERR "updated term and Definition for $id: $dbName to $name and $dbDef to $definition\n" if($dbName ne $name || $dbDef ne $definition);
      }
    }
    else {
      $ontologyTerm->setName($name);
      $ontologyTerm->setUri($uri);
      $ontologyTerm->setDefinition($definition);
      $ontologyTerm->setIsObsolete($isObsolete);
    }
    $countTerms++;

    my $ontologySynonym = GUS::Model::ApidbUserDatasets::OntologySynonym->new({ontology_synonym => $name, definition => $definition, external_database_release_id => $extDbRls});  
    $ontologySynonym->setParent($ontologyTerm);
    $ontologySynonym->setIsPreferred(1) if($isPreferred);
    $ontologySynonym->retrieveFromDB();
    $countSyns++;

    my @synArr = split(/,/, $synonyms);
    for (my $i=0; $i<@synArr; $i++) {
      $synArr[$i] =~ s/^\s+|\s+$//g;
      my $ontologySynonym = GUS::Model::ApidbUserDatasets::OntologySynonym->new({ontology_synonym => $synArr[$i], external_database_release_id => $extDbRls});  
      $ontologySynonym->setParent($ontologyTerm);
      if (!$ontologySynonym->retrieveFromDB()) {
	$countSyns++;
      }    
    }
    $ontologyTerm->submit();
    $self->undefPointerCache();
  }
  $fh->close();

  my $resultDescr = "Inserted $countTerms rows in ApidbUserDatasets.OntologyTerm and $countSyns row in ApidbUserDatasets.OntologySynonym";
  return ($resultDescr);
}

sub insertRelationships {
  my ($self, $file, $extDbRls) = @_;  
  my $fh = IO::File->new("<$file");
  my $countRels = 0;

  my $line = <$fh>  if($self->getArg('hasHeader'));
  while ($line=<$fh>) {
    next if ($line =~ /^#/);
    chomp($line);
    my ($subjectId, $predicateId, $objectId, $relationshipTypeId) = split(/\t/, $line);

    my $subject = GUS::Model::ApidbUserDatasets::OntologyTerm->new({source_id => $subjectId});    
    if(!$subject->retrieveFromDB()) {
      $self->userError("Failure retrieving subject ontology term \"$subjectId\"");
    }

    my $predicate;
    if($predicateId) {
      $predicate = GUS::Model::ApidbUserDatasets::OntologyTerm->new({source_id => $predicateId});
      if(!$predicate->retrieveFromDB()) {
        $self->userError("Failure retrieving predicate ontology term \"$predicateId\"");
      }
    }

    my $object = GUS::Model::ApidbUserDatasets::OntologyTerm->new({source_id => $objectId});
    if(!$object->retrieveFromDB()) {
      $self->userError("Failure retrieving object ontology term \"$objectId\"");
    }

    my $relationshipType;

    my $ontologyRelationship = GUS::Model::ApidbUserDatasets::OntologyRelationship->new();   
    $ontologyRelationship->setSubjectTermId($subject->getId());
    $ontologyRelationship->setPredicateTermId($predicate->getId()) if($predicate); 
    $ontologyRelationship->setObjectTermId($object->getId());
    $ontologyRelationship->setExternalDatabaseReleaseId($extDbRls);

    if($relationshipTypeId) {
      my $relTypeExtDbRls = $self->getExtDbRlsId($self->getArg('relTypeExtDbRlsSpec'));
      $relationshipType = GUS::Model::ApidbUserDatasets::OntologyTerm->new({external_database_release_id => $relTypeExtDbRls, source_id => $relationshipTypeId});
      if(!$relationshipType->retrieveFromDB()) {
        $self->userError("Failure retrieving relationshipType ontology term \"$relationshipTypeId\"");
      }

      $ontologyRelationship->setOntologyRelationshipTypeId($relationshipType->getId());
    }

    $countRels++;

    $ontologyRelationship->submit();
    $self->undefPointerCache();
  }
  $fh->close();
  my $resultDescr = ". Inserted $countRels rows in ApidbUserDatasets.OntologyRelationship";
  return ($resultDescr);
}

sub undoTables {
  my ($self) = @_;

  return ('ApidbUserDatasets.OntologyRelationship', 'ApidbUserDatasets.OntologySynonym');
}

1;
