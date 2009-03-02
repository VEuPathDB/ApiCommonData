package ApiCommonData::Load::WorkflowSteps::RunMummer;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
    my ($self, $undo ,$test) = @_;


    my $genomicSeqsFile = $self->getParamValue('genomicSeqsFile');
    my $inputDir = $self->getParamValue('inputDir');
    my $outputFile = $self->getParamValue('outputFile');

    my $localDataDir = $self->getLocalDataDir();
    my $mummerPath = $self->getConfig('mummerPath');

    my @inputFileNames = $self->getInputFiles($test,$localDataDir/$inputDir,'','fasta');

    if (scalar @inputFileNames==0){
	die "No input files. Please check inputDir: $inputDir\n";
    }else {

	if ($test) {
	    $self->testInputFile('inputDir', "$localDataDir/$inputDir");
	    $self->testInputFile('genomicSeqsFile', "$localDataDir/$genomicSeqsFile");
	    $self->runCmd(0,"echo test > $localDataDir/$outputFile");
	}else{
	    foreach my $inputFile (@inputFileNames){
		my $cmd = "callMUMmerForSnps --mummerDir $mummerPath --query_file $localDataDir/$genomicSeqsFile --output_file $localDataDir/$outputFile --snp_file $localDataDir/$inputFile"; 
		$self->runCmd($test,$cmd);
	    }
	}

    }


}

sub getParamsDeclaration {
    return ('genomicSeqsFile',
            'inputDir',
            'outputFile'
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
