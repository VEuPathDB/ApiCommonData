#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

my ($pdb_file, $id_file, $output_file);
GetOptions(
    'pdb_file=s' => \$pdb_file,
    'id_file=s'  => \$id_file,
    'output_file=s' => \$output_file,
) or die "Usage: $0 --pdb_file pdb_file.txt --id_file id_file.txt --output_file output.txt\n";

#Copy regex from classes.xml for GUS::Supported::Plugin::LoadFastaSequences
my $regexSourceId = '>(\w+)\s+mol:protein';
my $regexDesc = 'length:\d+\s+(.+)$';

open my $id_fh, '<', $id_file or die "Could not open id file: $!\n";
my %taxon_data;
while (my $line = <$id_fh>) {
    chomp $line;
    my @fields = split /\t/, $line;
    my $source_id = $fields[0];
    my $taxon_name = $fields[1] // '';  
    $taxon_data{lc(substr($source_id, 0, 4))} = $taxon_name; 
}
close $id_fh;

open my $out_fh, '>', $output_file or die "Could not open output file: $!\n";

open my $pdb_fh, '<', $pdb_file or die "Could not open pdb file: $!\n";

while (my $line = <$pdb_fh>) {
    chomp $line;
    if ($line =~ /$regexSourceId/) {
        my $source_id = $1;
        my $taxon_key = lc(substr($source_id, 0, 4)); 
        my $taxon_name = $taxon_data{$taxon_key} // 'Unknown'; 
        
        my $description = '';
        if ($line =~ /$regexDesc/) {
            $description = $1; 
        }

        print $out_fh "$source_id\t$description\t$taxon_name\n";
    }
}
close $pdb_fh;

close $out_fh;

print "Process completed. Output written to $output_file.\n";

