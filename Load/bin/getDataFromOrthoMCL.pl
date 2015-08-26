#!/usr/bin/perl

use strict;
use LWP::Simple;
use XML::Simple;;
use Getopt::Long;

my %hash;
my ($outputAllOrthoGrps, $outputOrthoSeqsWithECs);


&GetOptions( "outputAllOrthoGrps=s"     => \$outputAllOrthoGrps,
             "outputOrthoSeqsWithECs=s" => \$outputOrthoSeqsWithECs );

die "cannot open output files\n" unless ($outputAllOrthoGrps && $outputOrthoSeqsWithECs);
my $browser = LWP::UserAgent->new;

my $url = 'http://orthomcl.org/webservices/GroupQuestions/BySequenceCount.xml?sequence_count_min=1&sequence_count_max=1000000&o-fields=group_name,ec_numbers,number_of_members,avg_connectivity,avg_percent_identity';

my $response = $browser->get($url);
die 'Error getting $url' unless defined $response;

my $xml = XML::Simple->new;
my $ref = $xml->XMLin($response->content);

open OUT, ">$outputAllOrthoGrps";
print OUT "[Group] [# Sequences] [Average % Connectivity]  [Average % Identity]  [EC Numbers]\n";

while(my ($og, $v) = each %{$ref->{recordset}->{record}}) {
  my $ec_numbers        = $v->{field}->{ec_numbers}->{content};
  my $number_of_members = $v->{field}->{number_of_members}->{content};
  my $avg_connectivity  = $v->{field}->{avg_connectivity}->{content};
  my $avg_pct_identity  = $v->{field}->{avg_percent_identity}->{content};

  if($ec_numbers) {
     $ec_numbers =~ s/\s+//g;
     my @ecArray = split /,/, $ec_numbers;
     foreach my $ec (@ecArray) {
       $ec =~ s/\(\d+\)$//;
       $hash{$ec} = $ec;
     }
  }

  print OUT "$og, $number_of_members, $avg_pct_identity, $avg_connectivity, $ec_numbers\n";
}

close OUT;

open OUT, ">OrthoSeqsWithECs.txt";
print OUT "[Accession] [Source ID] [EC Numbers] [Group] [Group Size]\n";

foreach my $ec (keys %hash) {
  $url = "http://orthomcl.org/webservices/SequenceQuestions/ByEcNumber.xml?ec_number_type_ahead=$ec&o-fields=primary_key,source_id,ec_numbers,group_name,group_size";

  $response = $browser->get($url);
  die 'Error getting $url' unless defined $response;

  $xml = XML::Simple->new;
  $ref = $xml->XMLin($response->content);

  while(my ($k, $v) = each %{$ref->{recordset}->{record}}) {
    next if $k eq 'id'; # count is 1, e.g. ec number is 6.2.1.30

    my $source_id  = $v->{field}->{source_id}->{content};
    my $ec_numbers = $v->{field}->{ec_numbers}->{content};
    my $group_name = $v->{field}->{group_name}->{content};
    my $group_size = $v->{field}->{group_size}->{content};

    next unless ($ec_numbers && $group_name);
    print OUT "$k, $source_id, $ec_numbers, $group_name, $group_size\n";
  }
}

close OUT;
