package ApiCommonData::Load::MBioResultsTable;

use strict;
use warnings;

use List::Util qw/sum uniq/;

use DateTime;
use JSON qw/encode_json/;

sub submitToGus {
  my ($self, $setMaxObjects, $undefPointerCache, $submit, $protocolAppNodeIdsForSamples) = @_;

  $setMaxObjects->(scalar @{$self->{rows}});

  SAMPLE:
  for my $sample (@{$self->{samples}}){
    my $panId = $protocolAppNodeIdsForSamples->{$sample};
    die "Missing ProtocolAppNode id for sample: $sample" unless $panId;
    ROW:
    for my $row (@{$self->{rows}}){
	my $value = $self->{data}{$sample}{$row};
        next ROW unless $value;
	$submit->($self->{valueToGus}->($panId, $row, $self->{sampleDetails}{$sample}, $self->{rowDetails}{$row}, $value));
    }
    $undefPointerCache->();
  }
}

sub valueToGusTaxa {
  my ($panId, $row, $sd, $rd, $v) = @_;

  return 'GUS::Model::Results::LineageAbundance', {
    PROTOCOL_APP_NODE_ID => $panId,
    lineage => $row,
    raw_count => $v,
    relative_abundance => sprintf("%.6f", $v / $sd->{totalCount})
  };
}

sub ampliconTaxa {
  my ($class, $inputPath) = @_;
  return construct($class, {
    resultType => 'Taxon table',
    dataForSampleOntologyTerm => 'abundance_amplicon',
    matrixElementType => 'int',
    printMatrixElement => sub {
      my ($x) = @_;
      return $x ? $x : "";
    },
    valueToGus => \&valueToGusTaxa,
  }, $inputPath, sub {
    my ($samples, $rowSampleHashPairs) = @_;
    my @rows;
    my %data;
    my %sampleDetails;
    P:
    for my $p (@{$rowSampleHashPairs}){
      my $row = $p->[0];
      push @rows, $row;
      SAMPLE:
      for my $sample (@$samples){
	my $value = $p->[1]{$sample};
        next SAMPLE unless $value;
        $data{$sample}{$row} = $value;
        $sampleDetails{$sample}{totalCount}+=$value;
      }
    }
    return \@rows, \%data, \%sampleDetails, {};
  });
}

sub wgsTaxa {
  my ($class, $inputPath) = @_;
  return construct($class, {
    resultType => 'Taxon table',
    dataForSampleOntologyTerm => 'abundance_wgs',
    matrixElementType => 'float',
    printMatrixElement => sub {
      my ($x) = @_;
      return $x ? sprintf("%.5f", $x) : "";
    },
    valueToGus => \&valueToGusTaxa,
  }, $inputPath, sub {
    my ($samples, $rowSampleHashPairs) = @_;
    my @rows;
    my %data;
    my %sampleDetails;
    P:
    for my $p (@{$rowSampleHashPairs}){
      my $row = maybeGoodMetaphlanRow($p->[0]);
      next P unless $row;
      push @rows, $row;
      SAMPLE:
      for my $sample (@$samples){
	my $value = $p->[1]{$sample};
        next SAMPLE unless $value;
        $data{$sample}{$row} = $value if $value;
        $sampleDetails{$sample}{totalCount}+=$value;
      }
    }
    return \@rows, \%data, \%sampleDetails, {};
  });
}

sub wgsFunctions {
  my ($class, $unitType, $inputPath) = @_;
  return construct($class, {
    resultType => 'Function table',
    dataForSampleOntologyTerm => "function_$unitType",
    matrixElementType => 'float',
    printMatrixElement => sub {
      my ($x) = @_;
      return $x ? sprintf("%.5f", $x) : "";
    },
    valueToGus => sub {
      my ($panId, $row, $sd, $rd, $v) = @_;
      return 'GUS::Model::Results::FunctionalUnitAbundance', {
        PROTOCOL_APP_NODE_ID => $panId,
        %{$rd},
        unit_type => $unitType,
        abundance_cpm => $v,
      };
    }
  }, $inputPath, sub {
    my ($samples, $rowSampleHashPairs) = @_;
    my %rows;
    my %data;
    my %rowDetails;
    P:
    for my $p (@{$rowSampleHashPairs}){
      my $row = $p->[0];
      next P if $row =~ m{UNMAPPED|UNGROUPED|UNINTEGRATED};
      $rowDetails{$row} = detailsFromRowName($row);
      $rows{$row}++;
      for my $sample (@$samples){
	my $value = $p->[1]{$sample};
        $data{$sample}{$row} = $value if $value;
      }
    }
    my @rows = sort keys %rows;
    return \@rows, \%data, {}, \%rowDetails;
  });
}

sub wgsPathways {
  my ($class, $inputPathAbundances, $inputPathCoverages) = @_;
  my $dataTypeInfo = {
    resultType => 'Pathway table',
    dataForSampleOntologyTerm => 'abundance_and_coverage_pathways',
    matrixElementType => 'unicode',
    printMatrixElement => sub {
      my ($abundance, $coverage) = @{$_[0]};
      return $abundance ? sprintf("\"%.5f|$coverage\"", $abundance) : "";
    },
    valueToGus => sub {
      my ($panId, $row, $sd, $rd, $v) = @_;
      my ($abundance, $coverage) = @$v;
      return 'GUS::Model::Results::FunctionalUnitAbundance', {
        PROTOCOL_APP_NODE_ID => $panId,
        %{$rd},
        unit_type => "pathway",
        abundance_cpm => $abundance,
        coverage_fraction => $coverage
      };
    }
  }; 

  my ($samplesAs, $rowHashSamplePairsAs) = parseSamplesTsv($inputPathAbundances);
  my ($samplesCs, $rowHashSamplePairsCs) = parseSamplesTsv($inputPathCoverages);
  my @samples = uniq @{$samplesAs}, @{$samplesCs};

  if (@$samplesAs < @samples || @$samplesCs < @samples){
    die "Inconsistent sample names across pathways and coverages: $inputPathAbundances, $inputPathCoverages";
  }

  my %rowsA;
  my %data;

  P:
  for my $p (@{$rowHashSamplePairsAs}) {
    my ($row, $h) = @$p;

    next P if $row =~ m{UNMAPPED|UNGROUPED|UNINTEGRATED};

    $rowsA{$row}++;
    for my $sample (@samples){
      $data{$sample}{$row} = $h->{$sample};
    } 
  }
  my $numRowsC;

  P:
  for my $p (@{$rowHashSamplePairsCs}) {
    my ($row, $h) = @{$p};
    next P if $row =~ m{UNMAPPED|UNGROUPED|UNINTEGRATED};

    die "Inconsistent rows between abundance and coverage files: row $row in the coverage file missing from the abundance file"
      unless defined $rowsA{$row};
    $numRowsC++;

    for my $sample (@samples){

      die "Inconsistent samples between abundance and coverage files: row $row, sample $sample in the coverage file missing from the abundance file"
         unless defined $data{$sample}{$row};

      $data{$sample}{$row} = [ $data{$sample}{$row}, $h->{$sample}];
    } 
  }
 
  my @rows = sort keys %rowsA;
  die sprintf("Coverage file had %s more rows than the abundance file?", $numRowsC - @rows)
    unless @rows == $numRowsC;

  my %rowDetails;
  for my $row (@rows){
    $rowDetails{$row} = detailsFromRowName($row);
  }

  return new($class, $dataTypeInfo, \@samples, \@rows, \%data, {}, \%rowDetails);
}

sub construct {
  my ($class, $dataTypeInfo, $inputPath, $prepare) = @_;

  my ($samples, $rowSampleHashPairs) = parseSamplesTsv($inputPath);

  return new($class, $dataTypeInfo, $samples, $prepare->($samples, $rowSampleHashPairs)); 
}

sub new {
  my ($class, $dataTypeInfo, $samples, $rows, $data, $sampleDetails, $rowDetails) = @_;
  return bless {
    %{$dataTypeInfo},
    samples => $samples,
    sampleDetails => $sampleDetails,
    rows => $rows,
    rowDetails => $rowDetails,
    data => $data,
  }, $class;
}

sub addSampleDetails {
  my ($self, $sampleDetails) = @_;
  $self->{sampleDetails} = $sampleDetails;
}

sub value {
  my ($self, $sample, $row) = @_;
  return $self->{data}{$sample}{$row};
}

sub attributesForSample {
  my ($self, $sample) = @_;
  return $self->{data}{$sample};
}

sub writeBiom {
  my ($self, $outputPath) = @_;
  open (my $fh, ">", $outputPath) or die "$!: $outputPath";
  
  my $date = DateTime->now()->iso8601(); 

  print $fh <<"1";
{
    "id":null,
    "format": "1.0.0",
    "format_url": "http://biom-format.org",
    "type": "$self->{resultType}",
    "generated_by": "MicrobiomeDB",
    "date": "$date",
    "rows":
1
  print $fh (encode_json([
    map {{id => $_, metadata => undef}} @{$self->{rows}}
  ]));
  print $fh <<"2";
,
    "columns":
2
  print $fh (encode_json([
    map {{id => $_, metadata => $self->{sampleDetails}{$_}}} @{$self->{samples}}
  ]));
  my $numRows = @{$self->{rows}};
  my $numSamples = @{$self->{samples}};
  print $fh <<"3";
,
    "matrix_type": "sparse",
    "matrix_element_type": "$self->{matrixElementType}",
    "shape": [$numRows, $numSamples],
    "data": [
3
  my $printCommaBeforeValue;
  RX:
  for my $rx (0..$#{$self->{rows}}){
    SX:
    for my $sx (0..$#{$self->{samples}}){
       my $value = $self->{printMatrixElement}->($self->{data}{$self->{samples}[$sx]}{$self->{rows}[$rx]});
       
       next SX unless $value;

       print $fh "," if $printCommaBeforeValue;
       print $fh "[$rx,$sx,$value]";
       $printCommaBeforeValue //= 1;
    }
  }
  print $fh <<"4";
           ]
}
4
  close $fh;
}

sub writeTabData {
  my ($self, $outputPath) = @_;
  open (my $fh, ">", $outputPath) or die "$!: $outputPath";
  print $fh join("\t", "", @{$self->{samples}})."\n";
  for my $row (@{$self->{rows}}){
    print $fh join("\t", $row, map {  $self->{printMatrixElement}->($self->{data}{$_}{$row})} @{$self->{samples}})."\n";
  }
  close $fh;
}

sub writeTabSampleDetails {
  my ($self, $outputPath) = @_;

  my @sampleDetails = uniq map {keys %{$_}} values %{$self->{sampleDetails}};

  open (my $fh, ">", $outputPath) or die "$!: $outputPath";
  print $fh join("\t", "", @sampleDetails)."\n";
  for my $sample (@{$self->{samples}}){
    print $fh join("\t", $sample, map { $self->{sampleDetails}{$sample}{$_} // ""} @sampleDetails)."\n";
  }
  close $fh;
}

sub parseSamplesTsv {
  my ($inputPath) = @_; 
  
  open (my $fh, "<", $inputPath) or die "$!: $inputPath";
 
  my $header = <$fh>;
  die "No header in $inputPath" unless $header;
  chomp $header;
  my ($__, @samples) = split "\t", $header;
  die "No samples in $inputPath" unless @samples;
  my @rowSampleHashPairs;
  while(my $line = <$fh>){
    chomp $line;
    my ($row, @counts) = split("\t", $line, -1);;
    die "Bad dimensions: $inputPath" unless $#counts == $#samples;
    my %h = map {
      $samples[$_] => $counts[$_]
    } 0..$#counts;
    push @rowSampleHashPairs, [$row, \%h];
  }
  die "No data rows in $inputPath" unless @rowSampleHashPairs;
  return \@samples, \@rowSampleHashPairs;
}

# Expect output in HUMAnN format
# ANAEROFRUCAT-PWY: homolactic fermentation
# ARGDEG-PWY: superpathway of L-arginine, putrescine, and 4-aminobutanoate degradation|g__Escherichia.s__Escherichia_coli
# 1.1.1.103: L-threonine 3-dehydrogenase|g__Escherichia.s__Escherichia_coli
# 1.1.1.103: L-threonine 3-dehydrogenase|unclassified
# 7.2.1.1: NO_NAME

sub detailsFromRowName {
  my ($row) = @_;

  (my $name = $row) =~ s{:.*}{};

  my $description;
  $row =~ m{^.*?:\s*([^\|]+)};
  $description = $1 if $1 and $1 ne "NO_NAME";
  
  
  my ($__, $lineage) = split("\|", $row);

  my $species;
  if($row =~ m{\|}){
    $species = $row;
    $species =~ s{^.*\|}{};
    $species =~ s{^.*s__}{};
    $species = unmessBiobakerySpecies($species);
  }

  return {name => $name, description => $description, species => $species};
}

# Expect output in metaphlan format
# Skip all taxa not at species level - they are summary values
sub prepareWgsTaxa {
  my ($dataPairs) = @_;

  my @rows;
  my @dataPairsResult;
  for my $p (@{$dataPairs}) {
    my ($row, $h) = @$p;
    $row = maybeGoodMetaphlanRow($row);
    next unless $row;
    push @rows, $row;
    push @dataPairsResult, [$row, $h];
  }
  return \@rows, \@dataPairsResult;
}

# Biobakery tools use mangled species names, with space, dash, and a few others changed to underscore
# Try make them good enough again
sub unmessBiobakerySpecies {
  my ($species) = @_;
# Species with IDs
  $species =~ s{_sp_}{ sp. };

# genus, maybe a different genus in []
  $species =~ s{^(\[?[A-Z][a-z]+\]?)_}{$1 };

# last word, like "Ruminococcus gnavus group"
  $species =~ s{_([a-z]+)$}{ $1};

  $species =~ s{oral_taxon_(\d+)$}{oral taxon $1};
  return $species;
}

sub maybeGoodMetaphlanRow {
  my ($row) = @_;
  return if $row eq 'UNKNOWN';
  return unless $row =~ m{k__(.*)\|p__(.*)\|c__(.*)\|o__(.*)\|f__(.*)\|g__(.*)\|s__(.*)};
  return join(";", $1, $2, $3, $4, $5, $6, unmessBiobakerySpecies($7));
}

1;
