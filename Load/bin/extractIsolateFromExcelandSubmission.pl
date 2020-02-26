#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
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

  my $size = @names;
  my $f = "";
  my $l = "";
  my $m = "";
  my $s = "";

  if($size == 2) {
    $f = $names[0];
    $l = $names[1];
  } elsif($size == 3) {
    $f = $names[0];
    $m = $names[1];
    $l = $names[2];
  } elsif($size == 4) {
    $f = $names[0];
    $m = $names[1];
    $l = $names[2];
    $s = $names[3];
  } else {
    $f = shift(@names);
    $l = pop(@names);
  }

  $author_form .= " -F 'author_first_$i=$f' -F 'author_mi_$i=$m' -F 'author_last_$i=$l' -F 'author_suffix_$i=$s'";
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
#system($cmd);


while(my ($k, $v) = each %hash) {
  next if $k < 23;   # isolate data starts from row 15, k is the row num
  next unless (exists($hash{$k}{0}) && $hash{$k}{0} ne "") ;

  my $isolate_id   = $hash{$k}{$cn{isolate_id}};
  $isolate_id  =~ s/\s/_/g;

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

  my $seq5                 = $hash{$k}{$cn{seq5}};
  my $seq5_primer_names    = $hash{$k}{$cn{seq5_primer_names}};
  my $seq5_primer_seqs     = $hash{$k}{$cn{seq5_primer_seqs}};
  my $seq5_product         = $hash{$k}{$cn{seq5_product}};
  my $seq5_desc            = $hash{$k}{$cn{seq5_desc}};
  my $seq5_genbank         = $hash{$k}{$cn{seq5_genbank}};
  my $seq5_trace           = $hash{$k}{$cn{seq5_trace}};

  my $seq6                 = $hash{$k}{$cn{seq6}};
  my $seq6_primer_names    = $hash{$k}{$cn{seq6_primer_names}};
  my $seq6_primer_seqs     = $hash{$k}{$cn{seq6_primer_seqs}};
  my $seq6_product         = $hash{$k}{$cn{seq6_product}};
  my $seq6_desc            = $hash{$k}{$cn{seq6_desc}};
  my $seq6_genbank         = $hash{$k}{$cn{seq6_genbank}};
  my $seq6_trace           = $hash{$k}{$cn{seq6_trace}};

  my $seq7                 = $hash{$k}{$cn{seq7}};
  my $seq7_primer_names    = $hash{$k}{$cn{seq7_primer_names}};
  my $seq7_primer_seqs     = $hash{$k}{$cn{seq7_primer_seqs}};
  my $seq7_product         = $hash{$k}{$cn{seq7_product}};
  my $seq7_desc            = $hash{$k}{$cn{seq7_desc}};
  my $seq7_genbank         = $hash{$k}{$cn{seq7_genbank}};
  my $seq7_trace           = $hash{$k}{$cn{seq7_trace}};

  my $seq8                 = $hash{$k}{$cn{seq8}};
  my $seq8_primer_names    = $hash{$k}{$cn{seq8_primer_names}};
  my $seq8_primer_seqs     = $hash{$k}{$cn{seq8_primer_seqs}};
  my $seq8_product         = $hash{$k}{$cn{seq8_product}};
  my $seq8_desc            = $hash{$k}{$cn{seq8_desc}};
  my $seq8_genbank         = $hash{$k}{$cn{seq8_genbank}};
  my $seq8_trace           = $hash{$k}{$cn{seq8_trace}};

  my $seq9                 = $hash{$k}{$cn{seq9}};
  my $seq9_primer_names    = $hash{$k}{$cn{seq9_primer_names}};
  my $seq9_primer_seqs     = $hash{$k}{$cn{seq9_primer_seqs}};
  my $seq9_product         = $hash{$k}{$cn{seq9_product}};
  my $seq9_desc            = $hash{$k}{$cn{seq9_desc}};
  my $seq9_genbank         = $hash{$k}{$cn{seq9_genbank}};
  my $seq9_trace           = $hash{$k}{$cn{seq9_trace}};

  my $seq10                 = $hash{$k}{$cn{seq10}};
  my $seq10_primer_names    = $hash{$k}{$cn{seq10_primer_names}};
  my $seq10_primer_seqs     = $hash{$k}{$cn{seq10_primer_seqs}};
  my $seq10_product         = $hash{$k}{$cn{seq10_product}};
  my $seq10_desc            = $hash{$k}{$cn{seq10_desc}};
  my $seq10_genbank         = $hash{$k}{$cn{seq10_genbank}};
  my $seq10_trace           = $hash{$k}{$cn{seq10_trace}};

  my $seq11                 = $hash{$k}{$cn{seq11}};
  my $seq11_primer_names    = $hash{$k}{$cn{seq11_primer_names}};
  my $seq11_primer_seqs     = $hash{$k}{$cn{seq11_primer_seqs}};
  my $seq11_product         = $hash{$k}{$cn{seq11_product}};
  my $seq11_desc            = $hash{$k}{$cn{seq11_desc}};
  my $seq11_genbank         = $hash{$k}{$cn{seq11_genbank}};
  my $seq11_trace           = $hash{$k}{$cn{seq11_trace}};

  my $seq12                 = $hash{$k}{$cn{seq12}};
  my $seq12_primer_names    = $hash{$k}{$cn{seq12_primer_names}};
  my $seq12_primer_seqs     = $hash{$k}{$cn{seq12_primer_seqs}};
  my $seq12_product         = $hash{$k}{$cn{seq12_product}};
  my $seq12_desc            = $hash{$k}{$cn{seq12_desc}};
  my $seq12_genbank         = $hash{$k}{$cn{seq12_genbank}};
  my $seq12_trace           = $hash{$k}{$cn{seq12_trace}};

  my $seq13                 = $hash{$k}{$cn{seq13}};
  my $seq13_primer_names    = $hash{$k}{$cn{seq13_primer_names}};
  my $seq13_primer_seqs     = $hash{$k}{$cn{seq13_primer_seqs}};
  my $seq13_product         = $hash{$k}{$cn{seq13_product}};
  my $seq13_desc            = $hash{$k}{$cn{seq13_desc}};
  my $seq13_genbank         = $hash{$k}{$cn{seq13_genbank}};
  my $seq13_trace           = $hash{$k}{$cn{seq13_trace}};

  my $seq14                 = $hash{$k}{$cn{seq14}};
  my $seq14_primer_names    = $hash{$k}{$cn{seq14_primer_names}};
  my $seq14_primer_seqs     = $hash{$k}{$cn{seq14_primer_seqs}};
  my $seq14_product         = $hash{$k}{$cn{seq14_product}};
  my $seq14_desc            = $hash{$k}{$cn{seq14_desc}};
  my $seq14_genbank         = $hash{$k}{$cn{seq14_genbank}};
  my $seq14_trace           = $hash{$k}{$cn{seq14_trace}};

  my $seq15                 = $hash{$k}{$cn{seq15}};
  my $seq15_primer_names    = $hash{$k}{$cn{seq15_primer_names}};
  my $seq15_primer_seqs     = $hash{$k}{$cn{seq15_primer_seqs}};
  my $seq15_product         = $hash{$k}{$cn{seq15_product}};
  my $seq15_desc            = $hash{$k}{$cn{seq15_desc}};
  my $seq15_genbank         = $hash{$k}{$cn{seq15_genbank}};
  my $seq15_trace           = $hash{$k}{$cn{seq15_trace}};

  my $seq16                 = $hash{$k}{$cn{seq16}};
  my $seq16_primer_names    = $hash{$k}{$cn{seq16_primer_names}};
  my $seq16_primer_seqs     = $hash{$k}{$cn{seq16_primer_seqs}};
  my $seq16_product         = $hash{$k}{$cn{seq16_product}};
  my $seq16_desc            = $hash{$k}{$cn{seq16_desc}};
  my $seq16_genbank         = $hash{$k}{$cn{seq16_genbank}};
  my $seq16_trace           = $hash{$k}{$cn{seq16_trace}};

  my $seq17                 = $hash{$k}{$cn{seq17}};
  my $seq17_primer_names    = $hash{$k}{$cn{seq17_primer_names}};
  my $seq17_primer_seqs     = $hash{$k}{$cn{seq17_primer_seqs}};
  my $seq17_product         = $hash{$k}{$cn{seq17_product}};
  my $seq17_desc            = $hash{$k}{$cn{seq17_desc}};
  my $seq17_genbank         = $hash{$k}{$cn{seq17_genbank}};
  my $seq17_trace           = $hash{$k}{$cn{seq17_trace}};

  $seq1_primer_seqs =~ s/\s+//g;
  $seq2_primer_seqs =~ s/\s+//g;
  $seq3_primer_seqs =~ s/\s+//g;
  $seq4_primer_seqs =~ s/\s+//g;
  $seq5_primer_seqs =~ s/\s+//g;
  $seq6_primer_seqs =~ s/\s+//g;
  $seq7_primer_seqs =~ s/\s+//g;
  $seq8_primer_seqs =~ s/\s+//g;
  $seq9_primer_seqs =~ s/\s+//g;
  $seq10_primer_seqs =~ s/\s+//g;
  $seq11_primer_seqs =~ s/\s+//g;
  $seq12_primer_seqs =~ s/\s+//g;
  $seq13_primer_seqs =~ s/\s+//g;
  $seq14_primer_seqs =~ s/\s+//g;
  $seq15_primer_seqs =~ s/\s+//g;
  $seq16_primer_seqs =~ s/\s+//g;
  $seq17_primer_seqs =~ s/\s+//g;

  my @seq1_primer_name = split /;/, $seq1_primer_names;
  my @seq2_primer_name = split /;/, $seq2_primer_names;
  my @seq3_primer_name = split /;/, $seq3_primer_names;
  my @seq4_primer_name = split /;/, $seq4_primer_names;
  my @seq5_primer_name = split /;/, $seq5_primer_names;
  my @seq6_primer_name = split /;/, $seq6_primer_names;
  my @seq7_primer_name = split /;/, $seq7_primer_names;
  my @seq8_primer_name = split /;/, $seq8_primer_names;
  my @seq9_primer_name = split /;/, $seq9_primer_names;
  my @seq10_primer_name = split /;/, $seq10_primer_names;
  my @seq11_primer_name = split /;/, $seq11_primer_names;
  my @seq12_primer_name = split /;/, $seq12_primer_names;
  my @seq13_primer_name = split /;/, $seq13_primer_names;
  my @seq14_primer_name = split /;/, $seq14_primer_names;
  my @seq15_primer_name = split /;/, $seq15_primer_names;
  my @seq16_primer_name = split /;/, $seq16_primer_names;
  my @seq17_primer_name = split /;/, $seq17_primer_names;

  my @seq1_primer_seq = split /;/, $seq1_primer_seqs;
  my @seq2_primer_seq = split /;/, $seq2_primer_seqs;
  my @seq3_primer_seq = split /;/, $seq3_primer_seqs;
  my @seq4_primer_seq = split /;/, $seq4_primer_seqs;
  my @seq5_primer_seq = split /;/, $seq5_primer_seqs;
  my @seq6_primer_seq = split /;/, $seq6_primer_seqs;
  my @seq7_primer_seq = split /;/, $seq7_primer_seqs;
  my @seq8_primer_seq = split /;/, $seq8_primer_seqs;
  my @seq9_primer_seq = split /;/, $seq9_primer_seqs;
  my @seq10_primer_seq = split /;/, $seq10_primer_seqs;
  my @seq11_primer_seq = split /;/, $seq11_primer_seqs;
  my @seq12_primer_seq = split /;/, $seq12_primer_seqs;
  my @seq13_primer_seq = split /;/, $seq13_primer_seqs;
  my @seq14_primer_seq = split /;/, $seq14_primer_seqs;
  my @seq15_primer_seq = split /;/, $seq15_primer_seqs;
  my @seq16_primer_seq = split /;/, $seq16_primer_seqs;
  my @seq17_primer_seq = split /;/, $seq17_primer_seqs;

  $country    .= ": $city" if $city;
  $country    .= ", $county" if $county;
  $country    .= ", $state" if $state;
  $isolate_id  =~ s/\s//g;

  $note .= "; age: $age" if $age;
  $note .= "; symptoms: $symptoms" if $symptoms;
  $note .= "; non-human habitat: $habitat" if $habitat;
  $note .= "; purpose of sample collection: $purpose" if $purpose;
  $note .= "; altitude: $alt" if $alt;
  $note .= "; internal id: $isolate_id";

  $note =~ s/^; //;

  my @mon = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
  $month =~ s/^0// if $month;

  my $collection_date = "";
  $collection_date  = sprintf("%02d", $day);
  $collection_date .= "-". $mon[$month-1]; 
  $collection_date .= "-$year" if $year;

  die "Cannot find isolate species. Please check column E\n" unless $species;

  $study =~ s/(\r|\n)/ /g;
  $study =~ s/\s+/ /g;

  my @seqs = (
         [$seq1, $seq1_product, $seq1_desc, \@seq1_primer_name, \@seq1_primer_seq, $seq1_trace, $seq1_genbank],
         [$seq2, $seq2_product, $seq2_desc, \@seq2_primer_name, \@seq2_primer_seq, $seq2_trace, $seq2_genbank],
         [$seq3, $seq3_product, $seq3_desc, \@seq3_primer_name, \@seq3_primer_seq, $seq3_trace, $seq3_genbank],
         [$seq4, $seq4_product, $seq4_desc, \@seq4_primer_name, \@seq4_primer_seq, $seq4_trace, $seq4_genbank],
         [$seq5, $seq5_product, $seq5_desc, \@seq5_primer_name, \@seq5_primer_seq, $seq5_trace, $seq5_genbank],
         [$seq6, $seq6_product, $seq6_desc, \@seq6_primer_name, \@seq6_primer_seq, $seq6_trace, $seq6_genbank],
         [$seq7, $seq7_product, $seq7_desc, \@seq7_primer_name, \@seq7_primer_seq, $seq7_trace, $seq7_genbank],
         [$seq8, $seq8_product, $seq8_desc, \@seq8_primer_name, \@seq8_primer_seq, $seq8_trace, $seq8_genbank],
         [$seq9, $seq9_product, $seq9_desc, \@seq9_primer_name, \@seq9_primer_seq, $seq9_trace, $seq9_genbank],
         [$seq10, $seq10_product, $seq10_desc, \@seq10_primer_name, \@seq10_primer_seq, $seq10_trace, $seq10_genbank],
         [$seq11, $seq11_product, $seq11_desc, \@seq11_primer_name, \@seq11_primer_seq, $seq11_trace, $seq11_genbank],
         [$seq12, $seq12_product, $seq12_desc, \@seq12_primer_name, \@seq12_primer_seq, $seq12_trace, $seq12_genbank],
         [$seq13, $seq13_product, $seq13_desc, \@seq13_primer_name, \@seq13_primer_seq, $seq13_trace, $seq13_genbank],
         [$seq14, $seq14_product, $seq14_desc, \@seq14_primer_name, \@seq14_primer_seq, $seq14_trace, $seq14_genbank],
         [$seq15, $seq15_product, $seq15_desc, \@seq15_primer_name, \@seq15_primer_seq, $seq15_trace, $seq15_genbank],
         [$seq16, $seq16_product, $seq16_desc, \@seq16_primer_name, \@seq16_primer_seq, $seq16_trace, $seq16_genbank],
         [$seq17, $seq17_product, $seq17_desc, \@seq17_primer_name, \@seq17_primer_seq, $seq17_trace, $seq17_genbank],
         );

  my $count = 1;
  foreach my $s (@seqs) {

    my $sequence        = $s->[0];
    my $product         = $s->[1];
    my $seq_description = $s->[2];
    my @primer_names    = @{$s->[3]};
    my @primer_seqs     = @{$s->[4]};
    my $trace           = $s->[5];
    my $genbank_acc     = $s->[6];

    my $file_name       = "$isolate_id.$count";

    next unless $sequence;

    $sequence =~ s/\W+//g;
    my $length   = length($sequence);

    my $seqnote = "";

    $seqnote .= "; trace file: $trace" if $trace;
    $seqnote .= "; genbank accession identical to  this sequence: $genbank_acc" if $genbank_acc;
    $seqnote .= "; seq description: $seq_description" if $seq_description;

    my $modifier = "";
    $modifier .= "[organism=$species]" if $species;
    $modifier .= "[genotype=$genotype]" if $genotype;
    $modifier .= "[subtype=$subtype]" if $subtype;
    $modifier .= "[isolation-source=$source]" if $source;
    $modifier .= "[collection-date=$collection_date]" if $year;
    $modifier .= "[host=$host]" if $host;
    $modifier .= "[bio-material=$material]" if $material;
    $modifier .= "[country=$country]" if $country;
    $modifier .= "[sex=$sex]" if $sex;
    $modifier .= "[breed=$breed]" if $breed;
    $modifier .= "[lat-lon=$lat $lon]" if ($lat && $lon) ;
    $modifier .= "[note=$note$seqnote]" if $note;
 
    # the following three modifiers need to change based on the data
    #$modifier .= "[gene=$product]" if $product;
    #$modifier .= "[product=cytochrome b]" if $product;
    #$modifier .= "[gcode=4]"; 

    if ($#primer_names > 0) {
      for(my $i = 0; $i <= $#primer_names; $i=$i+2) {
        $modifier .= "[fwd-PCR-primer-name=$primer_names[$i]]"; 
        $modifier .= "[fwd-PCR-primer-seq=$primer_seqs[$i]]"; 
        $modifier .= "[rev-PCR-primer-name=$primer_names[$i+1]]"; 
        $modifier .= "[rev-PCR-primer-seq=$primer_seqs[$i+1]]"; 
      }
    }
    else {
      for(my $i = 0; $i <= $#primer_seqs; $i=$i+2) {
        $modifier .= "[fwd-PCR-primer-seq=$primer_seqs[$i]]"; 
        $modifier .= "[rev-PCR-primer-seq=$primer_seqs[$i+1]]"; 
      }
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
my $cmd = "./linux.tbl2asn -t template.sbt -p . -k cm -V vb";
# don't allow tbl2asn annotate the longest ORF
#my $cmd = "linux.tbl2asn -t template.sbt -p . -V vb";
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
BD,Sequence 5 Product or Locus Name,seq5_product
BE,Sequence 5 Primer Name,seq5_primer_names
BF,Sequence 5 Primer Seq,seq5_primer_seqs
BG,Sequence 5 Description,seq5_desc
BH,Sequence 5,seq5
BI,Sequence 5 Genbank Number,seq5_genbank
BJ,Sequence 5 Trace File,seq5_trace
BK,Sequence 6 Product or Locus Name,seq6_product
BL,Sequence 6 Primer Name,seq6_primer_names
BM,Sequence 6 Primer Seq,seq6_primer_seqs
BN,Sequence 6 Description,seq6_desc
BO,Sequence 6,seq6
BP,Sequence 6 Genbank Number,seq6_genbank
BQ,Sequence 6 Trace File,seq6_trace 
BR,Sequence 7 Product or Locus Name,seq7_product
BS,Sequence 7 Primer Name,seq7_primer_names
BT,Sequence 7 Primer Seq,seq7_primer_seqs
BU,Sequence 7 Description,seq7_desc
BV,Sequence 7,seq7
BW,Sequence 7 Genbank Number,seq7_genbank
BX,Sequence 7 Trace File,seq7_trace
BY,Sequence 8 Product or Locus Name,seq8_product
BZ,Sequence 8 Primer Name,seq8_primer_names
CA,Sequence 8 Primer Seq,seq8_primer_seqs
CB,Sequence 8 Description,seq8_desc
CC,Sequence 8,seq8
CD,Sequence 8 Genbank Number,seq8_genbank
CE,Sequence 8 Trace File,seq8_trace
CF,Sequence 9 Product or Locus Name,seq9_product
CG,Sequence 9 Primer Name,seq9_primer_names
CH,Sequence 9 Primer Seq,seq9_primer_seqs
CI,Sequence 9 Description,seq9_desc
CJ,Sequence 9,seq9
CK,Sequence 9 Genbank Number,seq9_genbank
CL,Sequence 9 Trace File,seq9_trace
CM,Sequence 10 Product or Locus Name,seq10_product
CN,Sequence 10 Primer Name,seq10_primer_names
CO,Sequence 10 Primer Seq,seq10_primer_seqs
CP,Sequence 10 Description,seq10_desc
CQ,Sequence 10,seq10
CR,Sequence 10 Genbank Number,seq10_genbank
CS,Sequence 10 Trace File,seq10_trace
CT,Sequence 11 Product or Locus Name,seq11_product
CU,Sequence 11 Primer Name,seq11_primer_names
CV,Sequence 11 Primer Seq,seq11_primer_seqs
CW,Sequence 11 Description,seq11_desc
CX,Sequence 11,seq11
CY,Sequence 11 Genbank Number,seq11_genbank
CZ,Sequence 11 Trace File,seq11_trace
DA,Sequence 12 Product or Locus Name,seq12_product
DB,Sequence 12 Primer Name,seq12_primer_names
DC,Sequence 12 Primer Seq,seq12_primer_seqs
DD,Sequence 12 Description,seq12_desc
DE,Sequence 12,seq12
DF,Sequence 12 Genbank Number,seq12_genbank
DG,Sequence 12 Trace File,seq12_trace
DH,Sequence 13 Product or Locus Name,seq13_product
DI,Sequence 13 Primer Name,seq13_primer_names
DJ,Sequence 13 Primer Seq,seq13_primer_seqs
DK,Sequence 13 Description,seq13_desc
DL,Sequence 13,seq13
DM,Sequence 13 Genbank Number,seq13_genbank
DN,Sequence 13 Trace File,seq13_trace
DO,Sequence 14 Product or Locus Name,seq14_product
DP,Sequence 14 Primer Name,seq14_primer_names
DQ,Sequence 14 Primer Seq,seq14_primer_seqs
DR,Sequence 14 Description,seq14_desc
DS,Sequence 14,seq14
DT,Sequence 14 Genbank Number,seq14_genbank
DU,Sequence 14 Trace File,seq14_trace
DV,Sequence 15 Product or Locus Name,seq15_product
DW,Sequence 15 Primer Name,seq15_primer_names
DX,Sequence 15 Primer Seq,seq15_primer_seqs
DY,Sequence 15 Description,seq15_desc
DZ,Sequence 15,seq15
EA,Sequence 15 Genbank Number,seq15_genbank
EB,Sequence 15 Trace File,seq15_trace
EC,Sequence 16 Product or Locus Name,seq16_product
ED,Sequence 16 Primer Name,seq16_primer_names
EE,Sequence 16 Primer Seq,seq16_primer_seqs
EF,Sequence 16 Description,seq16_desc
EG,Sequence 16,seq16
EH,Sequence 16 Genbank Number,seq16_genbank
EI,Sequence 16 Trace File,seq16_trace
EJ,Sequence 17 Product or Locus Name,seq17_product
EK,Sequence 17 Primer Name,seq17_primer_names
EL,Sequence 17 Primer Seq,seq17_primer_seqs
EM,Sequence 17 Description,seq17_desc
EN,Sequence 17,seq17
EO,Sequence 17 Genbank Number,seq17_genbank
EP,Sequence 17 Trace File,seq17_trace
