package ApiCommonData::Load::WorkflowSteps::ExtractNaSeq;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


## to do
## API $self->getExtDbRlsId($genomeExtDbRlsSpec)

sub run {
  my ($self, $test) = @_;

  my $table = $self->getParamValue('table');

  my $dbRlsId = $self->getExtDbRlsId($self->getParamValue('extDbRlsSpec'));

  my $alternateDefline = $self->getParamValue('alternateDefline');
  
  my $outputFile = $self->getParamValue('outputFile');

  my $separateFastaFiles = $self->getParamValue('separateFastaFiles');

  my $outputDirForSeparateFiles = $self->getParamValue('outputDirForSeparateFiles');

  my $sql;
  
  if ($alternateDefline eq ""){

  $sql = "select source_id, description,
            'length='||length,sequence
             from dots.$table
             where external_database_release_id = $dbRlsId";
 
  }else{
 
  $sql = "select $alternateDefline,sequence
             from dots.$table
             where external_database_release_id = $dbRlsId";
  }
  
  my $cmd;

  if ($separateFastaFiles) {

      $cmd="gusExtractIndividualSequences --outputDir $outputDirForSeparateFiles --idSQL \"$sql\" --verbose";
      
      if ($test) {

           $self->runCmd(0,"mkdir -p $outputDirForSeparateFiles");} else{

           $self->runCmd($test,$cmd); }

  } else {

      $cmd = "gusExtractSequences --outputFile $outputFile --idSQL \"$sql\" --verbose";
      if ($test) {

           $self->runCmd(0,"echo Hello > $outputFile");} else{

           $self->runCmd($test,$cmd); }
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
    );
  return @properties;
}

sub getParamDeclaration {
  my $properties =
     ['table'],
     ['extDbRlsSpec'],
     ['alternateDefline'],
     ['separateFastaFiles'],
     ['outputFile'],
     ['outputDirForSeparateFiles'],
  return $properties;
}

sub getDocumentation {
}
