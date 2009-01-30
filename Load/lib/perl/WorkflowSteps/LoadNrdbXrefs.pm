package ApiCommonData::Load::WorkflowSteps::LoadNrdbXrefs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $xrefsFile = $self->getParamValue('xrefsFile');
  my $dbAbbrevList = $self->getParamValue('dbAbbrevList');
  my $nrdbExtDbRlsSpec = $self->getParamValue('nrdbExtDbRlsSpec');

  my $localDataDir = $self->getLocalDataDir();
  my $stepDir = $self->getStepDir();

  my $cmd = "filterDbXRefOutput --file '$localDataDir/$xrefsFile' 2>>$stepDir/command.log";
   $self->runCmd($test,$cmd);
  my @db = split(/,/, $dbAbbrevList);

  foreach my $db (@db) {
    my $dbType = $db =~ /gb|emb|dbj/ ? "gb" : $db;

    my $dbName = "NRDB_${dbType}_dbXRefBySeqIdentity";

    unless (-e "$localDataDir/${xrefsFile}_$db"){
      my $log = "$stepDir/command.err";
      open(LOG,">>$log") or die "Can't open log file $log. Reason: $!\n";
      print LOG "$localDataDir/${xrefsFile}_$db does not exist. Skipping...\n";
      close(LOG);
      next;
    }


}
    die "test here";
}
sub getParamsDeclaration {
  return (
          'xrefsFile',
          'dbAbbrevList',
          'nrdbVersion',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
