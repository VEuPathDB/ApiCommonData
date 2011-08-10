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
            "genus=s"     => \$taxon );

unless($file && $taxon) {
  die
print <<EOL;
Usage: extractIsolateFromExcel.pl --inputfile isolateSubmissimnExcelFile --genus genusName

Where:
  inputfile - Isolate Submission Excel File (in Excel 2000-2004 format .xls)
  genus     - valid NCBI taxomomy name, e.g Cryptosporidium, Toxoplasma, Plasmodium

EOL
}

while(<DATA>) {
  chomp;
  my ($col, $col_head, $col_title, $col_name) = split /,/, $_;
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
  next if $k < 13;   # isolate data starts from row 15, k is the row num
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

  my $seq1                 = $hash{$k}{$cn{seq1}};
  my $seq1_fwd_primer_name = $hash{$k}{$cn{seq1_fwd_primer_name}};
  my $seq1_fwd_primer_seq  = $hash{$k}{$cn{seq1_fwd_primer_seq}};
  my $seq1_rev_primer_name = $hash{$k}{$cn{seq1_rev_primer_name}};
  my $seq1_rev_primer_seq  = $hash{$k}{$cn{seq1_rev_primer_seq}};
  my $seq1_product         = $hash{$k}{$cn{seq1_product}};
  my $seq1_desc            = $hash{$k}{$cn{seq1_desc}};

  my $seq2                 = $hash{$k}{$cn{seq2}};
  my $seq2_fwd_primer_name = $hash{$k}{$cn{seq2_fwd_primer_name}};
  my $seq2_fwd_primer_seq  = $hash{$k}{$cn{seq2_fwd_primer_seq}};
  my $seq2_rev_primer_name = $hash{$k}{$cn{seq2_rev_primer_name}};
  my $seq2_rev_primer_seq  = $hash{$k}{$cn{seq2_rev_primer_seq}};
  my $seq2_product         = $hash{$k}{$cn{seq2_product}};
  my $seq2_desc            = $hash{$k}{$cn{seq2_desc}};

  my $seq3                 = $hash{$k}{$cn{seq3}};
  my $seq3_fwd_primer_name = $hash{$k}{$cn{seq3_fwd_primer_name}};
  my $seq3_fwd_primer_seq  = $hash{$k}{$cn{seq3_fwd_primer_seq}};
  my $seq3_rev_primer_name = $hash{$k}{$cn{seq3_rev_primer_name}};
  my $seq3_rev_primer_seq  = $hash{$k}{$cn{seq3_rev_primer_seq}};
  my $seq3_product         = $hash{$k}{$cn{seq3_product}};
  my $seq3_desc            = $hash{$k}{$cn{seq3_desc}};

  my $seq4                 = $hash{$k}{$cn{seq4}};
  my $seq4_fwd_primer_name = $hash{$k}{$cn{seq4_fwd_primer_name}};
  my $seq4_fwd_primer_seq  = $hash{$k}{$cn{seq4_fwd_primer_seq}};
  my $seq4_rev_primer_name = $hash{$k}{$cn{seq4_rev_primer_name}};
  my $seq4_rev_primer_seq  = $hash{$k}{$cn{seq4_rev_primer_seq}};
  my $seq4_product         = $hash{$k}{$cn{seq4_product}};
  my $seq4_desc            = $hash{$k}{$cn{seq4_desc}};

  $country    .= ", $city" if $city;
  $country    .= ", $state" if $state;
  $country    .= ", $county" if $county;
  $isolate_id  =~ s/\s//g;
  $year        .= "-$month" if $month;
  $year        .= "-$day" if $day;

  $note .= "; age: $age" if $age;
  $note .= "; symptoms: $symptoms" if $symptoms;
  $note .= "; habitat: $habitat" if $habitat;
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

  my @seqs = (
         [$seq1, $seq1_fwd_primer_name, $seq1_fwd_primer_seq, $seq1_rev_primer_name, $seq1_rev_primer_seq, $seq1_product, $seq1_desc],
         [$seq2, $seq2_fwd_primer_name, $seq2_fwd_primer_seq, $seq2_rev_primer_name, $seq2_rev_primer_seq, $seq2_product, $seq2_desc],
         [$seq3, $seq3_fwd_primer_name, $seq3_fwd_primer_seq, $seq3_rev_primer_name, $seq3_rev_primer_seq, $seq3_product, $seq3_desc],
         [$seq4, $seq4_fwd_primer_name, $seq4_fwd_primer_seq, $seq4_rev_primer_name, $seq4_rev_primer_seq, $seq4_product, $seq4_desc]
             );

  my $count = 0;
  foreach my $s (@seqs) {
   
    my $sequence        = $s->[0]; 
    my $fwd_primer_name = $s->[1];
    my $fwd_primer_seq  = $s->[2];
    my $rev_primer_name = $s->[3];
    my $rev_primer_seq  = $s->[4];
    my $product         = $s->[5];
    my $seq_description = $s->[6];
    my $file_name       = $isolate_id;            

    next unless $sequence; 

    $sequence =~ s/\W+//g;  
    my $length   = length($sequence);

    $file_name = "$isolate_id.$count" unless $count == 0;

    my $seq = Bio::Seq::RichSeq->new( -seq  => $sequence,
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
    $feat->add_tag_value('fwd-PCR-primer-name', $fwd_primer_name) if $fwd_primer_name;
    $feat->add_tag_value('fwd-PCR-primer-seq', $fwd_primer_seq) if $fwd_primer_seq;
    $feat->add_tag_value('rev-PCR-primer-name', $rev_primer_name) if $rev_primer_name;
    $feat->add_tag_value('rev-PCR-primer-seq', $rev_primer_seq) if $rev_primer_seq;

    my $location = Bio::Location::Fuzzy->new( -start => '<1', -end => ">$length", -location_type => '..');

    my $gene_feat =  Bio::SeqFeature::Generic->new( -primary_tag  => 'gene',
                                                    -location     => $location );

    my $cds_feat =  Bio::SeqFeature::Generic->new( -primary_tag  => 'CDS',
                                                   -location     => $location,
                                                   -tag          => { codon_start => 1,
                                                                      product     => $product,
                                                                      note        => $seq_description 
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

    my $out = Bio::SeqIO->new(-file => ">$file_name", -format => 'Genbank' );
    $out->write_seq($seq); 
    $count++;
  }
} 

__DATA__
0,A,Isolate ID,isolate_id
1,B,Day,day
2,C,Month,month
3,D,Year,year
4,E,Isolate Species,species
5,F,Genotype,genotype
6,G,Subtype,subtype
7,H,Other Organism,organism
8,I,Country,country
9,J,Region - State or Province,state
10,K,County,county
11,L,City/Village/Locality,city
12,M,Latitude/Longitude Coordinates,gps
13,N,Environment Source,isolation_source
14,O,Host Species,host
15,P,blank/hidden column P,hidden
16,Q,Race/Breed,breed
17,R,Age,age
18,S,Sex,sex
19,T,Host Material,material
20,U,Symptoms,symptoms
21,V,Non-human Habitat,habitat
22,W,Additional Notes,note
23,X,Sequence 1 Product or Locus Name,seq1_product
24,Y,Sequence 1 Forward Primer Name,seq1_fwd_primer_name
25,Z,Sequence 1 Forward Primer Seq,seq1_fwd_primer_seq
26,AA,Sequence 1 Reverse Primer Name,seq1_rev_primer_name
27,AB,Sequence 1 Reverse Primer Seq,seq1_rev_primer_seq
28,AC,Sequence 1 Description,seq1_desc
29,AD,Sequence 1,seq1
30,AE,Sequence 2 Product or Locus Name,seq2_product
31,AF,Sequence 2 Forward Primer Name,seq2_fwd_primer_name
32,AG,Sequence 2 Forward Primer Seq,seq2_fwd_primer_seq
33,AH,Sequence 2 Reverse Primer Name,seq2_rev_primer_name
34,AI,Sequence 2 Reverse Primer Seq,seq2_rev_primer_seq
35,AJ,Sequence 2 Description,seq2_desc
36,AK,Sequence 2,seq2
37,AL,Sequence 3 Product or Locus Name,seq3_product
38,AM,Sequence 3 Forward Primer Name,seq3_fwd_primer_name
39,AN,Sequence 3 Forward Primer Seq,seq3_fwd_primer_seq
40,AO,Sequence 3 Reverse Primer Name,seq3_rev_primer_name
41,AP,Sequence 3 Reverse Primer Seq,seq3_rev_primer_seq
42,AQ,Sequence 3 Description,seq3_desc
43,AR,Sequence 3,seq3
44,AS,Sequence 4 Product or Locus Name,seq4_product
45,AT,Sequence 4 Forward Primer Name,seq4_fwd_primer_name
46,AU,Sequence 4 Forward Primer Seq,seq4_fwd_primer_seq
47,AV,Sequence 4 Reverse Primer Name,seq4_rev_primer_name
48,AW,Sequence 4 Reverse Primer Seq,seq4_rev_primer_seq
49,AX,Sequence 4 Description,seq4_desc
50,AY,Sequence 4,seq4
