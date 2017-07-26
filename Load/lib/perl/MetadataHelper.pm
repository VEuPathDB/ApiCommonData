package ApiCommonData::Load::MetadataHelper;

use strict;

use ApiCommonData::Load::MetadataReader;

use XML::Simple;

use Data::Dumper;

sub getReaders { $_[0]->{_readers} }
sub setReaders { $_[0]->{_readers} = $_[1] }

sub getDistinctQualifiers { $_[0]->{_distinct_qualifiers} }
sub setDistinctQualifiers { $_[0]->{_distinct_qualifiers} = $_[1] }

sub getMergedOutput { $_[0]->{_merged_output} }
sub setMergedOutput { $_[0]->{_merged_output} = $_[1] }

sub getParentParsedOutput { $_[0]->{_parent_parsed_output} }
sub setParentParsedOutput { $_[0]->{_parent_parsed_output} = $_[1] }

sub getOntologyMapping { $_[0]->{_ontology_mapping} }
sub setOntologyMapping { $_[0]->{_ontology_mapping} = $_[1] }

sub new {
  my ($class, $type, $metadataFiles, $rowExcludeFile, $colExcludeFile, $parentMergedFile, $parentType, $ontologyMappingXmlFile, $ancillaryInputFile) = @_;

  my $self = bless {}, $class;

  my $rowExcludes = &readRowExcludeFile($rowExcludeFile);
  my $colExcludes = &readColExcludeFile($colExcludeFile);

  my $ontologyMapping = &readOntologyMappingXmlFile($ontologyMappingXmlFile);

  $self->setOntologyMapping($ontologyMapping);

  my $parentParsedOutput;
  if($parentMergedFile) {
    my $parentReaderClass = "ApiCommonData::Load::MetadataReader::" . $parentType . "Reader";
    my $parentReader = eval {
      $parentReaderClass->new($parentMergedFile, {}, {}, undef);
    };
    die $@ if $@;

    $parentReader->read();

    $parentParsedOutput = $parentReader->getParsedOutput();

    $self->setParentParsedOutput($parentParsedOutput);
  }

  my @readers;
  foreach my $metadataFile (@$metadataFiles) {
    my $readerClass = "ApiCommonData::Load::MetadataReader::" . $type . "Reader";

   my $reader = eval {
     $readerClass->new($metadataFile, $rowExcludes, $colExcludes, $parentParsedOutput, $ancillaryInputFile);
   };
    die $@ if $@;

    push @readers, $reader;
  }

  $self->setReaders(\@readers);

  return $self;
}

sub merge {
  my ($self) = @_;

  my $readers = $self->getReaders();

  my $mergedOutput = {};
  my %distinctQualifiers;

  foreach my $reader (@$readers) {
    $reader->read();

    my @parsedOutputs;
    my $nestedReaders = $reader->getNestedReaders();
    if($nestedReaders) {
      @parsedOutputs = map {$_->getParsedOutput()} @$nestedReaders;
    }

    push @parsedOutputs, $reader->getParsedOutput();

    foreach my $parsedOutput(@parsedOutputs) {

      foreach my $pk (keys %$parsedOutput) {
        my $qualifiersHash = $parsedOutput->{$pk};

        foreach my $qualifier (keys %$qualifiersHash) {


          my $value = $qualifiersHash->{$qualifier};

          push @{$mergedOutput->{$pk}->{$qualifier}}, $value if(defined $value);
          $distinctQualifiers{$qualifier}++ unless($qualifier eq '__PARENT__');
        }
      }
    }
  }

  $self->setMergedOutput($mergedOutput);
  $self->setDistinctQualifiers(\%distinctQualifiers);
}


sub isValid {
  my ($self) = @_;

  my $mergedOutput = $self->getMergedOutput();
  my $parentOutput = $self->getParentParsedOutput();
  my $ontologyMapping = $self->getOntologyMapping();

  my $errors = {};
  my %errorsDistinctQualifiers;

  my %distinctValues;

  foreach my $pk (keys %$mergedOutput) {
    if($parentOutput) {
      my $parentId = $mergedOutput->{$pk}->{"__PARENT__"};

      $parentId = &getDistinctLowerCaseValues($parentId);
      die "No Parent Defined for $pk" unless(defined $parentId);

      unless($parentOutput->{$parentId}) {
        print STDERR "PRIMARY_KEY=$pk\n";
        print STDERR Dumper $mergedOutput->{$pk};
        die "Parent $parentId not defined as primary key in parent file" ;
      }

    }
    my $qualifiersHash = $mergedOutput->{$pk};
    foreach my $qualifier (keys %$qualifiersHash) {
      if($ontologyMapping) {
        unless($ontologyMapping->{$qualifier}->{characteristicQualifier}->{source_id}) {
          $errors->{$qualifier}->{"MISSING_ONTOLOGY_MAPPING"} = 1 unless($qualifier eq '__PARENT__');
        }
      }

      my $values = $qualifiersHash->{$qualifier};
      foreach my $value (@$values) {
        if($value =~ /USER_ERROR/) {

          $errors->{$qualifier}->{"MERGE_ERRORS"} = $errors->{$qualifier}->{"MERGE_ERRORS"} + 1;
          $errorsDistinctQualifiers{$qualifier} = $errorsDistinctQualifiers{$qualifier} + 1;
        }

        $distinctValues{$qualifier}->{$value} = 1;
      }
    }
  }


  foreach my $qualifier (keys %distinctValues) {
    my @values = keys %{$distinctValues{$qualifier}};
    my $valuesCount = scalar @values;

    print STDERR "QUALIFIER=$qualifier has $valuesCount Distinct Values\n";    

    my $max;
    if($valuesCount > 10) {
      print STDERR "Showing 10\n";
      $max = 10;
    }
    else {
      $max = $valuesCount;
    }
    
    for(my $i = 0; $i < $max; $i++) {
      print STDERR "   $values[$i]\n";
    }
  }

  if(scalar keys %$errors == 0) {
    return 1;
  }

  print STDERR "\n-----------------------------------------\n";

  print STDERR "Errors found:\n";
  print STDERR Dumper $errors;


#  &write(\*STDERR, \%errorsDistinctQualifiers, $errors, undef);

  return 0;
}


# this is a one column file (no header) of primary keys to exclude
sub readRowExcludeFile {
  my $file = shift;

  my %hash;

  if($file) {
    open(FILE, $file) or die "cannot open file $file for reading:$!";

    while(<FILE>) {
      chomp;

      $hash{lc($_)}++;
    }
    close FILE;
  }
  return \%hash;
}



sub readOntologyMappingXmlFile {
  my ($file) = shift;

  if($file) {
    my $ontologyMappingXML = XMLin($file, ForceArray => 1);

    my %ontologyMapping;

    foreach my $ot (@{$ontologyMappingXML->{ontologyTerm}}) {
      my $sourceId = $ot->{source_id};

      foreach my $name (@{$ot->{name}}) {
        $ontologyMapping{lc($name)}->{$ot->{type}} = $ot;
      }
    }

    return \%ontologyMapping;
  }

}

sub readColExcludeFile {
  my $file = shift;

  my %hash;

  if($file) {
    open(FILE, $file) or die "cannot open file $file for reading:$!";

    while(<FILE>) {
      chomp;

      my @a = split(/\t/, $_);

      my $file = $a[1];
      my $col = lc($a[0]);

      $file = "__ALL__" unless($file);

      $hash{$file}->{$col} = 1;
    }
    close FILE;
  }

  return \%hash;

}


sub writeMergedFile {
  my ($self, $outputFile) = @_;

  my $distinctQualifiers = $self->getDistinctQualifiers();
  my $mergedOutput = $self->getMergedOutput();

  open(my $fh, ">$outputFile") or die "Cannot open file $outputFile for writing:$!";

  &write($fh, $distinctQualifiers, $mergedOutput);

  close $fh;
}

sub write {
  my ($fh, $distinctQualifiers, $mergedOutput, $summarize) = @_;

  my @qualifiers = keys %$distinctQualifiers;

  print $fh "PRIMARY_KEY\tPARENT\t" . join("\t", @qualifiers) . "\n";

  foreach my $pk (keys %$mergedOutput) {
    my $qualifiersHash = $mergedOutput->{$pk};

    my $parent = &getDistinctLowerCaseValues($qualifiersHash->{'__PARENT__'});

    my @qualifierValues = map { &getDistinctLowerCaseValues($qualifiersHash->{$_})  } @qualifiers;

    print $fh "$pk\t$parent\t" . join("\t", @qualifierValues) . "\n";
  }
}

sub getDistinctLowerCaseValues {
  my ($a) = @_;

  my %seen;
  foreach(@$a) {
    $seen{$_}++;
  }

  my $rv = join('|', keys(%seen));

  if(scalar(keys(%seen)) > 1) {
    $rv = "USER_ERROR_$rv";
  }

  return $rv;
}



1;
