package ApiCommonData::Load::IsolateVocabulary::Reporter;

use strict;
use Carp;

use ApiCommonData::Load::IsolateVocabulary::Utils;

sub getNewTerms {$_[0]->{_new_terms}}

sub getExistingTerms {$_[0]->{_existing_terms}}
sub setExistingTerms {$_[0]->{_existing_terms} = $_[1]}

sub getGusConfigFile {$_[0]->{gusConfigFile}}
sub setGusConfigFile {$_[0]->{gusConfigFile} = $_[1]}

sub disconnect {$_[0]->{dbh}->disconnect()}

sub getDbh {$_[0]->{dbh}}
sub setDbh {$_[0]->{dbh} = $_[1]}

sub new {
  my ($class, $gusConfigFile, $existingTerms, $newTerms, $type) = @_;


  my $args = {_new_terms => $newTerms,
              _existing_terms => $existingTerms,
              _type => $type
             };


  my $self = bless $args, $class;
  $self->setGusConfigFile($gusConfigFile);

  my $dbh = ApiCommonData::Load::IsolateVocabulary::Utils::createDbh($gusConfigFile);

  $self->setDbh($dbh);
  $self->setExistingTerms($existingTerms);

  return $self;
}

sub report {
  my ($self) = @_;

  my $type = $_[0]->{_type};

  my $hadErrors;

  my $dbh = $self->getDbh();

  my $existingTerms = $self->getExistingTerms();

  # Check Existing terms have all needed attributes
  foreach my $existingTerm (@$existingTerms) {
    unless($existingTerm->isValid()) {
      print STDERR "had error\n";
      $hadErrors = 1;
    }
  }

  # ensure the (assignment) terms in the mapping file are present in ontology
  my $check = $self->checkOntology();

  # make hash lookup for existing terms
  my $existingTermsHash = $self->makeHashFromTerms();

  my $newTerms = $self->getNewTerms();

  # Check all new terms are handled
  foreach my $vocabTerm (@{$newTerms}) {
    my $original = $vocabTerm->getOriginal();

    unless($existingTermsHash->{$original}) {
      print STDERR "No Mapping Info for Vocab Term:  $original\n";
      $self->getXml($original, $type);
      $hadErrors = 1;
    }
  }

  if($hadErrors || $check) {
    print STDERR "Please Correct Errors and rerun.  Terms can either be added to an ontology or add an xml map to link term to existing ontology\n";
  }
  else {
    print STDERR "All New Ontology Terms either map to existing term or are handeled in the xml map!\n";
  }

}

sub makeHashFromTerms {
  my ($self) = @_;

  my $existingTerms = $self->getExistingTerms();

  my %hash;

  foreach my $vocabTerm (@{$existingTerms}) {
    my $original = $vocabTerm->getOriginal();
    $hash{$original} = 1;
  }

  return \%hash;
}


sub getXml {
  my ($self, $value, $type) = @_;
  my $str = <<END;
  <initial table=\"IsolateSource\" field=\"$type\" original=\"$value\">
    <maps>
      <row type=\"$type\" value=\"\" \/>
    <\/maps>
  <\/initial>
END

print STDOUT $str;

}


sub isIncluded {
  my ($self, $a, $v) = @_;

  unless($a) {
    return 0;
  }
  foreach(@$a) {
    return 1 if $v eq $_;
  }
  return 0;
}

sub getAllOntologies {
  my ($self)  = @_;

  my $dbh = $self->getDbh();
  my $sql = "select term, type from apidb.isolatevocabulary where source = 'isolate vocabulary'";
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $res = {};
  while(my ($term, $type) = $sh->fetchrow_array()) {
#    $type = 'country' if($type eq 'geographic_location');
    $res->{$term}->{$type} = 1;
  }
  $sh->finish();

  return $res;
}

sub checkOntology {
  my ($self) = @_;

  my $existingOntology = $self->getAllOntologies();
  my @missing;

  foreach my $term (@{$self->getExistingTerms}) {
    my $original = $term->getOriginal();

    my $mapValue = $term->getValue();
    my $mapType = $term->getType();

    unless($existingOntology->{$mapValue}->{$mapType}) {
      push @missing, $mapValue;
    }
  }

  if (scalar @missing > 0) {
    print STDOUT "Add these $#missing+1 terms Isolate Vocabulary:\n";
    foreach my $term (sort @missing) {
      print STDOUT "$term\t\tproduct\n";
    }
  }



  return scalar(@missing);
}

1;
