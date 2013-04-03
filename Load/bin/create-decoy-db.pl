#!/usr/local/bin/perl

#############################################################################
# Copyright (C) 2006, Matrix Science Limited.                               #
#                                                                           #
# This script is free software. You can redistribute and/or                 #
# modify it under the terms of the GNU General Public License               #
# as published by the Free Software Foundation; either version 2            #
# of the License or, (at your option), any later version.                   #
#                                                                           #
# These modules are distributed in the hope that they will be useful,       #
# but WITHOUT ANY WARRANTY; without even the implied warranty of            #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the              #
# GNU General Public License for more details.                              #
#############################################################################

#Modified by Andy Jones, Jan 2009 to count the number of amino acids and stop when reaching a given threshold, output file not optional
#Implementing first for reverse mode

#19 Jan modification to the code (ARJ) to work out where trptic sites are in proteins, and create proportionally correct randomised sequence within same tryptic sites

# Modified by Ritesh Krishna, Oct 2010.

# This version has been further modified to extract IPI accessions for reverse databases


  use strict;

# print usage information if no arguments supplied  
  unless ($ARGV[0]) {
    print "Usage:\ncreate-decoy-db.pl [--random] [--append] [--rev_tryptic] [--random_tryptic] [--keep_accessions] input.fasta output.fasta stop_at_amino_acid_count Rnd_accession\n\n";
    print "If --random is specified, the output entries will be random sequences\n";
    print "   with the same average amino acid composition as the input database. \n";
    print "   Otherwise, the output entries will be created by reversing the input\n";
    print "   sequences, (faster, but not suitable for PMF or no-enzyme searches).\n";
    print "If --append is specified, the new entries will be appended to the input\n";
    print "   database. Otherwise, a separate decoy database file will be created.\n";
    print "If --keep_accessions is specified, the original accession strings will\n";
    print "   be retained. This is necessary if you want to use taxonomy and the\n";
    print "   taxonomy is derived from the accessions, (e.g. NCBI gi2taxid).\n";
    print "   Otherwise, the string ###REV### or ###RND### is prepended to the\n";
    print "   original accession strings.\n";
    print "You cannot specify both --append and --keep_accessions.\n";
    print "An output path must be supplied unless --append is specified.\n";
    exit 1;
  }

# get arguments and perform basic error checking
  my($random, $append, $keep_accessions, $inFile, $outFile, $stopCount, $totalDecoyLen, $reverseTryptic, $trypticRandom, $rndAcc);
  for (my $i = 0; $i <= $#ARGV; $i++) {
    	if (lc($ARGV[$i]) eq "--random") {
      		$random = 1;	 
    	} elsif ( lc($ARGV[$i]) eq "--append") {
		  $append = 1;
	} elsif ( lc($ARGV[$i]) eq "--rev_tryptic") {
      		$reverseTryptic = 1;
	} elsif (lc($ARGV[$i]) eq "--random_tryptic") {
      		$trypticRandom= 1;
    	} 
	elsif (lc($ARGV[$i]) eq "--keep_accessions") {
      		$keep_accessions = 1;
    	}
	elsif ($ARGV[$i] =~ /^-/) {
      		die "Error: unrecognised argument: " . $ARGV[$i];
    	} elsif (!$inFile) {
      		$inFile = $ARGV[$i];
    	} elsif (!$outFile) {
      		$outFile = $ARGV[$i];
    	} 
	elsif(!$stopCount){
		$stopCount = $ARGV[$i];
	}
	elsif(!$rndAcc && $trypticRandom){
		$rndAcc = $ARGV[$i];
	}
	else {
      		die "Error: too many arguments";
    	}
  }
  
  if(!$stopCount){
	die "Error: count to stop position not set\n";
  }	
  
  
  unless ($inFile && -s $inFile) {
    die "Error: must specify valid input file";
  }
  
  unless ($append) {
    if ($outFile) {
      if (-e $outFile) {
        print "Warning: output file already exists. OK to overwrite? [No] ";
        my $answer = <STDIN>;
        unless ($answer =~ /^y/i) {
          exit 1;
        }
      }
    } else {
      die "Error: must specify output file path";
    }  
  }
  
  if ($append && $keep_accessions) {
    die "Error: cannot combine --append and --keep_accessions";
  }
  
 # Determine the operating system
 my $os_ = $^O;
 
# so far so good, try to open input and output files
  if ($append) { 
    open (INFILE,  "+<$inFile")          || die "Error: cannot open input file";
    open (OUTFILE, "+>$inFile" . ".tmp") || die "Error: cannot create temp file";
  } else {
    open (INFILE,  "<$inFile")           || die "Error: cannot open input file";
    open (OUTFILE, ">$outFile")          || die "Error: cannot open output file";
  }
  
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

# set the cursor to start of file + 1 character, (i.e. skip first ">")
  seek(INFILE, 1, 0);

# read a complete sequence entry at a time
  $/ = "$eol>";
  
# for --random, need to determine average AA composition of input database
	my(@AACount, @residue, $denominator);
  if ($random || $trypticRandom) {
    while (<INFILE>) {
      my($title, $seq) = split(/$eol/o, $_, 2);
      $_ = uc($seq);
      	 
      $AACount[0] += tr/A//;
      $AACount[1] += tr/B//;
      $AACount[2] += tr/C//;
      $AACount[3] += tr/D//;
      $AACount[4] += tr/E//;
      $AACount[5] += tr/F//;
      $AACount[6] += tr/G//;
      $AACount[7] += tr/H//;
      $AACount[8] += tr/I//;
      $AACount[9] += tr/J//;
      $AACount[10] += tr/K//;
      $AACount[11] += tr/L//;
      $AACount[12] += tr/M//;
      $AACount[13] += tr/N//;
      $AACount[14] += tr/O//;
      $AACount[15] += tr/P//;
      $AACount[16] += tr/Q//;
      $AACount[17] += tr/R//;
      $AACount[18] += tr/S//;
      $AACount[19] += tr/T//;
      $AACount[20] += tr/U//;
      $AACount[21] += tr/V//;
      $AACount[22] += tr/W//;
      $AACount[23] += tr/X//;
      $AACount[24] += tr/Y//;
      $AACount[25] += tr/Z//;
	  
	  if($trypticRandom){	#these three amino acids stay in position for the method where tryptic sites are maintained
			$AACount[10] = 0;
			$AACount[15] = 0;
			$AACount[17] = 0;
	  }  
    }
	
	
	# $denominator is total number of residues
	foreach (@AACount) {
	  $denominator += $_;
	}
	# populate lookup vector with residues in same proportions
	for (my $i = 0; $i < 26; $i++) {
	  for (my $j = 0; $j < int($AACount[$i] * 10000 / $denominator + 0.5); $j++) {
		push @residue, chr(65 + $i);
	  }
	}
	# ensure vector fully populated by topping up with common residue A
	while (scalar(@residue) < 10000) {
	  push @residue, "A";
	}
  }


# set the cursor to start of file + 1 character, (i.e. skip first ">")
  seek(INFILE, 1, 0);

# loop through input file and create the output file
  while (<INFILE>) {
    	my($title, $seq) = split(/$eol/o, $_, 2);
    	my($accession, $description) = split(/\s+/, $title, 2);
    	# remove any non-residue characters from input sequence
    	$seq =~ tr/a-zA-Z//cd;
    	$seq = uc($seq);
    	my @pieces;

    	if($trypticRandom){	#creates a database of the same size, with the same tryptic sites, but with randomly inserted amino acids
		if ($keep_accessions) {
			die "Not implemented yet\n";
		} 
		else {	  
			#This scripts expects databases to have been pre-processed to only have one identifier	
			if($accession eq "gb"){	#Special case for Toxoplasma database, first accession before | is always gb...
				my @tmp = split(/\|/, $accession);	#extract only the first of a series of | separated accessions	
				$accession = $tmp[1];
			}
			
			if($accession =~ s/IPI:/IPI:$rndAcc/){
			}
			else{
				$accession = $rndAcc . $accession;
			}
        		#if($os_ eq "linux"){
        		#	print OUTFILE ">" . $accession . " ". $description.$eol;
        		#}else{
				print OUTFILE ">" . $accession. $eol;	#RK
        		#}
		}
		
		# create random peptide sequences
		my @peptides = split(/(?<=[KR])/, $seq);
		my $rnd_seq = "";
		
		for (my $i=0; $i<@peptides;$i++){
			my $pep = $peptides[$i];
			my $len = length($pep);
			my $rnd_peptide = "";
			
			for (my $i = 0; $i < $len; $i++) {					
				my $char = substr($pep,$i,1);	
				if($char ne "K" && $char ne "R" && $char ne "P"){
					$rnd_peptide .= $residue[int(rand 10000)];
				}
				else{
					$rnd_peptide .= $char;
				}
			}						
			
			if(length($pep) != length ($rnd_peptide)){
				print "$pep\n$rnd_peptide\n\n";
				print "error: unequal peptide length created\n";
				die;
			}
			
			$rnd_seq .= $rnd_peptide;
		}	
	
		# chop into little pieces for output
		@pieces = $rnd_seq =~ /(.{1,60})/g;
		
		foreach (@pieces) {
			my $nextLen = $totalDecoyLen + length($_);
			if($nextLen > $stopCount){
				my $tempLen = $stopCount-$totalDecoyLen;
				my $tempString = substr($_, 0, $tempLen);
				print OUTFILE $tempString. $eol;
				print OUTFILE "$eol$eol";
				exit;
			}
			else{			
				print OUTFILE $_ . $eol;			
			}
			$totalDecoyLen = $nextLen;		
		}

	}
	else {
	  	if ($keep_accessions) {
        		#if($os_ eq "linux"){
        		#	print OUTFILE ">" . $accession . " ". $description . $eol;
	        	#}else{
        			print OUTFILE ">" . $accession . $eol; # RK
        		#}
      		} 

   	 	# create reversed sequence
      		$seq = reverse $seq;
    		# chop into little pieces for output
      		@pieces = $seq =~ /(.{1,60})/g;
	        foreach (@pieces) {     
			my $nextLen = $totalDecoyLen + length($_);
			if($nextLen > $stopCount){
				my $tempLen = $stopCount-$totalDecoyLen;
				my $tempString = substr($_, 0, $tempLen);
				print OUTFILE $tempString. $eol;
				exit;
			}
			else{			
				print OUTFILE $_ . $eol;			
			}
			$totalDecoyLen = $nextLen;
      		}	
    	}
  }

# if --append, copy output to end of input file and delete temp file
  if ($append) {
    seek(OUTFILE, 0, 0);
    while (<OUTFILE>) {
        print INFILE $_;      
    }
    close OUTFILE;
    unlink "$inFile" . ".tmp";
  }

  print OUTFILE "$eol$eol";
  print "Amino acid count\t$totalDecoyLen\n";
  
  exit 0;
  
  
#Randomize array order, from http://docstore.mik.ua/orelly/perl/cookbook/ch04_18.htm  
sub fisher_yates_shuffle {
    my $array = shift;
    my $i;
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
}

#create an array of chars
sub addCharsToArray{
	my $tmp = shift;
	my @array = @{$tmp};
	my $char = shift;
	my $numChars = shift;
	
	for(my $i = 0 ; $i < $numChars; $i++){
		push(@array,$char);
	}	
}

  
