#!/usr/local/bin/perl

# The script to create a sequence database for mass-spec search engine
#@author - Ritesh Krishna

use strict;

my $numArgs = $#ARGV  + 1;

# print usage information if no arguments supplied  
if($numArgs != 3) {
   print "Usage:\n perl create_fasta_for_searchEngine.pl annotation_file.fasta decoy_ratio outputfile.fasta \n";
   exit 1;
}
  
# get arguments and perform basic error checking
my($annotation_file, $decoy_ratio, $outputfile);
  
$annotation_file = $ARGV[0];
$decoy_ratio 	 = $ARGV[1];
$outputfile 	 = $ARGV[2];

print "\n $annotation_file \t $decoy_ratio \t $outputfile \n";

# Determine the operating system
my $os_ = $^O;
 
my @tempFiles = ();
for(my $i = 0; $i < $decoy_ratio ; $i++){
	my $tempFile = "temp".($i+1).".fasta";
	@tempFiles = (@tempFiles, $tempFile);
	my $command = "perl create-decoy-db.pl --random_tryptic ". $annotation_file . " $tempFile 1000000000000000 Rnd".($i+1);
	print "\n $command \n";
	
	#execute the cmd
	system($command);
}

print "@tempFiles";

#concatenate the files and also process the header !!
open (OUTFILE, ">$outputfile")          || die "Error: cannot open output file";

# First process the $annotation_file
open (INFILE,  "<$annotation_file")  || die "Error: cannot open input file";

# use the same EOL for the output as found in the input file
binmode INFILE;
binmode OUTFILE;
$/ = "\012>";
my $eol;
while (<INFILE>) {
    if (length($_) > 1) {
      if (/\015\012/) {
        $eol = "\015\012"; #DOS
      } else {
        $eol = "\012"; #Unix
      }
      last;
    } else {
      next;
    }
}

seek(INFILE, 1, 0);

while (<INFILE>) {
    my($title, $seq) = split(/$eol/o, $_, 2);
    my($accession, $description) = split(/\s+/, $title, 2);
	# remove any non-residue characters from input sequence
    $seq =~ tr/a-zA-Z//cd;
	$seq = uc($seq);
    
    if($os_ eq "linux"){
        	print OUTFILE ">" . $accession . " ". $accession . $eol;
    }else{
        	print OUTFILE ">" . $accession . $eol; # RK
    }   
    print OUTFILE $seq . $eol; # RK       
 }
 
close(INFILE);
 
foreach my $tempfile(@tempFiles){
 	open (INFILE,  "<$tempfile")  || die "Error: cannot open $tempfile";
 	
 	seek(INFILE, 1, 0);

	while (<INFILE>) {
    	my($title, $seq) = split(/$eol/o, $_, 2);
    	my($accession, $description) = split(/\s+/, $title, 2);
		# remove any non-residue characters from input sequence
    	$seq =~ tr/a-zA-Z//cd;
		$seq = uc($seq);
    
	if($os_ eq "linux"){
        	print OUTFILE ">" . $accession . " ". $accession . $eol;
    	}else{
        	print OUTFILE ">" . $accession . $eol; # RK
    	}    	
    	print OUTFILE $seq . $eol; # RK       
 	}
 	close(INFILE);
}

close(OUTFILE);
	
