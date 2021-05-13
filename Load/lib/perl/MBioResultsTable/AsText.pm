package ApiCommonData::Load::MBioResultsTable::AsText;
use strict;
use warnings;

use base qw/ApiCommonData::Load::MBioResultsTable/;
use DateTime;
use JSON qw/encode_json/;
use List::Util qw/uniq/;

$ApiCommonData::Load::MBioResultsTable::AsText::dataTypeInfo = {
  ampliconTaxa => {
    resultType => 'Taxon table',
    matrixElementType => 'int',
    printMatrixElement => sub {
      my ($x) = @_;
      return $x ? $x : "";
    },
  },
  wgsTaxa => {
    resultType => 'Taxon table',
    matrixElementType => 'float',
    printMatrixElement => sub {
      my ($x) = @_;
      return $x ? sprintf("%.5f", $x) : "";
    },
  },
  wgsFunctions => {
    resultType => 'Function table',
    matrixElementType => 'float',
    printMatrixElement => sub {
      my ($x) = @_;
      return $x ? sprintf("%.5f", $x) : "";
    },
  },
  wgsPathways => {
    resultType => 'Pathway table',
    matrixElementType => 'unicode',
    printMatrixElement => sub {
      my ($abundance, $coverage) = @{$_[0]};
      return $abundance ? sprintf("\"%.5f|$coverage\"", $abundance) : "";
    },

  },
};

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

1;
