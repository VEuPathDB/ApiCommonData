#!/usr/bin/perl
use strict;

# read isolate submission Excel file - 2000-2007 version?

use Spreadsheet::ParseExcel;

use lib "$ENV{GUS_HOME}/lib/perl/ApiCommonWebsite/Model";

use Bio::SeqIO;
use Bio::Seq::RichSeq;

my (%hash, %cn);  # column name
my $file = shift or die "cannot open the Isolate Submission Excel form\n";

my %idhash = ();

my $col = 0;
while(<DATA>) {
  chomp;
  next if /^$/;
  my ($col_head, $col_title, $col_name) = split /,/, $_;
  $cn{$col_name} = $col;
  $col++; 
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



my @author_list  = split /\,/, $authors;
my $count = @author_list;

my $author_form = "";

for(my $i=1; $i<=$count; $i++) {
  my $name = $author_list[$i-1];
  $name =~ s/\s+$//g;
  $name =~ s/^\s+//g;

  my @names = split /\s/, $name;

  my $f = shift(@names);
  my $l = pop(@names);

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

  # in case of duplicate isolate ids
	if(exists $idhash{$isolate_id}) {
	  $isolate_id .= '_1';
	  $idhash{$isolate_id} = 1;
	} else {
	  $idhash{$isolate_id} = 1;
	}

  my $species      = $hash{$k}{$cn{species}};
  my $country      = $hash{$k}{$cn{country}};
  my $state        = $hash{$k}{$cn{state}};
  my $county       = $hash{$k}{$cn{county}};
  my $city         = $hash{$k}{$cn{city}};
  my $day          = $hash{$k}{$cn{day}} || '01';
  my $month        = $hash{$k}{$cn{month}} || 'Jan';
  my $year         = $hash{$k}{$cn{year}};
  my $host         = $hash{$k}{$cn{host}};
  my $genotype     = $hash{$k}{$cn{genotype}};
  my $subtype      = $hash{$k}{$cn{subtype}};
  my $age          = $hash{$k}{$cn{age}};
  my $sex          = $hash{$k}{$cn{sex}};
  my $material     = $hash{$k}{$cn{material}};
  my $breed        = $hash{$k}{$cn{breed}};
  my $lat          = $hash{$k}{$cn{lat}};
  my $lon          = $hash{$k}{$cn{lon}};
  my $alt          = $hash{$k}{$cn{alt}};
  my $symptoms     = $hash{$k}{$cn{symptoms}};
  my $habitat      = $hash{$k}{$cn{habitat}};
  my $note         = $hash{$k}{$cn{note}};
  my $source       = $hash{$k}{$cn{isolation_source}};

  my $seq1                 = $hash{$k}{$cn{seq1}};
  my $seq1_primer_names    = $hash{$k}{$cn{seq1_primer_names}};
  my $seq1_primer_seqs     = $hash{$k}{$cn{seq1_primer_seqs}};
  my $seq1_product         = $hash{$k}{$cn{seq1_product}};
  my $seq1_desc            = $hash{$k}{$cn{seq1_desc}};
  my $seq1_genbank         = $hash{$k}{$cn{seq1_genbank}};
  my $seq1_trace           = $hash{$k}{$cn{seq1_trace}};

  my $seq2                 = $hash{$k}{$cn{seq2}};
  my $seq2_primer_names    = $hash{$k}{$cn{seq2_primer_names}};
  my $seq2_primer_seqs     = $hash{$k}{$cn{seq2_primer_seqs}};
  my $seq2_product         = $hash{$k}{$cn{seq2_product}};
  my $seq2_desc            = $hash{$k}{$cn{seq2_desc}};
  my $seq2_genbank         = $hash{$k}{$cn{seq2_genbank}};
  my $seq2_trace           = $hash{$k}{$cn{seq2_trace}};

  my $seq3                 = $hash{$k}{$cn{seq3}};
  my $seq3_primer_names    = $hash{$k}{$cn{seq3_primer_names}};
  my $seq3_primer_seqs     = $hash{$k}{$cn{seq3_primer_seqs}};
  my $seq3_product         = $hash{$k}{$cn{seq3_product}};
  my $seq3_desc            = $hash{$k}{$cn{seq3_desc}};
  my $seq3_genbank         = $hash{$k}{$cn{seq3_genbank}};
  my $seq3_trace           = $hash{$k}{$cn{seq3_trace}};

  my $seq4                 = $hash{$k}{$cn{seq4}};
  my $seq4_primer_names    = $hash{$k}{$cn{seq4_primer_names}};
  my $seq4_primer_seqs     = $hash{$k}{$cn{seq4_primer_seqs}};
  my $seq4_product         = $hash{$k}{$cn{seq4_product}};
  my $seq4_desc            = $hash{$k}{$cn{seq4_desc}};
  my $seq4_genbank         = $hash{$k}{$cn{seq4_genbank}};
  my $seq4_trace           = $hash{$k}{$cn{seq4_trace}};

  $seq1_primer_names =~ s/\s+//g; 
  $seq2_primer_names =~ s/\s+//g; 
  $seq3_primer_names =~ s/\s+//g; 
  $seq4_primer_names =~ s/\s+//g; 

  $seq1_primer_seqs =~ s/\s+//g;
  $seq2_primer_seqs =~ s/\s+//g;
  $seq3_primer_seqs =~ s/\s+//g;
  $seq4_primer_seqs =~ s/\s+//g;

  my @seq1_primer_name = split /;/, $seq1_primer_names;
  my @seq2_primer_name = split /;/, $seq2_primer_names;
  my @seq3_primer_name = split /;/, $seq3_primer_names;
  my @seq4_primer_name = split /;/, $seq4_primer_names;

  my @seq1_primer_seq = split /;/, $seq1_primer_seqs;
  my @seq2_primer_seq = split /;/, $seq2_primer_seqs;
  my @seq3_primer_seq = split /;/, $seq3_primer_seqs;
  my @seq4_primer_seq = split /;/, $seq4_primer_seqs;

  $country    .= ": $city" if $city;
  $country    .= ", $county" if $county;
  $country    .= ", $state" if $state;
  $isolate_id  =~ s/\s//g;

  $note .= "; age: $age" if $age;
  $note .= "; symptoms: $symptoms" if $symptoms;
  $note .= "; habitat: $habitat" if $habitat;
  $note .= "; purpose of sample collection: $purpose" if $purpose;
  $note .= "; Altitude: $alt" if $alt;
  $note =~ s/^; //;

  my @mon = qw/null Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
  $month =~ s/^0// if $month;

  my $collection_date = "";
  $collection_date  = sprintf("%02d", $day);
  $collection_date .= "-". $mon[$month]; 
  $collection_date .= "-$year" if $year;

  die "Cannot find isolate species. Please check column E\n" unless $species;

  $study =~ s/(\r|\n)/ /g;

  my @seqs = (
         [$seq1, $seq1_product, $seq1_desc, \@seq1_primer_name, \@seq1_primer_seq, $seq1_trace],
         [$seq2, $seq2_product, $seq2_desc, \@seq2_primer_name, \@seq2_primer_seq, $seq2_trace],
         [$seq3, $seq3_product, $seq3_desc, \@seq3_primer_name, \@seq3_primer_seq, $seq3_trace],
         [$seq4, $seq4_product, $seq4_desc, \@seq4_primer_name, \@seq4_primer_seq, $seq4_trace]);

  my $count = 1;
  foreach my $s (@seqs) {

    my $sequence        = $s->[0];
    my $product         = $s->[1];
    my $seq_description = $s->[2];
    my @primer_names    = @{$s->[3]};
    my @primer_seqs     = @{$s->[4]};
    my $trace           = $s->[5];

    my $file_name       = "$isolate_id.$count";

    next unless $sequence;

    $sequence =~ s/\W+//g;
    my $length   = length($sequence);

		$note .= "; trace file: $trace" if $trace;
		$note .= "; seq description: $seq_description" if $seq_description;

    my $modifier = "";
    $modifier .= "[organism=$species]" if $species;
    $modifier .= "[genotype=$genotype]" if $genotype;
    $modifier .= "[subtype=$subtype]" if $subtype;
    $modifier .= "[isolation-source=$source]" if $source;
    $modifier .= "[collection-date=$collection_date]" if $year;
    $modifier .= "[host=$host]" if $host;
    $modifier .= "[isolation-source=$material]" if $material;
    $modifier .= "[country=$country]" if $country;
    $modifier .= "[sex=$sex]" if $sex;
    $modifier .= "[breed=$breed]" if $breed;
    $modifier .= "[lat-lon=$lat $lon]" if ($lat && $lon) ;
    $modifier .= "[note=$note]" if $note;
    $modifier .= "[protein=$product]" if $product;

    for(my $i = 0; $i <= $#primer_names; $i=$i+2) {
      $modifier .= "[fwd-PCR-primer-name=$primer_names[$i]]"; 
      $modifier .= "[fwd-PCR-primer-seq=$primer_seqs[$i]]"; 
      $modifier .= "[rev-PCR-primer-name=$primer_names[$i+1]]"; 
      $modifier .= "[rev-PCR-primer-seq=$primer_seqs[$i+1]]"; 
    }

    my $seq = Bio::Seq::RichSeq->new( -seq  => $sequence,
                                      -desc => "$modifier $study",
                                      -id   => $file_name );

    my $out = Bio::SeqIO->new(-file => ">$file_name.fsa", -format => 'Fasta' );
    $out->write_seq($seq);

    #open  (F, ">$file_name.tbl");
    #print F ">Feature\t$file_name\n";
    #print F "<1\t>$length\tgene\n";
    #print F "\t\t\tgene\tgene_name\n"; ?
    #print F "<1\t>$length\tCDS\n";
    #print F "\t\t\tproduct\t$product\n" if $product;
    #print F "\t\t\tnote\t$seq_description\n";
    #close F;

    $count++;
  }
}

# under current directory run tbl2asn to generate asn files for genbank submission
my $cmd = "linux.tbl2asn -t template.sbt -p . -k cm -V vb";
system($cmd);

__DATA__
A,Isolate ID,isolate_id
B,Day,day
C,Month,month
D,Year,year
E,Day,e_day
F,Month,e_month
G,Year,e_year
H,Isolate Species,species
I,Genotype,genotype
J,Subtype,subtype
K,Other Organism,organism
L,Country,country
M,Region - State or Province,state
N,County,county
O,City/Village/Locality,city
P,Latitude,lat
Q,Longitude,lon
R,Altitude,alt
S,Environment Source,isolation_source
T,Host Species,host
U,Race/Breed,breed
V,Age,age
W,Sex,sex
X,Host Material,material
Y,Symptoms,symptoms
Z,Non-human Habitat,habitat
AA,Additional Notes,note
AB,Sequence 1 Product or Locus Name,seq1_product
AC,Sequence 1 Primer Name,seq1_primer_names
AD,Sequence 1 Primer Seq,seq1_primer_seqs
AE,Sequence 1 Description,seq1_desc
AF,Sequence 1,seq1
AG,Sequence 1 Genbank Number,seq1_genbank
AH,Sequence 1 Trace File,seq1_trace
AI,Sequence 2 Product or Locus Name,seq2_product
AJ,Sequence 2 Primer Name,seq2_primer_names
AK,Sequence 2 Primer Seq,seq2_primer_seqs
AL,Sequence 2 Description,seq2_desc
AM,Sequence 2,seq2
AN,Sequence 2 Genbank Number,seq2_genbank
AO,Sequence 2 Trace File,seq2_trace
AP,Sequence 3 Product or Locus Name,seq3_product
AQ,Sequence 3 Primer Name,seq3_primer_names
AR,Sequence 3 Primer Seq,seq3_primer_seqs
AS,Sequence 3 Description,seq3_desc
AT,Sequence 3,seq3
AU,Sequence 3 Genbank Number,seq3_genbank
AV,Sequence 3 Trace File,seq3_trace
AW,Sequence 4 Product or Locus Name,seq4_product
AX,Sequence 4 Primer Name,seq4_primer_names
AY,Sequence 4 Primer Seq,seq4_primer_seqs
AZ,Sequence 4 Description,seq4_desc
BA,Sequence 4,seq4
BB,Sequence 4 Genbank Number,seq4_genbank
BC,Sequence 4 Trace File,seq4_trace
