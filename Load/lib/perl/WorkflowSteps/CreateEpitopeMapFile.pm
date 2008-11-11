package ApiCommonData::Load::WorkflowSteps::CreateEpitopeMapFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
 	my ($self, $test) = @_;

	my $inputDir = $self->getParamValue('inputDirRelativeToDownloadsDir');
	my $querydir = $self->getParamValue('proteinsFile');
	my $blastDir = $self->getParamValue('blastDbDir');
	my $speciesKey = $self->getParamValue('organismTwoLetterAbbrev');
	my $outputDir = $self->getParamValue('outputDir');

  	my $cmd = "createEpitopeMappingFile  --inputDir $inputDir --queryDir $queryDir --outputDir $outputDir --blastDatabase $blastDir";
  	$cmd .= " --speciesKey $speciesKey" if ($speciesKey);

    	self->runCmd($test,$cmd);
}



sub getParamsDeclaration {
  return ('inputDirRelativeToDownloadsDir',
	  'blastDbDir',
	  'organismTwoLetterAbbrev',
	  'proteinsFile',
	  'outputDir'
	 );
}


sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

sub getDocumentation {
}

sub restart {
}

sub undo {

}

