package ApiCommonData::Load::WorkflowSteps::FixPsipredFileNames;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
    my ($self, $test) = @_;

    my $inputDir = $self->getParamValue('inputDir');
    my $outputDir = $self->getParamValue('outputDir');

    my $localDataDir = $self->getLocalDataDir();

    $self->runCmd(0,"cp -r $localDataDir/$inputDir  $localDataDir/$outputDir");

    opendir(DIR, "$localDataDir/$outputDir") || die "Can't open directory '$localDataDir/$outputDir'";
    
    
    my @files = readdir(DIR);
    foreach my $file (@files) {
	next if /^\.+$/;  # skip . and ..
        my $original = $file;
        $file =~ s/(\S+)_(\d)/$1-$2/g;
        $self->runCmd($test, "mv $original $file");
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

