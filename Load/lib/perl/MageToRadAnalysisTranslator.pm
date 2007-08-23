package ApiCommonData::Load::MageToRadAnalysisTranslator;

use base qw(RAD::MR_T::MageImport::Service::AbstractTranslator);

use strict;

sub mapAll {
  my ($self, $docRoot) = @_;

  my $sLogger = $self->getLogger();
  $sLogger->info("start the mapAll method");

 unless(ref($docRoot) eq 'RAD::MR_T::MageImport::VO::DocRoot') {
    RAD::MR_T::MageImport::VOException::ObjectTypeError->
        new("Must provide the docRoot to mapAll Method")->throw();
  }

  my %rv;;

  my $voAssays = $docRoot->getAssayVOs();

  foreach my $assay (@$voAssays) {
    my $studyName = $assay->getStudyName();
    my $arrayDesign = $assay->getArraySourceId();
    my $acquisitions = $assay->getAcquisitions();

    foreach my $acquisition (@$acquisitions) {
      my $quantifications = $acquisition->getQuantifications();

      foreach my $quantification (@$quantifications) {
        my $processQuants = $quantification->getProcesses();

        my $quantName = $quantification->getName();

        foreach my $process (@$processQuants) {
          my $protocolName = $process->getProtocolName();
          my $name = $process->getName();
          my $uri = $process->getUri();

          my $parameterValues = $process->getParameterValues();

          $rv{$uri}->{study_name} = $studyName;
          $rv{$uri}->{array_design} = $arrayDesign;

          $rv{$uri}->{name} = $name;
          $rv{$uri}->{protocol_name} = $protocolName;
          $rv{$uri}->{parameter_values} = $parameterValues;

          push(@{$rv{$uri}->{quantification_names}}, $quantName);
        }
      }
    }
  }

  my $normCount = scalar keys %rv;
  print STDERR "Found [$normCount] Normalized Data Files\n";

  return \%rv;
}


1;
