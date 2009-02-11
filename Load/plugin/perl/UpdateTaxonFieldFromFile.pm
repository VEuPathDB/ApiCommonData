package ApiCommonData::Load::Plugin::UpdateTaxonFieldFromFile;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::TaxonName;
use GUS::Model::SRes::Taxon;

$| = 1;


# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [
     fileArg({name => 'fileName',
	      descr => 'input file containing the source_id and either the correspoding ncbi_tax_id or taxon_name',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0,
	      mustExist => 1,
	      format => 'Text'
	     }),
     stringArg({name => 'sourceIdRegex',
		descr => 'regex used to identify the source_id in each line',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'taxonNameRegex',
		descr => 'regex used to identify the taxon_name,must have this or ncbiTaxIdRegex',
		constraintFunc => undef,
		reqd => 0,
		isList => 0
	       }),
     stringArg({name => 'ncbiTaxIdRegex',
		descr => 'regex used to identify the ncbi tax_id,must have this or taxonNameRegex',
		constraintFunc => undef,
		reqd => 0,
		isList => 0
	       }),
     stringArg({name => 'tableName',
		descr => 'fully specified table to be updated, e.g. DoTS::ExternalAASequence',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0
	       }),
     stringArg({name => 'extDbRelSpec',
              descr => 'the database source for the rows being updated in database_name|db_rel_ver format',
              constraintFunc => undef,
              reqd => 1,
              isList => 0
             }),
     stringArg({name => 'idSql',
		descr => 'sql used to get the PKs and lower case source_ids of the rows to be updated, external_database_release_id appended using info from extDbRelSpec',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0
	       })
    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Updates specified table's taxon_id field";

  my $purpose = "Update the specified table's taxon_id from information supplied in the input file";

  my $tablesAffected = "";

  my $tablesDependedOn = [['SRes::TaxonName', 'the taxon_id will be identified using the taxon name if the regex is supplied'],['SRes::Taxon','the taxon_id will be identified using the ncbi tax_id if the the regex is supplied']];

  my $howToRestart = "No extra steps required for restart";

  my $failureCases = "";

  my $notes = "the table to be updated must contain source_id and taxon_id attributes and the file supplied must contain a source_id and either a taxon_name or ncbi_tax_id for which a taxon_id can be identified";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

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
  my $argumentDeclaration = &getArgumentsDeclaration();


  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision$',
                     name => ref($self),
                     revisionNotes => '',
                     argsDeclaration => $argumentDeclaration,
                     documentation => $documentation});

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

  my $table = $self->getArg('tableName');

  $self->userError("table must be in format TableSpace::Table") if ($table !~ /^\w+::\w+$/);

  eval ("require GUS::Model::$table");

  my $tableId = $self->className2TableId($table);

  my $pkName = $self->getAlgInvocation()->getTablePKFromTableId($tableId);

  my $sourceIds  = $self->processFile();

  my $updatedRows = $self->getUpdateIds($sourceIds,$table,$pkName);

  my $resultDescrip = "Taxon_id field updated in $updatedRows rows of $table";

  $self->setResultDescr($resultDescrip);
  $self->logData($resultDescrip);
}


sub processFile {
  my ($self) = @_;

  my $file = $self->getArg('fileName');

  my %taxonIds;

  my %sourceIds;

  my $unknownTaxonId = $self->getTaxonId(\%taxonIds);

  my $sourceRegex = $self->getArg('sourceIdRegex');

  open(FILE,$file) || $self->userError ("can't open $file for reading");

  while(<FILE>){
    chomp;

    my $line = $_;

    my $source_id;

    if ($line =~ /$sourceRegex/) { 
      $source_id = lc($1);
    }
    else {
      my $forgotParens = ($sourceRegex !~ /\(/)? "(Forgot parens?)" : "";
      $self->userError("Unable to parse source_id from $line using regex '$sourceRegex' $forgotParens");
    }

    my $taxon_id = $self->getTaxonId(\%taxonIds,$line);

    $sourceIds{$source_id} = $taxon_id if (! exists $sourceIds{$source_id} || $sourceIds{$source_id} == $unknownTaxonId);
  }

  %taxonIds = ();

  return \%sourceIds;
}

sub getTaxonId {
  my ($self,$taxonIds,$line) = @_;

  my ($regex,$id);

  if ($self->getArg('taxonNameRegex')) {
    $regex = $self->getArg('taxonNameRegex');
  }
  elsif ($self->getArg('ncbiTaxIdRegex')) {
    $regex = $self->getArg('ncbiTaxIdRegex');
  }
  else {
    $self->userError("must supply either ncbiTaxIdRegex or taxonNameRegex");
  }

  my $val;

  if ($line =~ /$regex/ ) {
    $val = lc($1);
  }
  else {
    $val = $self->getArg('taxonNameRegex') ? 'unknown' : 32644;
  }

  if (defined $taxonIds->{$val}) {
    $id = $taxonIds->{$val};
  }
  else {
    $id = $self->getArg('taxonNameRegex') ? $self->getIdFromTaxonName($val) : $self->getIdfromTaxon($val) ;
    $taxonIds->{$val} = $id;
  }

  return $id;
}

sub getIdFromTaxonName {
  my ($self,$name) = @_;

  my $dbh = $self->getQueryHandle();

  my $stmt = $dbh->prepare("select taxon_id from sres.taxonname where lower(name) = ?");

  $stmt->execute($name);

  my ($id) = $stmt->fetchrow_array();

  $id = $self->getIdFromTaxonName('unknown') if (! $id);

  $self->undefPointerCache();

  return $id;
}

sub getIdfromTaxon {
  my ($self,$ncbiTaxId) = @_;

  my $taxon = GUS::Model::SRes::Taxon->new({'ncbi_tax_id' => $ncbiTaxId});

  $taxon->retrieveFromDB();

  my $id = $taxon->getId();

  $id = $self->getIdFromTaxonName('unknown') if (! $id);

  $self->undefPointerCache();

  return $id;
}

sub updateRows {
  my ($self,$sourceIds,$table,$source,$pk,$table,$pkName) = @_;

  my $submitted;

  my $tableName = "GUS::Model::$table";

  my $row = $tableName->new({"$pkName" => $pk});

  $row->retrieveFromDB();

  $row->setTaxonId($sourceIds->{$source}) unless ($sourceIds->{$source} == $row->getTaxonId());

  $submitted += $row->submit();

  $self->undefPointerCache();

  $self->log("Updated $submitted rows.") if $submitted % 1000 == 0;


  return $submitted;
}

sub getUpdateIds {
  my ($self,$sourceIds,$table,$pkName) = @_;
  my $updatedRows;

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRelSpec'));

  my $idSql = $self->getArg('idSql');

  if ($idSql =~ /where/) {
    $idSql = $idSql . " and external_database_release_id = $extDbRlsId";
  }
  else {
    $idSql = $idSql . " where external_database_release_id = $extDbRlsId";
  }

  my $dbh = $self->getQueryHandle();

  my $stmt = $dbh->prepareAndExecute($idSql);

  while (my ($source_id, $pk) = $stmt->fetchrow_array) {
    $updatedRows = $self->updateRows($sourceIds,$table,$source_id,$pk,$table,$pkName);
  }

  $self->undefPointerCache();

  return $updatedRows;
}

sub undoUpdatedTables {
  my ($self) = @_;

  return ('DoTS.AASequence',
	  'DoTS.NASequence',
          'DoTS.NRDBEntry',
          'DoTS.OpticalMap',
          'DoTS.MicrosatelliteMap',
          'DoTS.RHMap',
          'Tess.MoietyImp',
          'DoTS.EndSequencePairMap'
	 );
}

1;
