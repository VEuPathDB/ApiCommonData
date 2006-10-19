package ApiCommonData::Load::Plugin::InsertMascotSummariesUndo;


@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

my $purpose = <<PURPOSE;
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
PURPOSEBRIEF

  my $notes = <<NOTES;

NOTES

  my $tablesAffected =
  [
  ];


  my $tablesDependedOn = 
  [
  ];

  my $howToRestart = <<RESTART;
No restart
RESTART

  my $failureCases = <<FAIL;
FAIL

my $documentation = { purpose=>$purpose, 
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };

my $argsDeclaration  =
  [
   stringArg({name => 'algInvocationId',
	      descr => 'A comma delimited list of algorithm invocation ids to undo',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 1,
	     }),

   booleanArg({name => 'undoAll',
	      descr => 'remove all',
	      constraintFunc=> undef,
	      reqd   => 0,
	      isList => 0,
	     }),
  ];


sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  $self->initialize({requiredDbVersion => 3.5,
             cvsRevision       => '$Revision$',
		     name => ref($self),
		     argsDeclaration => $argsDeclaration,
		     documentation => $documentation
		    });

  return $self;
}

sub run{
  my ($self) = @_;
  
  $self->{'dbh'} = $self->getQueryHandle();

  $self->{'dbh'}->{AutoCommit}=0;

  $self->{'algInvocationIds'} = $self->getArg('algInvocationId');
  
  if ($self->getArg('undoAll')) {
    $self->{'algInvocationIds'} = $self->_getAllAlgInvIds($self->{'dbh'});
  }

  $self->undoFeatures();

  $self->_deleteFromTable('Core.AlgorithmParam');

  $self->_deleteFromTable('Core.AlgorithmInvocation');

  if ($self->getArg('commit')) {
    print STDERR "Committing\n";
    $self->{'dbh'}->commit()
      || die "Commit failed: " . $self->{'dbh'}->errstr() . "\n";
  } else {
    print STDERR "Rolling back\n";
    $self->{'dbh'}->rollback()
      || die "Rollback failed: " . $self->{'dbh'}->errstr() . "\n";
  }
}

sub undoFeatures{
   my ($self) = @_;

   $self->_deleteFromTable('DoTS.AALocation');
   $self->_deleteFromTable('DoTS.MassSpecFeature');
   $self->_deleteFromTable('DoTS.MassSpecSummary');
   $self->_deleteFromTable('DoTS.NALocation');
   $self->_deleteFromTable('DoTS.NAFeature');
   $self->_deleteFromTable('DoTSVer.MassSpecFeatureVer');
   $self->_deleteFromTable('Core.AlgorithmParam');
   $self->_deleteFromTable('Core.AlgorithmInvocation');
}


sub _deleteFromTable{
   my ($self, $tableName) = @_;

  &deleteFromTable($tableName, $self->{'algInvocationIds'}, $self->{'dbh'});
}

sub deleteFromTable{
  my ($tableName, $algInvocationIds, $dbh) = @_;

  my $algoInvocIds = join(', ', @{$algInvocationIds});

  my $sql = 
"DELETE FROM $tableName
WHERE row_alg_invocation_id IN ($algoInvocIds)";

  my $rows = $dbh->do($sql) || die "Failed running sql:\n$sql\n";
  $rows = 0 if $rows eq "0E0";
  print STDERR "Deleted $rows rows from $tableName\n";
}

sub _getAllAlgInvIds {
    my ($self, $dbh) = @_;
    
    my $package = __PACKAGE__;
    $package =~ s/Undo//;
    
    my $sth = $dbh->prepare(<<EOSQL);
    select alginv.algorithm_invocation_id, alg.row_alg_invocation_id
    from core.algorithm alg,
         core.algorithmimplementation algimp,
         core.algorithminvocation alginv
    where alg.algorithm_id = algimp.algorithm_id
      and algimp.algorithm_implementation_id = alginv.algorithm_implementation_id
    and  alg.name = ?
EOSQL

    $sth->execute($package);

    my @ids = map {$_->[0]} @{$sth->fetchall_arrayref([0])};
    
    return \@ids;
}

1;
