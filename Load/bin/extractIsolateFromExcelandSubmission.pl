#!/usr/bin/perl
use strict;

# read isolate submission Excel file - 2000-2007 version?

use Spreadsheet::ParseExcel;

use lib "$ENV{GUS_HOME}/lib/perl/ApiCommonWebsite/Model";

use Bio::SeqIO;
use Bio::Seq::RichSeq;

my (%hash, %cn);  # column name
my $file = shift or die "cannot open the Isolate Submission Excel form\n";

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

my $first_name   = $hash{2}{1};
my $last_name    = $hash{3}{1};
my $department   = $hash{4}{1};
my $institution  = $hash{5}{1};
my $street       = $hash{6}{1};
my $city         = $hash{7}{1};
my $state        = $hash{8}{1};
my $zip          = $hash{9}{1};
my $country      = $hash{10}{1};
my $phone        = $hash{11}{1};
my $email        = $hash{12}{1};

my $authors      = $hash{13}{1};
my $study        = $hash{14}{1};
my $pmid         = $hash{15}{1};
my $other_ref    = $hash{16}{1};
my $purpose      = $hash{17}{1};
my $release_date = $hash{18}{1};


my @author_list  = split /,/, $authors;
my $count = @author_list;

my $author_form = "";

for(my $i=1; $i<=$count; $i++) {
  my $name = $author_list[$i-1];
  $name =~ s/\s+$//g;
  $name =~ s/^\s+//g;
  my ($f, $l) = split /\s/, $name;

  $author_form .= " -F 'author_first_$i=$f' -F 'author_mi_$i=' -F 'author_last_$i=$l' -F 'author_suffix_$i='";
}

my $publish_status = $pmid ? "published" : "unpublished";

my $cmd =<<EOL;
curl -F 'first_name=$first_name'
     -F 'last_name=$last_name'
     -F 'department=$department'
     -F 'institution=$institution'
     -F 'street=$street'
     -F 'city=$city'
     -F 'state=$state'
     -F 'zip=$zip'
     -F 'country=$country'
     -F 'phone=$phone'
     -F 'fax=none'
     -F 'email=$email'
     $author_form
     -F 'author_first_='
     -F 'author_mi_='
     -F 'author_last_='
     -F 'author_suffix_='
     -F 'cit_status_radio=$publish_status'
     -F 'citation_title=$study'
     -F 'jrnl_title='
     -F 'jrnl_yr='
     -F 'jrnl_vol='
     -F 'jrnl_issue='
     -F 'jrnl_pages_from='
     -F 'jrnl_pages_to='
     -F 'cit_pmid=$pmid'
     -F 'cit_auth_radio=same'
     -F 'cit_author_first_1='
     -F 'cit_author_mi_1='
     -F 'cit_author_last_1='
     -F 'cit_author_suffix_1='
     -F 'cit_author_first_='
     -F 'cit_author_mi_='
     -F 'cit_author_last_='
     -F 'cit_author_suffix_='
     -F 'submit=Create Template'
     http://www.ncbi.nlm.nih.gov/WebSub/template.cgi
     > template.sbt
EOL

$cmd =~ s/\r|\n//igc;
system($cmd);


while(my ($k, $v) = each %hash) {
  next if $k < 23;   # isolate data starts from row 15, k is the row num
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

  die "Cannot find isolate species. Please check column E\n" unless $species;

  $study =~ s/(\r|\n)/ /g;

  my @seqs = (
         [$seq1, $seq1_fwd_primer_name, $seq1_fwd_primer_seq, $seq1_rev_primer_name, $seq1_rev_primer_seq, $seq1_product, $seq1_desc],
         [$seq2, $seq2_fwd_primer_name, $seq2_fwd_primer_seq, $seq2_rev_primer_name, $seq2_rev_primer_seq, $seq2_product, $seq2_desc],
         [$seq3, $seq3_fwd_primer_name, $seq3_fwd_primer_seq, $seq3_rev_primer_name, $seq3_rev_primer_seq, $seq3_product, $seq3_desc],
         [$seq4, $seq4_fwd_primer_name, $seq4_fwd_primer_seq, $seq4_rev_primer_name, $seq4_rev_primer_seq, $seq4_product, $seq4_desc]
             );

  my $count = 1;
  foreach my $s (@seqs) {

    my $sequence        = $s->[0];
    my $fwd_primer_name = $s->[1];
    my $fwd_primer_seq  = $s->[2];
    my $rev_primer_name = $s->[3];
    my $rev_primer_seq  = $s->[4];
    my $product         = $s->[5];
    my $seq_description = $s->[6];
    my $file_name       = "$isolate_id.$count";

    next unless $sequence;

    $sequence =~ s/\W+//g;
    my $length   = length($sequence);

    my $modifier = "";
    $modifier .= "[organism=$species]" if $species;
    $modifier .= "[genotype=$genotype]" if $genotype;
    $modifier .= "[subtype=$subtype]" if $subtype;
    $modifier .= "[isolation-source=$source]" if $source;
    $modifier .= "[collection-date=$year]" if $year;
    $modifier .= "[host=$host]" if $host;
    $modifier .= "[country=$country]" if $country;
    $modifier .= "[sex=$sex]" if $sex;
    $modifier .= "[breed=$breed]" if $breed;
    $modifier .= "[lat-lon=$gps]" if $gps;
    $modifier .= "[note=$note]" if $note;
    $modifier .= "[fwd-PCR-primer-name=$fwd_primer_name]" if $fwd_primer_name;
    $modifier .= "[fwd-PCR-primer-seq=$fwd_primer_seq]" if $fwd_primer_seq;
    $modifier .= "[rev-PCR-primer-name=$rev_primer_name]" if $rev_primer_name;
    $modifier .= "[rev-PCR-primer-seq=$rev_primer_seq]" if $rev_primer_seq;

    my $seq = Bio::Seq::RichSeq->new( -seq  => $sequence,
                                      -desc => "$study $modifier",
                                      -id   => $file_name );

    my $out = Bio::SeqIO->new(-file => ">$file_name.fsa", -format => 'Fasta' );
    $out->write_seq($seq);

    open  (F, ">$file_name.tbl");
    print F ">Feature\t$file_name\n";
    print F "<1\t>$length\tgene\n";
    #print F "\t\t\tgene\tgene_name\n"; ?
    print F "<1\t>$length\tCDS\n";
    print F "\t\t\tproduct\t$product\n" if $product;
    print F "\t\t\tnote\t$seq_description\n";

    close F;

    $count++;
  }
}

# under current directory run tbl2asn to generate asn files for genbank submission
my $cmd = "linux.tbl2asn -t template.sbt -p . -k m -V vb";
system($cmd);

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
