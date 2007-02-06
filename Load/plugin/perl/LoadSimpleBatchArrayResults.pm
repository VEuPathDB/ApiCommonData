package ApiCommonData::Load::Plugin::LoadSimpleBatchArrayResults;
@ISA = qw( GUS::PluginMgr::Plugin );

use strict;
use IO::File;
use CBIL::Util::Disp;

use GUS::PluginMgr::Plugin;
use GUS::Community::FileTranslator;
use GUS::Community::Utils::InformationQueries;

use GUS::Model::RAD::RelatedQuantification;
use GUS::Model::RAD::Protocol;
use GUS::Model::RAD::StudyAssay;
use GUS::Model::RAD::Assay;

use GUS::Model::Study::Study;


# ----------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------

sub getArgumentsDeclaration {
  my $argumentDeclaration  =
    [
     stringArg({name  => 'studyName',
                descr => 'The study whose quantification results being loaded.',
                constraintFunc => undef,
                reqd  => 1,
                isList => 0
               }),
     fileArg({name => 'headerMappingFile',
	      descr => 'The full path of the xmlFile which provides a mapping for the File Headers to Database columns.',
	      constraintFunc => undef,
	      reqd  => 1,
	      isList => 0,
	      mustExist => 1,
	      format => 'See the NOTES for the format of this file'
	     }),
     stringArg({name  => 'resultSubclassView',
		 descr => 'Subclass View for ArrayResults. example: RAD::RMAExpress',
		 constraintFunc => undef,
		 reqd  => 1,
		 isList => 0
		}),
     stringArg({name  => 'arraySubclassView',
		 descr => 'Subclass View. for ArrayMap example: RAD::ShortOligoFamily',
		 constraintFunc => undef,
		 reqd  => 1,
		 isList => 0
		}),
     stringArg({name  => 'quantificationProtocolName',
		 descr => 'Name of the Quantification Protocol for these results',
		 constraintFunc => undef,
		 reqd  => 1,
		 isList => 0
		}),
     stringArg({name  => 'quantificationDirectory',
		 descr => 'Where are the results located?',
		 constraintFunc => undef,
		 reqd  => 1,
		 isList => 0
		}),
    ];
  return $argumentDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = 'Loads into the appropriate view of RAD::(Composite)ElementResultImp quantification data from a collection of files all having the same format.  Currently only one channel data is supported!!';

  my $purpose = <<PURPOSE;
Loads into the appropriate view of RAD::(Composite)ElementResultImp quantification data from a collection of files all having the same format.  Currently only one channel data is supported!!
PURPOSE

  my $tablesAffected = [['RAD::ElementResultImp', 'Enters the quantification results here, if the protocol is GenePix or ArrayVision'], ['RAD::CompositeElementResultImp', 'Enters the quantification results here, if the protocol is MAS4.0, MAS5.0, RMAExpress, or MOID'], ['RAD::RelatedQuantification', 'Inserts entries in this table for the quantifications at stake, if missing']];

  my $tablesDependedOn = [['Study::Study', 'The study, if studyId is passed in'], ['RAD::StudyAssay', 'The table linking the assays to the study, if studyId is passed in'], ['RAD::Assay', 'The assays passed in'], ['SRes::ExternalDatabaseRelease', 'The external database relase for the assays passed in'], ['RAD::ArrayDesign', 'The array design(s) used in the assays passed in' ], ['Study::OntologyEntry', 'The technology and substrate information for the arrays involved; also the channels for the acquisitions relative to the assays passed in'], ['RAD::Acquisition', 'The acquisitions for the assays passed in'], ['RAD::Quantification', 'The quantifications for the assays passed in'], ['RAD::RelatedAcquisition', 'The associations between the acquisitions for the assays passed in'], ['RAD::RelatedQuantification', 'The associations between the quantifications for the assays passed in'], ['RAD::Protocol', 'The quantification protocol of interest']];

  my $howToRestart = <<RESTART;
RESTART

  my $failureCases = <<FAILURE_CASES;
FAILURE_CASES

  my $notes = <<NOTES;
=head2 F<headerMappingFile>

This should be an xml file whose format should be that specified in GUS/Community/config/FileTranslatorCfg.dtd.
This is used to map headers in the software output files to attributes of the appropriate RAD view of (Composite)ElementResultImp as well as to RAD coordinates.

=head1 AUTHORS

This plugin was modified by John Brestelli from code written by: Hongxian He, Junmin Liu, Elisabetta Manduchi, Angel Pizarro, Trish Whetzel.

=head1 COPYRIGHT

Copyright CBIL, Trustees of University of Pennsylvania 2003.

=cut
NOTES

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};
  
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
  
  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision: 4207 $',
		     name => ref($self),
		     revisionNotes => '',
		     argsDeclaration => $argumentDeclaration,
		     documentation => $documentation
		    });
  return $self;
}

#--------------------------------------------------------------------------------

sub run {
  my ($self) = @_;

  $self->logAlgInvocationId();
  $self->logCommit();
  $self->logArgs();

  my $dbh = $self->getQueryHandle();

  my $logPath = $self->getArg('quantificationDirectory'); 
  $logPath = $logPath."/" unless ($logPath =~ m{.*/$});
  unless (-e "$logPath") {
    $self->userError("directory $logPath does not exist.");
  }

  $self->log("Files will be logged to $logPath");

  $self->checkViewArguments($dbh);

  my $study = $self->_getStudy();
  my $assays = $self->_getAllAssays($study);

  my $xmlFile = $self->getArg('headerMappingFile');

  my $fileTranslator = eval {
    GUS::Community::FileTranslator->new($xmlFile, "$logPath/errors.log", 0);
  };

  if ($@) {
    $self->userError("The mapping configuration file '$xmlFile' failed the validation. Please see the log file.");
  };

  my $numAssays = scalar(@$assays);
  $self->log("STATUS", "There are $numAssays assays whose results will be loaded.");

  my $assayCount = 0;
  foreach my $assay (@$assays) {
    $self->processAssay($assay, $logPath, $dbh, $fileTranslator);

    $assayCount++;
  }
  return("Processed $assayCount assays");
}

#--------------------------------------------------------------------------------

sub checkViewArguments {
  my ($self, $dbh) = @_;

  my $resultSubclassView = $self->getArg('resultSubclassView');
  my $arraySubclassView = $self->getArg('arraySubclassView');

  unless($self->isViewOnTable("CompositeElementResultImp", $resultSubclassView, $dbh)) {
    $self->userError("resultSubclassView [$resultSubclassView] is not a subclass of CompositeElementResultImp");
  }

  unless($self->isViewOnTable("CompositeElementImp", $arraySubclassView, $dbh)) {
    $self->userError("arraySubclassView [$arraySubclassView] is not a subclass of CompositeElementImp");
  }
}

#--------------------------------------------------------------------------------

sub isViewOnTable {
  my ($self, $table, $view, $dbh) = @_;

  my $sql = "select d.name || '::' || t.name from 
             Core.TABLEINFO t, Core.DATABASEINFO d 
             where d.database_id = t.database_id
              and t.view_on_table_id in
              (select table_id from Core.TABLEINFO where name = ?)";

  my $sh = $dbh->prepare($sql);
  $sh->execute($table);

  while(my ($allowedView) = $sh->fetchrow_array()) {
    return 1 if($allowedView eq $view);
  }

  $sh->finish();

  return 0;
}

#--------------------------------------------------------------------------------

sub processAssay {
  my ($self, $assay, $logPath, $dbh, $fileTranslator) = @_;

  my $assayId = $assay->getId();
  my $arrayDesignId = $assay->getArrayDesignId();

  my $infoQ = GUS::Community::Utils::InformationQueries->new($dbh);
  my $arrayInfo = $infoQ->getArrayInfo($arrayDesignId);

  $self->log("STATUS", "Working on assay $assayId.");

  my $ftLogFile = $logPath.".".$assayId.".filetranslator.log";

  my $quantProtocol = $self->_getQuantificationProtocol();

  my $quantifications = $self->_getQuantificationsMatchingProtocol($assay, $quantProtocol);

  foreach my $quantification (@$quantifications) {
    my $quantificationId = $quantification->getId();
    $self->log("STATUS", "Working on quantification [$quantificationId].");

    my $dataFile = $self->createDataFile($arrayInfo, $quantification, $fileTranslator);

    if (defined $dataFile) {
      my $relatedQuantifications = $self->_findRelatedQuantifications($quantification);
      $self->_relateQuantifications($quantification, $relatedQuantifications);

      $self->runArrayResultLoader($dbh, $logPath, $dataFile, $arrayDesignId, $quantificationId);
      $self->parseARlogs($logPath, $quantificationId);
    } 
    else {
      # The input file failed to validate against the config file
      $self->log("ERROR", "The input file for quantification [$quantificationId] failed validation. The results for this quantification cannot be loaded. Please see the log file $ftLogFile.");
    }
  } 
}

#--------------------------------------------------------------------------------

sub _relateQuantifications {
  my ($self, $quantification, $relatedQuantifications) = @_;

  my @relatedQuantifications;

  foreach my $related (@$relatedQuantifications) {
    my $relatedId = $related->getId();
    my $quantId = $quantification->getId();

    my $relatedQuantification = GUS::Model::RAD::RelatedQuantification->new({quantification_id => $quantId,
                                                                             associated_quantification_id => $relatedId,
                                                                            });

    unless($relatedQuantification->retrieveFromDB()) {
      $relatedQuantification->submit();
      $self->logData("RESULT", "[$quantId] and [$relatedId] are related. Inserted 1 entry in RAD::RelatedQuantification.");

      push(@relatedQuantifications, $relatedQuantification);
    }
  }
  return \@relatedQuantifications;
}

#--------------------------------------------------------------------------------

sub _findRelatedQuantifications {
  my ($self, $quantification) = @_;

  my $acquisition = $quantification->getParent('RAD::Acquisition', 1);
  my @otherQuantifications = $acquisition->getChildren('RAD::Quantification', 1);

  my @relatedQuants;

  foreach my $otherQuant (@otherQuantifications) {
    unless($otherQuant->getId() == $quantification->getId()) {
      push(@relatedQuants, $otherQuant);
    }
  }
  return \@relatedQuants;
}

#--------------------------------------------------------------------------------

sub _getQuantificationsMatchingProtocol {
  my ($self, $assay, $wantProtocol) = @_;

  my @matches;

  my $wantName = $wantProtocol->getName();

  my @acquisitions = $assay->getChildren('RAD::Acquisition', 1);
  my @quantifications = map {$_->getChildren('RAD::Quantification', 1)} @acquisitions;

  foreach my $quant (@quantifications) {
    if($quant->getProtocolId()) {
      my $protocol = $quant->getParent('RAD::Protocol', 1);
      my $name = $protocol->getName();

      push(@matches, $quant) if($name eq $wantName);
    }
  }

  return \@matches;
}

#--------------------------------------------------------------------------------

sub _getAllAssays {
  my ($self, $study) = @_;

  my @studyAssays = $study->getChildren('RAD::StudyAssay', 1);
  my @assays = map {$_->getParent('RAD::Assay', 1)} @studyAssays;

  return \@assays;
}

#--------------------------------------------------------------------------------

sub _getStudy {
  my ($self) = @_;

  my $studyName = $self->getArg('studyName');

  my $study = GUS::Model::Study::Study->new({name => $studyName});

  unless($study->retrieveFromDB) {
    $self->userError("Study [$studyName] was not retrieved from the DB");
  }
  return $study;
}

#--------------------------------------------------------------------------------

sub _getQuantificationProtocol {
  my ($self) = @_;

  my $quantProtocolName = $self->getArg('quantificationProtocolName');

  my $protocol = GUS::Model::RAD::Protocol->new({name => $quantProtocolName});

  unless($protocol->retrieveFromDB) {
    $self->userError("Protocol [$quantProtocolName] was not retrieved from the DB");
  }
  return $protocol;
}


#--------------------------------------------------------------------------------

sub runArrayResultLoader {
  my ($self, $dbh, $logPath, $dataFile, $arrayDesignId, $Rqid, $Gqid) = @_;

  my $infoQ = GUS::Community::Utils::InformationQueries->new($dbh);
  my $q = $infoQ->getQuantificationInfo($Rqid);
  my $projectName = $self->getArg('project') ? $self->getArg('project'): $q->{'project_name'};
  my $groupName =  $self->getArg('group') ?  $self->getArg('group') : $q->{'group_name'};

  my $arraySubclassView = $self->getArg('arraySubclassView');
  my $resultSubclassView = $self->getArg('resultSubclassView');

  my $commitString = "";
  if ($self->getArg('commit')) {
    $commitString = "--commit";
  }

  system("ga GUS::Community::Plugin::LoadSimpleArrayResults --data_file $dataFile --array_design_id $arrayDesignId --quantification_id $Rqid --array_subclass_view $arraySubclassView --result_subclass_view $resultSubclassView --project '$projectName' --group '$groupName' --log_path $logPath $commitString");
}

#--------------------------------------------------------------------------------

sub parseARlogs{
  my ($self, $logPath, $qid) = @_;

  my $fh = new IO::File;
  my $prefix = $logPath.$qid;

  my $errorFile = $prefix."_AR_errors.log";
  my $warningFile = $prefix."_AR_warnings.log";
  my $resultFile = $prefix."_AR_result.log";
  my $countErrors = 0;
  my $countWarnings = 0;
  unless ($fh->open("< $errorFile")) {
    $self->error("Could not open file $errorFile\n$!");
  }
  while (my $line=<$fh>) { 
    if ($line =~ /ERROR/i) {
      $countErrors++;
    }
  }
  $fh->close();
  if ($countErrors) {
    $self->log("ERROR", "There are $countErrors reported in file $errorFile. MAKE SURE TO CHECK THIS FILE!!!");
    $self->logData("ERROR", "There are $countErrors reported in file $errorFile. MAKE SURE TO CHECK THIS FILE!!!");
  }

  unless ($fh->open("< $warningFile")) {
    $self->error("Could not open file $warningFile.");
  }
  while (my $line=<$fh>) {
    if ($line =~ /WARNING/i) {
      $countWarnings++;
    }
  }
  $fh->close();
  if ($countWarnings) {
    $self->log("WARNING", "There are $countWarnings reported in file $warningFile.");
    $self->logData("WARNING", "There are $countWarnings reported in file $warningFile.");
  }

  unless ($fh->open("< $resultFile")) {
    $self->error("Could not open file $resultFile.");
  }
  while (my $line=<$fh>) {
    if ($line =~ /RESULT\s+(\w+.*)$/i) {
      my $msg = $1;
      $self->log("RESULT", "For quantification $qid: $msg");
      $self->logData("RESULT", "For quantification $qid: $msg");
    }
  }
  $fh->close();
}

#--------------------------------------------------------------------------------

sub createDataFile{
  my ($self, $arrayInfo, $quant, $fileTranslator) = @_;
  my $filePath = $self->getArg('quantificationDirectory');

  # translate input file to output according to the mapping xmlFile
  my $fname = $filePath . "/" . $quant->getUri();
  my $dataFile = $fname. ".data";

  my $result = $fileTranslator->translate($arrayInfo, $fname, $dataFile);

  # invalid input file
  if ($result == -1) {
    return undef;
  } 
  else {
    return $dataFile;
  }
}

1;



