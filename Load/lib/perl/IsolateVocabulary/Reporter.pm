package ApiCommonData::Load::IsolateVocabulary::Reporter;

use strict;
use Carp;

sub getNewTerms {$_[0]->{_new_terms}}
sub getExistingTerms {$_[0]->{_existing_terms}}

sub new {
  my ($class, $existingTerms, $newTerms) = @_;


  my $args = {_new_terms => $newTerms,
              _existing_terms => $existingTerms
             };


  bless $args, $class; 
}

sub report {
  my ($self) = @_;

  # make hash lookup for existing terms
  my $existingTermsHash = $self->makeHashFromTerms();

  my $newTerms = $self->getNewTerms();

  my $hadErrors;

  my $existingTerms = $self->getExistingTerms();

  # Check Existing terms have all needed attributes
  foreach my $existingTerm (@$existingTerms) {
    unless($existingTerm->isValid()) {
      $hadErrors = 1;
    }
  }

  # Check all new terms are handled
  foreach my $vocabTerm (@{$newTerms}) {
    my $value = $vocabTerm->getValue();

    unless($existingTermsHash->{$value}) {
      print STDERR "No Mapping Info for Vocab Term:  $value\n";
      $hadErrors = 1;
    }
  }

  if($hadErrors) {
    print STDERR "Please Correct erros and rerun";
  }
  else {
    print STDERR "Complete!";
  }

}

sub makeHashFromTerms {
  my ($self) = @_;

  my $existingTerms = $self->getExistingTerms();

  my %hash;

  foreach my $vocabTerm (@{$existingTerms}) {
    my $value = $vocabTerm->getValue();
    $hash{$value} = $vocabTerm;
  }

  return \%hash;
}




1;
