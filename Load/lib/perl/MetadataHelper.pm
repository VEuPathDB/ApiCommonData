package ApiCommonData::Load::MetadataHelper;

use strict;

use JSON;

use ApiCommonData::Load::MetadataReader;

use Statistics::Descriptive;

use ApiCommonData::Load::OntologyDAGNode;

use XML::Simple;

use Data::Dumper;

use File::Basename;

use CBIL::ISA::InvestigationSimple;

use Scalar::Util qw(looks_like_number); 

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
  my ($class, $type, $metadataFiles, $rowExcludeFile, $colExcludeFile, $parentMergedFile, $parentType, $ontologyMappingXmlFile, $ancillaryInputFile, $packageName) = @_;

  eval "require $packageName";
  die $@ if $@;  

  my $self = bless {}, $class;

  my $rowExcludes = &readRowExcludeFile($rowExcludeFile);
  my $colExcludes = &readColExcludeFile($colExcludeFile);

  my $ontologyMapping = &readOntologyMappingXmlFile($ontologyMappingXmlFile);

  $self->setOntologyMapping($ontologyMapping);

  my $parentParsedOutput;
  if($parentMergedFile) {
    my $parentReaderClass = $packageName . "::" . $parentType . "Reader";

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
    my $readerClass = $packageName. "::" . $type . "Reader";

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

      unless($parentOutput->{lc($parentId)}) {
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


  foreach my $qualifier (keys %$errors) {
    foreach my $type (keys %{$errors->{$qualifier}}) {
      my $v = $errors->{$qualifier}->{$type};

      print "$qualifier\t$type\t$v\n";
    }
  }




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


sub readOntologyOwlFile {
  my ($self, $owlFile) = @_;

  # build classpath
  opendir(D, "$ENV{GUS_HOME}/lib/java") || $self->error("Can't open $ENV{GUS_HOME}/lib/java to find .jar files");
  my @jars;
  foreach my $file (readdir D){
    next if ($file !~ /\.jar$/);
    push(@jars, "$ENV{GUS_HOME}/lib/java/$file");
  }
  my $classpath = join(':', @jars);

   my $systemResult = system("java -classpath $classpath org.gusdb.gus.supported.OntologyVisitor $owlFile");
   unless($systemResult / 256 == 0) {
     die "Could not Parse OWL file $owlFile";
   }

   my $systemResult = system("java -classpath $classpath org.gusdb.gus.supported.IsA_Axioms $owlFile");
   unless($systemResult / 256 == 0) {
     die "Could not Parse OWL file $owlFile";
   }

  my $propertyNames = $self->readPropertyFile($owlFile . "_terms.txt", [0,1]);
  my $propertySubclasses = $self->readPropertyFile($owlFile . "_isA.txt", [2,0]);

  return($propertyNames, $propertySubclasses);
}

sub readPropertyFile {
  my ($self, $file , $i) = @_;

  open(FILE, $file) or die "Cannot open file $file for reading:$!";

  <FILE>;

  my %rv;

  while(my $line = <FILE>) {
    chomp $line;

    my @a = split(/\t/, $line);

    push @{$rv{$a[$i->[0]]}}, $a[$i->[1]];
  }

  close FILE;

  return \%rv;
}

sub makeTreeObjFromOntology {
  my ($self, $owlFile) = @_;

  my ($propertyNames, $propertySubclasses) = $self->readOntologyOwlFile($owlFile);

  my %nodeLookup;

  my $rootSourceId = "http://www.w3.org/2002/07/owl#Thing";

  my $root = ApiCommonData::Load::OntologyDAGNode->new({name => $rootSourceId, attributes => {"displayName" => "Thing"} });

  $nodeLookup{$rootSourceId} = $root;

  foreach my $parentSourceId (keys %$propertySubclasses) {

    my $parentNode = $nodeLookup{$parentSourceId};

    unless($parentNode) {
      my $parentDisplayName = $propertyNames->{$parentSourceId}->[0];
      $parentNode = ApiCommonData::Load::OntologyDAGNode->new({name => $parentSourceId, attributes => {"displayName" => $parentDisplayName}});
      $nodeLookup{$parentSourceId} = $parentNode;
    }

    my $childrenSourceIds = $propertySubclasses->{$parentSourceId};

    foreach my $childSourceId (@$childrenSourceIds) {
      my $childNode = $nodeLookup{$childSourceId};

      unless($childNode) {
        my $childDisplayName = $propertyNames->{$childSourceId}->[0];
        $childNode = ApiCommonData::Load::OntologyDAGNode->new({name => $childSourceId, attributes => {"displayName" => $childDisplayName} }) ;
        $nodeLookup{$childSourceId} = $childNode;
      }

      $parentNode->add_daughter($childNode);
    }
  }

#  print map("$_\n", @{$root->tree2string({no_attributes => 0})});
  return ($root, \%nodeLookup);
}



sub writeInvestigationTree {
  my ($self, $ontologyMappingFile, $valueMappingFile, $dateObfuscationFile, $ontologyOwlFile, $mergedOutputFile) = @_;

  my ($treeObjRoot, $nodeLookup) = $self->makeTreeObjFromOntology($ontologyOwlFile);

  my $dirname = dirname($mergedOutputFile);

  my $treeStringOutputFile = $mergedOutputFile . ".tree.txt";
  my $jsonStringOutputFile = $mergedOutputFile . ".tree.json";


  my $mergedOutputBaseName = basename($mergedOutputFile);
  my $investigationFile = "$dirname/tempInvestigation.xml";

  open(FILE, ">$investigationFile") or die "Cannot open file $investigationFile for writing: $!";
  

  print FILE "<investigation identifier=\"DUMMY\" identifierIsDirectoryName=\"false\">
  <study fileName=\"$mergedOutputBaseName\" identifierSuffix=\"-1\">
    <node isaObject=\"Source\" name=\"ENTITY\" type=\"INTERNAL\" suffix=\"\" useExactSuffix=\"true\" idColumn=\"PRIMARY_KEY\"/>  
  </study>
</investigation>
";

  close FILE;

  my $investigation = CBIL::ISA::InvestigationSimple->new($investigationFile, $ontologyMappingFile, undef, $valueMappingFile, undef, 0, $dateObfuscationFile);
  eval {
    $investigation->parseInvestigation();
  };
  if($@) {
    die $@;
    next;
  }

  my $studies = $investigation->getStudies();

  my %data;


  foreach my $study (@$studies) {
    
    while($study->hasMoreData()) {
      
      eval {
        $investigation->parseStudy($study);
        $investigation->dealWithAllOntologies();
      };
      if($@) {
        die $@;
      }

      my $nodes = $study->getNodes();


      foreach my $node (@$nodes) {

        my $characteristics = $node->getCharacteristics();
        foreach my $characteristic (@$characteristics) {
          my $qualifier = $characteristic->getQualifier();
          my $value = $characteristic->getValue();
          push @{$data{$qualifier}}, $value if($value)
        }
      }
    }
  }


  foreach my $sourceId (keys %data) {

    my $parentNode = $nodeLookup->{$sourceId};
    die "Source_id [$sourceId] is missing from the OWL file but used in data" unless($parentNode);

    my %count;

    my @values = @{$data{$sourceId}};

    foreach my $value (@values) {
      if($value =~ /\d\d\d\d-\d\d-\d\d/) {
        $count{"date"}++;
      }
      elsif(looks_like_number($value)) {
        $count{"number"}++;
      }
      else {
        $count{"string"}++;
      }

      $count{"total"}++;
    }

    if($count{"date"} == $count{"total"}) {
      #sort and take first and last
      my @sorted = sort @values;
      my $mindate = $sorted[0];
      my $maxdate = $sorted[scalar(@sorted)];
      my $display = "DATE_RANGE=$mindate-$maxdate";

      $parentNode->add_daughter(ApiCommonData::Load::OntologyDAGNode->new({name => "$sourceId.1", attributes => {"displayName" => $display, "isLeaf" => 1, "keep" => 1} })) ;
    }
    elsif($count{"number"} == $count{"total"}) {
      # use stats package to get quantiles and mean
      my $stat = Statistics::Descriptive::Full->new();
      $stat->add_data(@values);
      my $min = $stat->quantile(0);
      my $firstQuantile = $stat->quantile(1);
      my $median = $stat->quantile(2);
      my $thirdQuantile = $stat->quantile(3);
      my $max = $stat->quantile(4);
      my $mean = $stat->mean();

      $parentNode->add_daughter(ApiCommonData::Load::OntologyDAGNode->new({name => "$sourceId.1", attributes => {"displayName" => "MIN=$min", "isLeaf" => 1, "keep" => 1} })) ;
      $parentNode->add_daughter(ApiCommonData::Load::OntologyDAGNode->new({name => "$sourceId.2", attributes => {"displayName" => "MAX=$max", "isLeaf" => 1, "keep" => 1} })) ;
      $parentNode->add_daughter(ApiCommonData::Load::OntologyDAGNode->new({name => "$sourceId.3", attributes => {"displayName" => "MEAN=$mean", "isLeaf" => 1, "keep" => 1} })) ;
      $parentNode->add_daughter(ApiCommonData::Load::OntologyDAGNode->new({name => "$sourceId.4", attributes => {"displayName" => "MEDIAN=$median", "isLeaf" => 1, "keep" => 1} })) ;
      $parentNode->add_daughter(ApiCommonData::Load::OntologyDAGNode->new({name => "$sourceId.5", attributes => {"displayName" => "LOWER_QUARTILE=$firstQuantile", "isLeaf" => 1, "keep" => 1} })) ;
      $parentNode->add_daughter(ApiCommonData::Load::OntologyDAGNode->new({name => "$sourceId.6", attributes => {"displayName" => "UPPER_QUARTILE=$thirdQuantile", "isLeaf" => 1, "keep" => 1} })) ;

    }
    else {
      my %values;
      foreach my $value(@values) {
        $values{$value}++;
      }

      my $ct = 1;
      foreach my $value (sort keys %values) {
        $parentNode->add_daughter(ApiCommonData::Load::OntologyDAGNode->new({name => "$sourceId.$ct", attributes => {"displayName" => "$value ($values{$value})", "isLeaf" => 1, "keep" => 1} })) ;
        $ct++;
      }
    }

    &keepNode($parentNode);

  }


  open(TREE, ">$treeStringOutputFile") or die "Cannot open file $treeStringOutputFile for writing:$!";
  open(JSON, ">$jsonStringOutputFile") or die "Cannot open file $jsonStringOutputFile for writing:$!";

  print TREE map { "$_\n" if($_) } @{$treeObjRoot->tree2string({no_attributes => 0})};

  my $treeHashRef = $treeObjRoot->transformToHashRef();

  my $json_text = encode_json($treeHashRef);

  print JSON "$json_text\n";

  close TREE;
  close JSON;
}



sub keepNode {
  my ($node) = @_;

  $node->{attributes}->{keep} = 1;

  return if($node->is_root());

  &keepNode($node->mother());
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
