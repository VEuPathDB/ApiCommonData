package ApiCommonData::Load::WorkflowSteps::FixPsipredFileNames;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
    my ($self, $test) = @_;
	
    my $inputDir = $self->getParamValue('inputDir');
    my $outputDir = $self->getParamValue('outputDir');
    my @files;
	
    $self->runCmd($test,"cp -r $inputDir  $outputDir");


    if (-d $inputDir){
        opendir(DIR, $inputDir) || die "Can't open directory '$inputDir'";
        my @noDotFiles = grep { $_ ne '.' && $_ ne '..' } readdir(DIR);
        @files = map { "$inputDir/$_" } @noDotFiles;
    } else {
        $files[0] = $inputDir;
    }
	
	
    foreach my $file (@files){
        my $original = $file;
        $file =~ s/(\S+)_(\d)/$1-$2/g;
        $self->runCmd($test,"mv $original $file");
    }
}

sub getParamsDeclaration {
    return ('inputDir',
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

