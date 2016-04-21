#!/usr/bin/perl

use strict;
use LWP::Simple;
use XML::Simple;;
use Getopt::Long;

my %hash;
my %uniq;
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
print OUT "[Group]\t[# Sequences]\t[Average % Connectivity]\t[Average % Identity]\t[EC Numbers]\n";

while(my ($og, $v) = each %{$ref->{recordset}->{record}}) {
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
    next unless (!exists $uniq{$source_id});
    $uniq{$source_id} = 1;

    $group_name = 'null' unless $group_name;
    $group_size = 'null' unless $group_size;

    print OUT "$k\t$source_id\t$ec_numbers\t$group_name\t$group_size\n";
  }
}

close OUT;
