package ApiCommonData::Load::WorkflowSteps::ExtractNaSeq;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


## to do
## API $self->getExtDbRlsId($genomeExtDbRlsSpec)
## API $self->getTaxonId($ncbiTaxId) 
## re-define dataDir

sub run {
  my ($self, $test) = @_;

  my $table = $self->getParamValue('table');

  my $dbRlsId = $self->getExtDbRlsId($self->getParamValue('extDbRlsSpec'));

  my $defline = $self->getParamValue('defline');
  
  my $outputFile = $self->getParamValue('outputFile');

  my $separateFastaFiles = $self->getParamValue('separateFastaFiles');

  my $outputDirForSeparateFiles = $self->getParamValue('outputDirForSeparateFiles');
  
  my $sql = "select $defLine,sequence
             from dots.$table
             where external_database_release_id = $dbRlsId";
  
  my $cmd;

  if ($separateFastaFiles) {

      $cmd="gusExtractIndividualSequences --outputDir $outputDirForSeparateFiles --idSQL \"$sql\" --verbose";

  } else {

      $cmd = "gusExtractSequences --outputFile $outputFile --idSQL \"$sql\" --verbose";
  }
  
  if ($test) {

      $self->runCmd(0,"test > $outputFile");

  } else {

      $self->runCmd($test,$cmd);

  }

}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['separateFastaFiles', "", ""],
     ['table', "", ""],
     ['defline', "", ""],
     ['genomeExtDbRlsSpec', "", ""],
     ['outputFile', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
