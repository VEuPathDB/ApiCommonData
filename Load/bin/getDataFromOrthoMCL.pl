#!/usr/bin/perl

use strict;
use XML::Simple;
use Getopt::Long;

my %hash;
my %uniq;
my ($outputAllOrthoGrps, $outputOrthoSeqsWithECs);

&GetOptions( "outputAllOrthoGrps=s"     => \$outputAllOrthoGrps,
             "outputOrthoSeqsWithECs=s" => \$outputOrthoSeqsWithECs );

die "cannot open output files\n" unless ($outputAllOrthoGrps && $outputOrthoSeqsWithECs);

my $url = "https://qa.orthomcl.org/webservices/GroupQuestions/BySequenceCount.xml?core_count_min=0&core_count_max=100000&peripheral_count_min=0&peripheral_count_max=100000&o-fields=group_name,ec_numbers,number_of_members,avg_connectivity,avg_percent_identity";

my $cmd = qq(wget "$url" -o $outputAllOrthoGrps.log -O $outputAllOrthoGrps.tmp);
print STDERR "\nRunning\n$cmd\n";

system($cmd);

my $ref = XMLin("$outputAllOrthoGrps.tmp");

open OUT, ">$outputAllOrthoGrps";
print OUT "[Group]\t[# Sequences]\t[Average % Connectivity]\t[Average % Identity]\t[EC Numbers]\n";

# update based on the xml format change - Haiming 12/06/2017
#while(my ($og, $v) = each %{$ref->{recordset}->{record}}) {
foreach my $v (@{$ref->{recordset}->{record}}) {
  my $og                = $v->{field}->{group_name}->{content};
  my $ec_numbers        = $v->{field}->{ec_numbers}->{content};
  my $number_of_members = $v->{field}->{number_of_members}->{content};
  my $avg_connectivity  = $v->{field}->{avg_connectivity}->{content};
  my $avg_pct_identity  = $v->{field}->{avg_percent_identity}->{content};

  $ec_numbers = 'null' unless $ec_numbers;
  print OUT "$og\t$number_of_members\t$avg_connectivity\t$avg_pct_identity\t$ec_numbers\n";
  if($ec_numbers) {
     $ec_numbers =~ s/\s+//g;
     my @ecArray = split /,/, $ec_numbers;
     foreach my $ec (@ecArray) {
       $ec =~ s/\(\d+\)$//;
       $hash{$ec} = $ec;
     }
  } 
}

close OUT;

open OUT, ">$outputOrthoSeqsWithECs";
print OUT "[Accession]\t[Source ID]\t[EC Numbers]\t[Group]\t[Group Size]\n";

$url = "https://qa.orthomcl.org/webservices/SequenceQuestions/ByEcAssignment.xml?o-fields=primary_key,source_id,ec_numbers,group_name,num_core,num_peripheral"; 

$cmd = qq(wget "$url" -o $outputOrthoSeqsWithECs.log -O $outputOrthoSeqsWithECs.tmp);
print STDERR "Running\n$cmd\n";
system($cmd);
$ref = XMLin("$outputOrthoSeqsWithECs.tmp");

# update based on the xml format change - Haiming 12/06/2017
#while(my ($k, $v) = each %{$ref->{recordset}->{record}}) {
foreach my $v (@{$ref->{recordset}->{record}}) {

  my $k          = $v->{field}->{primary_key}->{content};
  my $source_id  = $v->{field}->{source_id}->{content};
  my $ec_numbers = $v->{field}->{ec_numbers}->{content};
  my $group_name = $v->{field}->{group_name}->{content};
  my $num_core = $v->{field}->{num_core}->{content};
  my $num_peripheral = $v->{field}->{num_peripheral}->{content};

  my $group_size = $num_core + $num_peripheral;

  next unless ($ec_numbers && $group_name);
  next unless (!exists $uniq{$source_id});
  $uniq{$source_id} = 1;

  $group_name = 'null' unless $group_name;
  $group_size = 'null' unless $group_size;

  print OUT "$k\t$source_id\t$ec_numbers\t$group_name\t$group_size\n";
}

close OUT;
