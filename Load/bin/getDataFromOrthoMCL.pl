#!/usr/bin/perl

use strict;
use Getopt::Long;

my %uniq;
my ($outputAllOrthoGrps, $outputOrthoSeqsWithECs);

&GetOptions( "outputAllOrthoGrps=s"     => \$outputAllOrthoGrps,
             "outputOrthoSeqsWithECs=s" => \$outputOrthoSeqsWithECs );

die "cannot open output files\n" unless ($outputAllOrthoGrps && $outputOrthoSeqsWithECs);

my $url = "https://orthomcl.org/orthomcl/service/record-types/group/searches/GroupsBySequenceCount/reports/attributesTabular?core_count_min=0&core_count_max=1000000&peripheral_count_min=0&peripheral_count_max=100000&reportConfig={\"attributes\":[\"primary_key\",\"number_of_members\",\"ec_numbers\",\"avg_connectivity\",\"avg_percent_identity\"],\"includeHeader\":true,\"attachmentType\":\"text\"}";

my $cmd = qq(wget '$url' -o $outputAllOrthoGrps.log -O $outputAllOrthoGrps);
print STDERR "\nRunning\n$cmd\n";
system($cmd);


$url = "https://orthomcl.org/orthomcl/service/record-types/sequence/searches/ByEcAssignment/reports/attributesTabular?reportConfig={\"attributes\":[\"primary_key\",\"source_id\",\"num_core\",\"num_peripheral\",\"group_name\",\"ec_numbers\"],\"includeHeader\":true,\"attachmentType\":\"plain\"}";

$cmd = qq(wget '$url' -o $outputOrthoSeqsWithECs.log -O $outputOrthoSeqsWithECs);
print STDERR "Running\n$cmd\n";
system($cmd);

