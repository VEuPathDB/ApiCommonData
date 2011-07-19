#!/usr/bin/perl
use strict;

# read isolate submission Excel file - 2000-2007 version?
# suggests using BioPerl version 1.60 or above

use Spreadsheet::ParseExcel;

use lib "$ENV{GUS_HOME}/lib/perl/ApiCommonWebsite/Model";
use pcbiPubmed;

# enforce to use bioperl version 1.60
use lib "$ENV{BASE_GUS}/cgi-lib/";

use Bio::SeqIO;
use Bio::Seq::RichSeq;
use Bio::SeqFeature::Generic;
use Bio::Annotation::Collection;
use Bio::Annotation::Reference;
use Bio::Location::Simple;
use Bio::Location::Fuzzy;
use Bio::Species;
use Bio::DB::Taxonomy;
use Getopt::Long qw(GetOptions);
# Bio::Species is deprecated using Bio::Taxon for BioPerl version 1.60

my (%hash, %cn);  # column name
my ($file, $taxon);

GetOptions( "inputfile=s" => \$file,
            "species=s"   => \$taxon );

unless($file && $taxon) {
  die
print <<EOL;
Usage: extractIsolateFromExcel.pl --inputfile isolateSubmissimnExcelFile --species speciesName

Where:
  inputfile  - Isolate Submission Excel File (in Excel 2000-2004 format .xls)
  species    - valid NCBI taxomomy name, e.g Cryptosporidium, Toxoplasma, Plasmodium

EOL
}

while(<DATA>) {
  chomp;
  my ($col, $col_title, $col_name) = split /,/, $_;
  $cn{$col_name} = $col;
}

my $parser = Spreadsheet::ParseExcel->new( CellHandler => \&cell_handler,
                                           NotSetCell  => 1 );

my $workbook = $parser->Parse($file);

sub cell_handler { 
  my $workbook    = $_[0];
  my $sheet_index = $_[1];
  my $row         = $_[2];
  my $col         = $_[3];
  my $cell        = $_[4]; 
  
  # Skip some worksheets and rows (inefficiently).
  return if $sheet_index >= 1;

  my $value = $cell->Value(); 
  $hash{$row}{$col} = $value;
}


my $submitter    = $hash{1}{1};
my $email        = $hash{2}{1};
my $affiliation  = $hash{3}{1};
my $authors      = $hash{4}{1};
my $study        = $hash{5}{1};
my $pmid         = $hash{6}{1};
my $other_ref    = $hash{7}{1};
my $purpose      = $hash{8}{1};
my $release_date = $hash{9}{1};

while(my ($k, $v) = each %hash) {
  next if $k < 13;   # isolate data starts from row 15
  next unless (exists($hash{$k}{0}) && $hash{$k}{0} ne "") ; 

  my $isolate_id   = $hash{$k}{$cn{isolate_id}}; 
  my $species      = $hash{$k}{$cn{species}};
  my $country      = $hash{$k}{$cn{country}};
  my $state        = $hash{$k}{$cn{state}};
  my $county       = $hash{$k}{$cn{county}};
  my $city         = $hash{$k}{$cn{city}};
  my $day          = $hash{$k}{$cn{day}};
  my $month        = $hash{$k}{$cn{month}};
  my $year         = $hash{$k}{$cn{year}};
  my $host         = $hash{$k}{$cn{host}};
  my $genotype     = $hash{$k}{$cn{genotype}};
  my $subtype      = $hash{$k}{$cn{subtype}};
  my $age          = $hash{$k}{$cn{age}};
  my $sex          = $hash{$k}{$cn{sex}};
  my $breed        = $hash{$k}{$cn{breed}};
  my $gps          = $hash{$k}{$cn{gps}};
  my $symptoms     = $hash{$k}{$cn{symptoms}};
  my $habitat      = $hash{$k}{$cn{habitat}};
  my $note         = $hash{$k}{$cn{note}};
  my $source       = $hash{$k}{$cn{isolation_source}};
  my $seq1         = $hash{$k}{$cn{seq1}};
  my $seq1_primer  = $hash{$k}{$cn{seq1_primer}};
  my $seq1_product = $hash{$k}{$cn{seq1_product}};

  $country    .= ", $city" if $city;
  $country    .= ", $state" if $state;
  $country    .= ", $county" if $county;
  $isolate_id  =~ s/\s//g;
  my $length   = length($seq1);
  $year        .= "-$month" if $month;
  $year        .= "-$day" if $day;

  $seq1 =~ s/\W+//g;  

  $note .= "; age: $age" if $age;
  $note .= "; symptoms: $symptoms" if $symptoms;
  $note .= "; habitat: $habitat" if $habitat;
  $note .= "; PCR_primers: $seq1_primer" if $seq1_primer; 
  $note .= "; purpose of sample collection: $purpose" if $purpose; 
  $note =~ s/^; //;
  # NCBI format /note="subtype: IIaA22G1R1; PCR_primers=fwd_name: AL3532"

  die "Cannot find isolate species. Please check column E\n" unless $species;

  my @class = ();
  my $db = Bio::DB::Taxonomy->new(-source => 'entrez');
  foreach my $node ($db->get_tree(($taxon))->get_nodes()) {
    push @class, $node->node_name();
  }

  shift @class;
  push  @class, $species;
  my $taxon = Bio::Species->new(-classification => [reverse @class]); 

  $study =~ s/(\r|\n)/ /g;

  my $seq = Bio::Seq::RichSeq->new( -seq  => $seq1,
                                    -desc => $study,        # DEFINITION
                                    -id   => $isolate_id );

  $seq->add_date("$day-$month-$year");
  $seq->species($taxon);

  my $feat =  Bio::SeqFeature::Generic->new( -start => 1,
                                             -end   => $length,
                                             -primary_tag  => 'source',
                                             -tag    => { 
                                                          mol_type => 'genomic DNA',
                                                        }
                                            );

  $feat->add_tag_value('organism', $species) if $species;
  $feat->add_tag_value('genotype', $genotype) if $genotype;
  $feat->add_tag_value('subtype', $subtype) if $subtype;
  $feat->add_tag_value('isolation_source', $source) if $source;
  $feat->add_tag_value('collection_date', $year) if $year;
  $feat->add_tag_value('host', $host) if $host;
  $feat->add_tag_value('country', $country) if $country;
  $feat->add_tag_value('sex', $sex) if $sex;
  $feat->add_tag_value('breed', $breed) if $breed;
  $feat->add_tag_value('lat-lon', $gps) if $gps;
  $feat->add_tag_value('note', $note) if $note;

  my $location = Bio::Location::Fuzzy->new( -start => '<1', -end => ">$length", -location_type => '..');

  my $gene_feat =  Bio::SeqFeature::Generic->new( -primary_tag  => 'gene',
                                                  -location => $location,
                                                );

  my $cds_feat =  Bio::SeqFeature::Generic->new( -primary_tag  => 'CDS',
                                                 -location => $location,
                                                  -tag    => { 
                                                               codon_start => 1,
                                                               product => $seq1_product,
                                                             }
                                                );

  my $ann = Bio::Annotation::Collection->new(); 

  if($pmid) {
    my $content = pcbiPubmed::setPubmedID($pmid);
    my $title   = pcbiPubmed::fetchTitle($content, "ArticleTitle");
    my $journal = pcbiPubmed::fetchPublication($content, "Journal");
    my $authors = pcbiPubmed::fetchAuthorListLong($content, "Author");

    # reference 1: pubmed if available, otherwise, use study title
    my $ref = Bio::Annotation::Reference->new( -title    => $title,
                                               -authors  => $authors,
                                               -pubmed   => $pmid,
                                               -location => $journal );
    $ann->add_Annotation('reference', $ref); 
  } else {
    my $ref = Bio::Annotation::Reference->new( -title    => $study,
                                               -authors  => $authors,
                                               -location => 'Unpublished');
    $ann->add_Annotation('reference', $ref); 
  }

  # reference 2 from submitter and affliation
  my $ref = Bio::Annotation::Reference->new( -title    => 'Direct Submission',
                                             -authors  => $authors,
                                             -location => "Contact: $submitter $affiliation" );

  $ann->add_Annotation('reference', $ref); 

  # reference 3: other reference links if available
  if($other_ref) {
    my $ref = Bio::Annotation::Reference->new( -title    => 'Direct Submission',
                                               -location => $other_ref);
    $ann->add_Annotation('reference', $ref); 

  }

  $seq->add_SeqFeature($feat); 
  $seq->add_SeqFeature($gene_feat); 
  $seq->add_SeqFeature($cds_feat); 

  $seq->annotation($ann);

  my $out = Bio::SeqIO->new(-file => ">$isolate_id",
                            -format => 'Genbank' );
  $out->write_seq($seq); 
} 

__DATA__
0,Isolate ID,isolate_id
1,Day,day
2,Month,month
3,Year,year
4,Isolate Species,species
5,Genotype,genotype
6,Subtype,subtype
7,Other Organism,organism
8,Country,country
9,Region - State or Province,state
10,County,county
11,City/Village/Locality,city
12,Latitude/Longitude Coordinates,gps
13,Environment Source,isolation_source
14,Host Species,host
15,blank/hidden column P,hidden
16,Race/Breed,breed
17,Age,age
18,Sex,sex
19,Host Material,material
20,Symptoms,symptoms
21,Non-human Habitat,habitat
22,Additional Notes,note
23,Sequence 1 Product or Locus Name,seq1_product
24,Sequence 1 Primer Pairs,seq1_primer
25,Sequence 1 description,seq1_desc
26,Sequence 1,seq1
27,Sequence 2 Product or Locus Name,seq2_product
28,Sequence 2 Primer Pairs,seq2_primer
29,Sequence 2 description,seq2_desc
30,Sequence 2,seq2
31,Sequence 3 Product or Locus Name,seq3_product
32,Sequence 3 Primer Pairs,seq3_primer
33,Sequence 3 description,seq3_desc
34,Sequence 3,seq3
35,Sequence 4 Product or Locus Name,seq4_product
36,Sequence 4 Primer Pairs,seq4_primer
37,Sequence 4 description,seq4_desc
38,Sequence 4,seq4
