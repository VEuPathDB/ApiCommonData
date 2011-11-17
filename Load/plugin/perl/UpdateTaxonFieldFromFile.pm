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
	      descr => 'input file containing the source_id and either the corresponding ncbi_tax_id or taxon_name',
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
     integerArg({name => 'sourceIdSubstringLength',
		descr => 'Use to take substring from beginning of a source_id ... this is 4 for PDB updates',
		constraintFunc=> undef,
		reqd  => 0,
		isList => 0
	       }),
     stringArg({name => 'extDbRelSpec',
              descr => 'the database source for the rows being updated in database_name|db_rel_ver format',
              constraintFunc => undef,
              reqd => 1,
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


  $self->initialize({requiredDbVersion => 3.6,
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
  $self->getDb()->setGlobalNoVersion(0);  ##don't want to version as not informative

  my $table = $self->getArg('tableName');

  $self->userError("table must be in format TableSpace::Table") if ($table !~ /^\w+::\w+$/);

  if ($self->getArg('taxonNameRegex')) {
    $self->{taxidnameregex} = $self->getArg('taxonNameRegex');
    $self->cacheTaxonNameMapping();
  }
  elsif ($self->getArg('ncbiTaxIdRegex')) {
    $self->{taxidnameregex} = $self->getArg('ncbiTaxIdRegex');
    $self->cacheTaxonIdMapping();
  }
  else {
    $self->userError("must supply either ncbiTaxIdRegex or taxonNameRegex");
  }

  eval ("require GUS::Model::$table");

  my $tableId = $self->className2TableId($table);

  my $pkName = $self->getAlgInvocation()->getTablePKFromTableId($tableId);

  my $sourceIds  = $self->processFile();

  my $updatedRows = $self->getUpdateIds($sourceIds);

  my $resultDescrip = "Taxon_id field updated in $updatedRows rows of $table";

  $self->setResultDescr($resultDescrip);
  $self->logData($resultDescrip);
}


sub processFile {
  my ($self) = @_;

  $self->log("Processing taxon file\n");

  my $file = $self->getArg('fileName');

  my %sourceIds;

  my $unknownTaxonId = $self->getIdFromTaxonOrName('unknown');

  my $sourceRegex = $self->getArg('sourceIdRegex');

  open(FILE,$file) || $self->userError ("can't open $file for reading");

  my $count = 0;

  while(<FILE>){
    $count++;
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

    my $taxon_id = $self->getTaxonId($line);

    $sourceIds{$source_id} = $taxon_id if (! exists $sourceIds{$source_id} || $sourceIds{$source_id} == $unknownTaxonId);

    $self->log("  Processed $count rows") if $count %10000 == 0;
  }

  return \%sourceIds;
}

sub getTaxonId {
  my ($self,$line) = @_;

  my ($val,$id);

  if ($line =~ /$self->{taxidnameregex}/ ) {
    $val = lc($1);
  }
  else {
    $val = 'unknown';
  }

  $id = $self->getIdFromTaxonOrName($val) ;

  return $id;
}

sub getIdFromTaxonOrName {
  my ($self,$val) = @_;

  my $id = $self->{taxonIdMapping}->{$val};

  $id = $self->getIdFromTaxonOrName('unknown') if (! $id);

  return $id;
}

sub cacheTaxonIdMapping {
  my $self = shift;
  $self->log("Caching ncbi_tax_id -> taxon_id mapping\n");
  my $st = $self->prepareAndExecute("select taxon_id, ncbi_tax_id from sres.taxon");
  while(my($taxon_id,$n_tax_id) = $st->fetchrow_array()){
    $self->{taxonIdMapping}->{$n_tax_id} = $taxon_id;
  }
  ##need to cache for unknown one ...
  my $ust = $self->prepareAndExecute("select taxon_id from sres.taxonname where lower(name) = 'unknown'");
  my ($uid) = $ust->fetchrow_array();
  $self->{taxonIdMapping}->{'unknown'} = $uid;
  $self->log("Cached ".scalar(keys%{$self->{taxonIdMapping}}). " ncbi_tax_id -> taxon_id mappings\n");
}

sub cacheTaxonNameMapping {
  my $self = shift;
  $self->log("Caching taxonName -> taxon_id mapping\n");
  my $st = $self->prepareAndExecute("select taxon_id,lower(name) from sres.taxonname");
  while(my($taxon_id,$taxName) = $st->fetchrow_array()){
    $self->{taxonIdMapping}->{$taxName} = $taxon_id;
  }
  $self->log("Cached ".scalar(keys%{$self->{taxonIdMapping}}). " names -> taxon_id mappings\n");
}



sub updateRows {
  my ($self,$hashref, $sourceIds) = @_;

  my $tableName = "GUS::Model::".$self->getArg('tableName');

  my $row = $tableName->new($hashref);

  my $subLength = $self->getArg('sourceIdSubstringLength');
  my $sid = $subLength ? substr($row->getSourceId(),0,$subLength) : $row->getSourceId();

  $row->setTaxonId($sourceIds->{$sid}) unless ($sourceIds->{$sid} == $row->getTaxonId());

  return $row->submit(0,1);
}

sub getUpdateIds {
  my ($self,$sourceIds) = @_;
  my $updatedRows = 0;

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRelSpec'));

  my $tableName = $self->getArg('tableName');
  $tableName =~ s/::/./;

  my $sql = "select * from $tableName where external_database_release_id = $extDbRlsId and taxon_id is null";
  $self->log("Query for rows to update:\n$sql\n");

  my $dbh = $self->getQueryHandle();

  my $stmt = $dbh->prepareAndExecute($sql);

  while (my $hashref = $stmt->fetchrow_hashref('NAME_lc')) {
    $self->getDb()->manageTransaction(0,'begin') if $updatedRows % 100 == 0;
    $updatedRows += $self->updateRows($hashref,$sourceIds);
    if ($updatedRows % 100 == 0){
      $self->getDb()->manageTransaction(0,'commit');
      $self->log("Updated $updatedRows rows.") if $updatedRows % 10000 == 0;
      $self->undefPointerCache();
    }
  }
  $self->getDb()->manageTransaction(0,'commit'); 
  $self->undefPointerCache();


  return $updatedRows;
}

sub undoTables {
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
