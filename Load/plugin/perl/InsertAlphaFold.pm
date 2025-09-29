package ApiCommonData::Load::Plugin::InsertAlphaFold;
use lib "$ENV{GUS_HOME}/lib/perl";
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Supported::Util;
use GUS::Model::ApiDB::AlphaFold;
use Data::Dumper;
use File::Temp qw/ tempfile /;

use ApiCommonData::Load::Psql;
use ApiCommonData::Load::Fifo;


use POSIX qw/strftime/;

sub getArgsDeclaration {
    my $argsDeclaration  =
    [
     
     stringArg({ name => 'inputFile',
             descr => 'accession_ids.txt file from AlphaFold',
             constraintFunc=> undef,
             reqd  => 1,
             isList => 0,
             mustExist => 1,
           }),

   stringArg({name => 'extDbSpec',                                                                                                                                                                         
              descr => 'External database from whence this data came|version',
              constraintFunc=> undef,
              reqd  => 1,
              isList => 0
             }),
    ];
    
    return $argsDeclaration;
}


sub getDocumentation {
    
    my $description = <<NOTES;
Load mappings between Uniprot ids and AlphaFold ids.
NOTES
    
    my $purpose = <<PURPOSE;
Load mappings between Uniprot ids and AlphaFold ids.
PURPOSE
    
    my $purposeBrief = <<PURPOSEBRIEF;
Load mappings between Uniprot ids and AlphaFold ids.
PURPOSEBRIEF
    
    my $syntax = <<SYNTAX;
SYNTAX
    
    my $notes = <<NOTES;
NOTES
    
    my $tablesAffected = <<AFFECT;
ApiDB.AlphaFold
AFFECT
    
    my $tablesDependedOn = <<TABD;
TABD
    
    my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
RESTART
    
    my $failureCases = <<FAIL;
FAIL
    
    my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};
    
    return ($documentation);
}



sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    
    my $documentation = &getDocumentation();
    
    my $args = &getArgsDeclaration();
    
    $self->initialize({requiredDbVersion => 4.0,
               cvsRevision => '$Revision$',
               name => ref($self),
               argsDeclaration   => $args,
               documentation     => $documentation
              });
    return $self;
}

sub run {
    my $self = shift;

    my $tableName = "ApiDB.AlphaFold";

    my $extDbSpec = $self->getArg('extDbSpec');
    my $extDbRlsId = $self->getExtDbRlsId($extDbSpec) or die "Couldn't find source db: $extDbSpec\n";

    my $inputFile = $self->getArg('inputFile');
 
    my $uniprotIds = $self->getUniprotIds;

    my $fifoName = "$inputFile\_filtered.txt";
    my $fifo = ApiCommonData::Load::Fifo->new($fifoName);


    my $alphaFoldTable = GUS::Model::ApiDB::AlphaFold_Table->new();

    my $psqlObj = $self->makePsqlObj($tableName, $fifoName, $alphaFoldTable->getAttributeList());
    my $psqlProcessString = $psqlObj->getCommandLine();
    
    my $pid = $fifo->attachReader($psqlProcessString);
    $self->addActiveForkedProcess($pid);

    my $fh = $fifo->attachWriter();

    my $rowCount = $self->filterInputAndLoad($inputFile, $uniprotIds, $fh, $extDbRlsId, $psqlObj);

    $fifo->cleanup();

}


sub initPrimaryKey {
    my ($self) = @_;

    my $dbh = $self->getQueryHandle();
    my $sql = "SELECT MAX(alphafold_id) from apidb.alphafold";
    my $sh = $dbh->prepare($sql);
    $sh->execute();

    # Set to 0 if there are no rows in this table
    my $primaryKeyInt = 0;;
    while(my ($primaryKey) = $sh->fetchrow_array()) {
        $primaryKeyInt = $primaryKey;
    }
    $sh->finish();
    
    return $primaryKeyInt++; 
}

sub makePsqlObj {
  my ($self, $tableName, $fifo, $attributeList) = @_;
  
  my $dbiDsn = $self->getDb->getDSN();
  $dbiDsn =~ /(:|;)dbname=((\w|\.)+);?/ ;
  my $db = $2;

  $dbiDsn =~ /(:|;)host=((\w|\.)+);?/ ;
  my $hostName = $2;

  my $psqlObj = ApiCommonData::Load::Psql->new({
    _login => $self->getDb->getLogin(),
    _password => $self->getDb->getPassword(),
    _database => $db,
    _hostName=> $hostname,
    _quiet => 0,
  });


  $psqlObj->setInfileName($fifo);
  $psqlObj->setTableName($tableName);
  $psqlObj->setFieldDelimiter(",");

  my @dataFields = map { lc($_) } @$attributeList;

  $psqlObj->setFields(\@dataFields);

  return $psqlObj;
}

# get uniprot ids from dbref table for filtering
sub getUniprotIds {
    my ($self) = @_;
    my $sql = "SELECT DISTINCT d.primary_identifier
               FROM sres.dbref d
               , sres.externaldatabase ed
               , sres.externaldatabaserelease edr
               WHERE (((ed.name = 'Uniprot/SWISSPROT' or ed.name = 'Uniprot/SPTREMBL')
                    AND (edr.version = 'xrefuniparc' OR edr.version = 'xref_sprot_blastp' OR edr.version = 'xref_trembl_blastp'))
                    OR (ed.name like '%_dbxref_%niprot_%RSRC'))
               AND edr.external_database_id = ed.external_database_id
               AND d.external_database_release_id = edr.external_database_release_id";

    my $dbh = $self->getQueryHandle();

    my $sh = $dbh->prepare($sql);
    $sh->execute();

    my %uniprotIds;
    while ((my $uniprotId) = $sh->fetchrow_array()) {
        $uniprotIds{$uniprotId} = 1;
    }

    die "No uniprot ids retrieved from database\n" unless scalar(keys %uniprotIds) > 0;

    return \%uniprotIds;
}

# filter out alphafold ids not in component database
sub filterInputAndLoad {
    my ($self, $inputFile, $uniprotIds, $fh, $extDbRlsId, $psqlObj) = @_;

    my $fields = $psqlObj->getFields();
    
    my $primaryKeyValue = $self->initPrimaryKey();
    my $rowGroupId = $dbiDb->getDefaultGroupId();
    my $rowUserId = $dbiDb->getDefaultUserId();
    my $rowProjectId = $dbiDb->getDefaultProjectId();
    my $rowAlgInvocationId = $dbiDb->getDefaultAlgoInvoId();
    my $userRead = $dbiDb->getDefaultUserRead();
    my $userWrite =  $dbiDb->getDefaultUserWrite();
    my $groupRead = $dbiDb->getDefaultGroupRead();
    my $groupWrite = $dbiDb->getDefaultGroupWrite();
    my $otherRead = $dbiDb->getDefaultOtherRead();
    my $otherWrite = $dbiDb->getDefaultOtherWrite();
    my $modificationDate = $self->getModificationDate();

    open(IN, $inputFile) or die "Cannot open input file $inputFile for reading. Please check and try again\n$!\n\n";

    my $count;
    
    while (<IN>) {
        chomp;
        my $line = $_;
        my @a =  split(',', $line);
        my $uniprot = $a[0];
        if (exists $uniprotIds->{$uniprot}) {

            my $firstResidueIndex = $a[1];
            my $lastResidueIndex = $a[2];
            my $sourceId = $a[3];
            my $alphaFoldVersion = $a[4];

            my $valuesHash = {alphafold_id => $primaryKeyValue,
                        uniprot_id => $uniprot,
                        first_residue_index => $firstResidueIndex,
                        last_residue_index => $lastResidueIndex,
                        source_id => $sourceId,
                        alphafold_version => $alphaFoldVersion,
                        external_database_release_id => $extDbRlsId,
                        modification_date => $modificationDate,
                        user_read => $userRead,
                        user_write => $userWrite,
                        group_read => $groupRead,
                        group_write => $groupWrite,
                        other_read => $otherRead,
                        other_write => $otherWrite,
                        row_user_id => $rowUserId,
                        row_group_id => $rowGroupId,
                        row_project_id => $rowProjectId,
                        row_alg_invocation_id => $rowAlgInvocationId
            };

            my @values = map { $valuesHash->{$_} } @$fields;

            print $fh join(",", @values) . "\n";
            $count++;
        }
    }
    close(IN);

    return $count;
}

sub getConfig {
    my ($self) = @_;

    if(!$self->{config}) {
        my $gusConfigFile = $self->getArg('gusConfigFile');
        $self->{config} = GUS::Supported::GusConfig->new($gusConfigFile);
    }
    $self->{config}
}


sub error {
  my ($self, $msg) = @_;
  print STDERR "\nERROR: $msg\n";

  foreach my $pid (@{$self->getActiveForkedProcesses()}) {
    kill(9, $pid);
  }

  $self->SUPER::error($msg);
}

sub getActiveForkedProcesses {
  my ($self) = @_;

  return $self->{_active_forked_processes} || [];
}

sub addActiveForkedProcess {
  my ($self, $pid) = @_;

  push @{$self->{_active_forked_processes}}, $pid;
}



# this will be run at the end of the workflow
# truncate the table and reload everything with sqlldr rather than undoing rows
sub undoPreprocess {
    my ($self, $dbh, $rowAlgInvocationList) = @_;

    $dbh->do('truncate table apidb.alphafold');
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.AlphaFold');
}

sub getModificationDate() { $_[0]->{_modification_date} }
sub setModificationDate {
  my ($self) = @_;
  my $modificationDate = strftime "%m-%d-%Y", localtime();
  $self->{_modification_date} = $modificationDate;
}


1;
