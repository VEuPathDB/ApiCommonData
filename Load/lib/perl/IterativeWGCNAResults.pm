
package ApiCommonData::Load::IterativeWGCNAResults;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);

use strict;
#use CBIL::TranscriptExpression::Error;
use CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles;

use Data::Dumper;

use DBI;
use DBD::Oracle;

use GUS::Supported::GusConfig;

sub getStrandness        { $_[0]->{strand} }
sub getGeneType        { $_[0]->{genetype} } #### Marking for removal - we want to do both or just one always.
sub getPower        { $_[0]->{softThresholdPower} }
sub getOrganism        { $_[0]->{organism} }
sub getInputSuffixMM              { $_[0]->{inputSuffixMM} }
sub getInputSuffixME              { $_[0]->{inputSuffixME} }
sub getInputFile              { $_[0]->{inputFile} }
sub getprofileSetName              { $_[0]->{profileSetName} }
sub getTechnologyType              { $_[0]->{technologyType} }
sub getReadsThreshold              { $_[0]->{readsThreshold} }
sub getDatasetName            { $_[0]->{datasetName} } #### Marking for removal. Need to get this info from elsewhere


#-------------------------------------------------------------------------------
sub new {
  my ($class, $args) = @_; 
  $args->{sourceIdType} = "gene";
  my $self = $class->SUPER::new($args) ;          
  
  return $self;
}

#------ Note: two versions of inputs ae used to running iterativeWGCNA method -----------#
#----- version1: only include protein-coding gene in the input tpm file -----------------#
#----- version2: only exclude pseudogenes in the input tpm file -------------------------#

sub munge {
	my ($self) = @_;
	#------------- database configuration -----------#
	my $strand = $self->getStrandness();
	my $mainDirectory = $self->getMainDirectory();
	my $technologyType = $self->getTechnologyType();
	my $profileSetName = $self->getprofileSetName();
	my $gusconfig = GUS::Supported::GusConfig->new("$ENV{GUS_HOME}/config/gus.config");
	my $dsn = $gusconfig->getDbiDsn();
	my $login = $gusconfig->getDatabaseLogin();
	my $password = $gusconfig->getDatabasePassword();

	my $dbh = DBI->connect($dsn, $login, $password, { PrintError => 1, RaiseError => 0})
		or die "Can't connect to the tracking database: $DBI::errstr\n";
	
	#--first strand processing ------------------------------------------#
	if($strand eq 'firststrand'){
		#-- extract inputs --#
		my $power = $self->getPower();
		my $inputFile = $self->getInputFile();
		my $organism = $self->getOrganism();
		my $genetype = $self->getGeneType();
		my $readsThreshold = $self->getReadsThreshold();
		my $datasetName = $self->getDatasetName();

		#--Version1: first strand processing  (only keep protein-coding gene in the input tpm file)-------------#
		if($genetype eq 'protein coding'){ #### Marking for removal
				my $outputFile = "Preprocessed_proteincoding_" . $inputFile; # Will be the wgcna input file
				my $sql = "SELECT source_id 
										FROM apidbtuning.geneAttributes  
										WHERE organism = '$organism' AND gene_type = 'protein coding gene'";
				my $stmt = $dbh->prepare($sql);
				$stmt->execute();

				# Create gene hash
				my %proteinCodingGenesHash;
				while(my ($proteinCodingGenes) = $stmt->fetchrow_array() ) {
					$proteinCodingGenesHash{$proteinCodingGenes} = 1;
				}
				
				$stmt->finish();

				#-------------- add 1st column header & only keep PROTEIN CODING GENES -----#
				open(IN, "<", $inputFile) or die "Couldn't open file $inputFile for reading, $!";
				open(OUT,">$mainDirectory/$outputFile") or die "Couldn't open file $mainDirectory/$outputFile for writing, $!";
				
				my %inputs; #### what are inputs here? header of input file? I think it's going to be wgcna inputs
				#### Marking for removal thanks to later while loop
				# my $header = <IN>;

				# # Clean and split headers read from file
				# chomp $header;
				# my @headers = split("\t",$header);  # array of headers
				# foreach my $headerValue (@headers[1 .. $#headers]) {
				# 	$inputs{$headerValue} = 1;
				# }
				# # The first header should be 'Gene'
				# $headers[0] = 'Gene';
				# print OUT join("\t",@headers);

				
				#-- Parse file and create input file for wgcna (called outputFile) --#

				while (my $line = <IN>){
					chomp $line;
					if ($. == 1){
						# Handle headers
						my @headers = split("\t",$line);
						$headers[0] = 'Gene';
						print OUT join("\t",@headers);
						
						@headers = map {s/^\s+|\s+$//g; $_ } @headers;  # clean white space. Likely want to do a map not grep. Map returns each element of @all.
						# Above can hopefully be replaced by chomp!
						foreach(@headers[1 .. $#headers]){
							$inputs{$_} = 1;
						}
					}else{
						my @geneLine = split("\t",$line);
						if ($proteinCodingGenesHash{$geneLine[0]}){
							print OUT $line;
						}
					}
				}
				close IN;
				close OUT;
				#--- Finished creating first output file. This output file will become the input to wgcna --#


				#-------------- run IterativeWGCNA docker image -----#
				mkdir("$mainDirectory/FirstStrandProteinCodingOutputs");
				my $outputDir = $mainDirectory . "/FirstStrandProteinCodingOutputs";

				my $inputFileForWGCNA = "$mainDirectory/$outputFile";
				my $command = "singularity run  docker://jbrestel/iterative-wgcna -i $inputFileForWGCNA  -o  $outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25";
				#my $command = "singularity run --bind $mainDirectory:/home/docker   docker://jbrestel/iterative-wgcna -i /home/docker$outputFile  -o  /home/docker/$outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25"; 
				# note - check to see if we have a veupathdb wgcna docker. if yes, can swap out the jbrestel version

				my $results  =  system($command);  # will return exit status
				
				#-------------- parse Module Membership -----#
				mkdir("$mainDirectory/FirstStrandProteinCodingOutputs/FirstStrandMMResultsForLoading")
				my $outputDirModuleMembership = "$mainDirectory/FirstStrandProteinCodingOutputs/FirstStrandMMResultsForLoading/";
				
				open(MM, "<", "$outputDir/merged-0.25-membership.txt") or die "Couldn't open $outputDir/merged-0.25-membership.txt for reading";
				my %MMHash;
				# Can we do all this while reading the file?
				# Would want to print to each file. Would need hash with file name, module. 
				# could end by looping over and closing all.
				# In general, don't read into memory if we don't have to!
				<MM>; # removing header
				while (my $line = <MM>) {
					chomp($line);
					print $line;
					# $line =~ s/\r//g; # consider command line tools for converting from mac to unix #### Marked for removal
					my @all = split/\t/,$line;
					push @{$MMHash{$all[1]}}, "$all[0]\t$all[2]\n"; # also can just exclude Unclassified things
				}
				close MM;
				
				my @files;
				my @modules;
				my @allKeys = keys %MMHash;
				my @ModuleNames = grep { $_ ne 'UNCLASSIFIED' } @allKeys; # removes unclassifieds
				for my $i(@ModuleNames){
					push @modules,$i . " " . $self->getInputSuffixMM() . " " . "ProteinCoding";
					push @files,"$i" . "_1st" . "\.txt" . " " . $self->getInputSuffixMM() . " " . "ProteinCoding" ;
					open(MMOUT, ">$outputDirModuleMembership/$i" . "_1st_ProteinCoding" . "\.txt") or die $!;
					print MMOUT "geneID\tcorrelation_coefficient\n";
					for my $ii(@{$MMHash{$i}}){
							print MMOUT $ii;
					}
					close MMOUT;
				}
				my %inputProtocolAppNodesHash;
				foreach(@modules) {
					push @{$inputProtocolAppNodesHash{$_}}, map { $_ . " " . $self->getInputSuffixMM() } sort keys %inputs;
				}
				
				# Sets things for config file. What my instance of this object did (parameters)
				$self->setInputProtocolAppNodesHash(\%inputProtocolAppNodesHash);
				$self->setNames(\@modules);                                                                                           
				$self->setFileNames(\@files);
				$self->setProtocolName("WGCNA");
				$self->setSourceIdType("gene");
				$self->createConfigFile(); # writes the config row
				
				#-------------- parse Module Eigengene -----#
				#-- copy module_egene file to one upper dir and the run doTranscription --#
				# my $CPcommand = "cp  $outputDir/merged-0.25-eigengenes.txt  . ; 
				# 									mv merged-0.25-eigengenes.txt merged-0.25-eigengenes_1stStrand_ProteinCoding.txt "; # rename while copying!
				# my $CPresults  =  system($CPcommand);
				
				# Also something like sourceIdType. Default is "gene". In this case should probably be "eigengene" so that the plugin knows.
				my $egenes = CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles->new(
			{mainDirectory => "$mainDirectory", inputFile => "$outputDir/merged-0.25-eigengenes.txt",makePercentiles => 0,doNotLoad => 0, profileSetName => "$profileSetName"}
			);
				$egenes ->setTechnologyType("RNASeq");
				$egenes->setProtocolName("WGCNAModuleEigengenes"); # Will be consumed by the loader (insertAnalysisResults plugin). Also need to change it in the plugin
				$egenes->createConfigFile(); # writes the config row
				
				$egenes ->munge();
				
		} # End protein coding geneType

		#-- Version2: first strand processing  (only remove pseudogenes in the input tpm file)-------------#
		if($genetype eq 'exclude pseudogene'){
			print "Excluding pseudogenes";
			my $outputFile = "Preprocessed_excludePseudogene_" . $inputFile;
			my $sql = "SELECT ga.source_id,
									ta.length
								FROM apidbtuning.geneAttributes ga,
									apidbtuning.transcriptAttributes ta
								WHERE ga.organism = '$organism'
								AND ga.gene_type != 'pseudogene'
								AND ga.gene_id = ta.gene_id";
			my $stmt = $dbh->prepare($sql);
			$stmt->execute();
			#### Marking for removal
			# my %hash;
			# my %hash_length;
			
			# while(my ($proteinCodingGenes, $transcript_length) = $stmt->fetchrow_array() ) {
			# 	$hash{$proteinCodingGenes} = 1;
			# 	$hash_length{$proteinCodingGenes} = $transcript_length;
			# }

			# Create gene hash
			#### Ann rename protein coding vars
			my %genesHash;
			my %geneLengthsHash;
			while(my ($proteinCodingGenes, $transcript_length) = $stmt->fetchrow_array() ) {
				$genesHash{$proteinCodingGenes} = 1;
				$geneLengthsHash{$proteinCodingGenes} = $transcript_length;
			}
				
			$stmt->finish();

			#--- Find average unique reads for this dataset ---#
			my ($avg_unique_reads) = $dbh->selectrow_array("select avg(avg_unique_reads)
														from apidbtuning.rnaseqstats
														where dataset_name = '$datasetName'
														group by dataset_name");

			#-------------- add 1st column header & only keep PROTEIN CODING GENES -----#
			open(IN, "<", $inputFile) or die "Couldn't open file $inputFile for reading, $!";
			open(OUT,">$mainDirectory/$outputFile") or die "Couldn't open file $mainDirectory/$outputFile for writing, $!";
			
			my %inputs;
			#-- Parse file and create input file for wgcna (called outputFile) --#

			while (my $line = <IN>){
				chomp $line;
				if ($. == 1){
					# Handle headers
					my @headers = split("\t",$line);
					$headers[0] = 'Gene';
					print OUT join("\t",@headers);
					
					# Above can hopefully be replaced by chomp!
					foreach(@headers[1 .. $#headers]){
						# Should the below come before printing?
						@headers = map {s/^\s+|\s+$//g; $_ } @headers;  # clean white space. Likely want to do a map not grep. Map returns each element of @all.
						$inputs{$_} = 1;
					}
				}else{
					#-- Each line describes one gene --#
					my @geneLine = split("\t",$line);
					print @geneLine;

					#-- Calculate and apply the floor based on the pre-defiend readsThreshold --#
					my $hard_floor = $readsThreshold * 1000000 * $hash_length{$geneLine[0]} / $avg_unique_reads;
					foreach(@geneLine[1 .. $#geneLine]){
						if ($_ < $hard_floor) {
							$_ = $hard_floor;
						}
					}

					$line = join("\t",@geneLine);
					print $line;

					if ($genesHash{$geneLine[0]}){
						print OUT $line;
					}

					
				}
			}
			close IN;
			close OUT;
		
			#-- Write lines to wgcna input file and apply floor expression value --#
			# open(IN, "<", $inputFile) or die "Couldn't open file $inputFile for reading, $!";
			# while (my $line = <IN>){
			# 	if ($. == 1){
			# 		# #-- Heading --#
			# 		# my @all = split/\t/,$line;
			# 		# $all[0] = 'Gene';
			# 		# my $new_line = join("\t",@all);
			# 		# print OUT $new_line;
					
			# 		# foreach(@all[1 .. $#all]){
			# 		# 	@all = grep {s/^\s+|\s+$//g; $_ } @all;
			# 		# 	$inputs{$_} = 1;
			# 		# }
			# 	}else{
			# 		#-- Each line describes one gene --#
			# 		my @all = split/\t/,$line;
			# 		print $line;

			# 		#-- Calculate and apply the floor based on the pre-defiend readsThreshold --#
			# 		my $hard_floor = $readsThreshold * 1000000 * $hash_length{$all[0]} / $avg_unique_reads;
			# 		foreach(@all[1 .. $#all]){
			# 			if ($_ < $hard_floor) {
			# 				$_ = $hard_floor;
			# 			}
			# 		}

			# 		$line = join("\t",@all);
			# 		print $line;

			# 		if ($hash{$all[0]}){
			# 			print OUT $line;
			# 		}
			# 	}
			# }
			# close IN;
			# close OUT;
				
			#-------------- run IterativeWGCNA docker image -----#
			mkdir("$mainDirectory/FirstStrandExcludePseudogeneOutputs");
			my $outputDir = $mainDirectory . "/FirstStrandExcludePseudogeneOutputs";

			my $inputFileForWGCNA = "$mainDirectory/$outputFile";
			my $command = "singularity run  docker://jbrestel/iterative-wgcna -i $inputFileForWGCNA  -o  $outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25";
			#my $command = "singularity run --bind $mainDirectory:/home/docker   docker://jbrestel/iterative-wgcna -i /home/docker$outputFile  -o  /home/docker/$outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25"; 
			
			my $results  =  system($command);
			
			#-------------- parse Module Membership -----#
			mkdir("$mainDirectory/FirstStrandExcludePseudogeneOutputs/FirstStrandMMResultsForLoading")
			my $outputDirModuleMembership = "$mainDirectory/FirstStrandExcludePseudogeneOutputs/FirstStrandMMResultsForLoading/";
			
			open(MM, "<", "$outputDir/merged-0.25-membership.txt") or die "Couldn't open $outputDir/merged-0.25-membership.txt for reading";
			my %MMHash;
			while (my $line = <MM>) {
				if ($. == 1){
						next;
				}else{
						chomp($line);
						$line =~ s/\r//g;
						my @all = split/\t/,$line;
						push @{$MMHash{$all[1]}}, "$all[0]\t$all[2]\n";
				}
			}
			close MM;
				
			my @files;
			my @modules;
			my @allKeys = keys %MMHash;
			my @ModuleNames = grep { $_ ne 'UNCLASSIFIED' } @allKeys; 
			for my $i(@ModuleNames){
				push @modules,$i . " " . $self->getInputSuffixMM() . " " . "ExcludePseudogene";
				push @files,"$i" . "_1st" . "\.txt" . " " . $self->getInputSuffixMM() . " " . "ExcludePseudogene" ;
				open(MMOUT, ">$outputDirModuleMembership/$i" . "_1st_ExcludePseudogene" . "\.txt") or die $!;
				print MMOUT "geneID\tcorrelation_coefficient\n";
				for my $ii(@{$MMHash{$i}}){
						print MMOUT $ii;
				}
				close MMOUT;
			}
			my %inputProtocolAppNodesHash;
			foreach(@modules) {
				push @{$inputProtocolAppNodesHash{$_}}, map { $_ . " " . $self->getInputSuffixMM() } sort keys %inputs;
			}
				
			$self->setInputProtocolAppNodesHash(\%inputProtocolAppNodesHash);
			$self->setNames(\@modules);                                                                                           
			$self->setFileNames(\@files);
			$self->setProtocolName("WGCNA");
			$self->setSourceIdType("gene");
			$self->createConfigFile();
				
			#-------------- parse Module Eigengene -----#
			#-- copy module_egene file to one upper dir and the run doTranscription --#
			my $CPcommand = "cp  $outputDir/merged-0.25-eigengenes.txt  . ; 
													mv merged-0.25-eigengenes.txt merged-0.25-eigengenes_1stStrand_ExcludePseudogene.txt ";
			my $CPresults  =  system($CPcommand);
			
			my $egenes = CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles->new(
				{mainDirectory => "$mainDirectory", inputFile => "merged-0.25-eigengenes_1stStrand_ExcludePseudogene.txt",makePercentiles => 0,doNotLoad => 0, profileSetName => "$profileSetName"}
			);
			$egenes ->setTechnologyType("RNASeq");
			$egenes->setProtocolName("WGCNAME");
			
			$egenes ->munge();
				
		}
	} # End first strant processing



	#--second strand processing ------------------------------------------#
	#### Marking for removal
	if($strand eq 'secondstrand'){
		my $power = $self->getPower();
		my $inputFile = $self->getInputFile();
		my $organism = $self->getOrganism();
		my $genetype = $self->getGeneType();
		#--Version1: second strand processing  (only keep protein-coding gene in the input tpm file)-------------#
		if($genetype eq 'protein coding'){
	    my $outputFile = "Preprocessed_proteincoding_" . $inputFile;
	    my $sql = "SELECT source_id 
                   FROM apidbtuning.geneAttributes  
                   WHERE organism = '$organism' AND gene_type = 'protein coding gene'";
	    my $stmt = $dbh->prepare($sql);
	    $stmt->execute();
	    my %hash;
	    
	    while(my ($proteinCodingGenes) = $stmt->fetchrow_array() ) {
				$hash{$proteinCodingGenes} = 1;
	    }
	    
	    $stmt->finish();
	    #-------------- add 1st column header & only keep PROTEIN CODING GENES -----#
	    open(IN, "<", $inputFile) or die "Couldn't open file $inputFile for reading, $!";
	    open(OUT,">$mainDirectory/$outputFile") or die "Couldn't open file $mainDirectory/$outputFile for writing, $!";
	    
	    my %inputs;
	    while (my $line = <IN>){
				$line =~ s/\n//g;
				if ($. == 1){
		    	my @all = split("\t",$line);
		    	foreach(@all[1 .. $#all]){
						$inputs{$_} = 1;
		    	}
				}
			}
	    close IN;
	    
	    open(IN, "<", $inputFile) or die "Couldn't open file $inputFile for reading, $!";
	    while (my $line = <IN>){
				if ($. == 1){
					my @all = split/\t/,$line;
					$all[0] = 'Gene';
					my $new_line = join("\t",@all);
					print OUT $new_line;
					
					foreach(@all[1 .. $#all]){
						@all = grep {s/^\s+|\s+$//g; $_ } @all;
						$inputs{$_} = 1;
					}
				}else{
					my @all = split/\t/,$line;
					if ($hash{$all[0]}){
						print OUT $line;
					}
				}
	    }

	    close IN;
	    close OUT;

	    my $commForPermission = "chmod g+w $outputFile";
	    system($commForPermission);
	    #-------------- run IterativeWGCNA docker image -----#
	    my $comm = "mkdir $mainDirectory/SecondStrandProteinCodingOutputs; chmod g+w $mainDirectory/SecondStrandProteinCodingOutputs";
	    system($comm);
	    my $outputDir = $mainDirectory . "/SecondStrandProteinCodingOutputs";

	    my $inputFileForWGCNA = "$mainDirectory/$outputFile";
	    my $command = "singularity run  docker://jbrestel/iterative-wgcna -i $inputFileForWGCNA  -o  $outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25";
	    #my $command = "singularity run --bind $mainDirectory:/home/docker   docker://jbrestel/iterative-wgcna -i /home/docker$outputFile  -o  /home/docker/$outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25"; 
	    
	    my $results  =  system($command);
	    
	    #-------------- parse Module Membership -----#
	    my $commgw = "mkdir $mainDirectory/SecondStrandProteinCodingOutputs/SecondStrandMMResultsForLoading; chmod g+w $mainDirectory/SecondStrandProteinCodingOutputs/SecondStrandMMResultsForLoading/";
	    system($commgw);

	    my $outputDirModuleMembership = "$mainDirectory/SecondStrandProteinCodingOutputs/SecondStrandMMResultsForLoading/";
	    
	    open(MM, "<", "$outputDir/merged-0.25-membership.txt") or die "Couldn't open $outputDir/merged-0.25-membership.txt for reading";
	    my %MMHash;
	    while (my $line = <MM>) {
				if ($. == 1){
					next;
				}else{
					chomp($line);
					$line =~ s/\r//g;
					my @all = split/\t/,$line;
					push @{$MMHash{$all[1]}}, "$all[0]\t$all[2]\n";
				}
	    }

	    close MM;
	    
	    my @files;
	    my @modules;
	    my @allKeys = keys %MMHash;
	    my @ModuleNames = grep { $_ ne 'UNCLASSIFIED' } @allKeys; 
	    for my $i(@ModuleNames){
				push @modules,$i . " " . $self->getInputSuffixMM() . " " . "ProteinCoding";
				push @files,"$i" . "_2nd" . "\.txt" . " " . $self->getInputSuffixMM() . " " . "ProteinCoding" ;
				open(MMOUT, ">$outputDirModuleMembership/$i" . "_2nd_ProteinCoding" . "\.txt") or die $!;
				print MMOUT "geneID\tcorrelation_coefficient\n";
				for my $ii(@{$MMHash{$i}}){
						print MMOUT $ii;
				}
				close MMOUT;
	    }
	    my %inputProtocolAppNodesHash;
	    foreach(@modules) {
				push @{$inputProtocolAppNodesHash{$_}}, map { $_ . " " . $self->getInputSuffixMM() } sort keys %inputs;
	    }
	    
	    $self->setInputProtocolAppNodesHash(\%inputProtocolAppNodesHash);
	    $self->setNames(\@modules);                                                                                           
	    $self->setFileNames(\@files);
	    $self->setProtocolName("WGCNA");
	    $self->setSourceIdType("gene");
	    $self->createConfigFile();
	    
	    #-------------- parse Module Eigengene -----#
	    #-- copy module_egene file to one upper dir and the run doTranscription --#
	    my $CPcommand = "cp  $outputDir/merged-0.25-eigengenes.txt  . ; 
                         mv merged-0.25-eigengenes.txt merged-0.25-eigengenes_2ndStrand_ProteinCoding.txt ";
	    my $CPresults  =  system($CPcommand);
	    
	    my $egenes = CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles->new(
			{mainDirectory => "$mainDirectory", inputFile => "merged-0.25-eigengenes_2ndStrand_ProteinCoding.txt",makePercentiles => 0,doNotLoad => 0, profileSetName => "$profileSetName"}
			);

	    $egenes ->setTechnologyType("RNASeq");
	    $egenes->setProtocolName("WGCNAME");
	    
	    $egenes ->munge();
	    
		}

		#-- Version2: second strand processing  (only remove pseudogenes in the input tpm file)-------------#
		if($genetype eq 'exclude pseudogene'){
			my $outputFile = "Preprocessed_excludePseudogene_" . $inputFile;
			my $sql = "SELECT source_id 
									FROM apidbtuning.geneAttributes  
									WHERE organism = '$organism' AND gene_type != 'pseudogene'";
			my $stmt = $dbh->prepare($sql);
			$stmt->execute();
			my %hash;
				
			while(my ($proteinCodingGenes) = $stmt->fetchrow_array() ) {
				$hash{$proteinCodingGenes} = 1;
			}
				
			$stmt->finish();
			#-------------- add 1st column header & only keep PROTEIN CODING GENES -----#
			open(IN, "<", $inputFile) or die "Couldn't open file $inputFile for reading, $!";
			open(OUT,">$mainDirectory/$outputFile") or die "Couldn't open file $mainDirectory/$outputFile for writing, $!";
			
			my %inputs;
			while (my $line = <IN>){
				$line =~ s/\n//g;
				if ($. == 1){
					my @all = split("\t",$line);
					foreach(@all[1 .. $#all]){
						$inputs{$_} = 1;
					}
				}
			}
	    close IN;
	    
	    open(IN, "<", $inputFile) or die "Couldn't open file $inputFile for reading, $!";
	    while (my $line = <IN>){
				if ($. == 1){
					my @all = split/\t/,$line;
					$all[0] = 'Gene';
					my $new_line = join("\t",@all);
					print OUT $new_line;
		    
		    	foreach(@all[1 .. $#all]){
						@all = grep {s/^\s+|\s+$//g; $_ } @all;
						$inputs{$_} = 1;
		    	}
				}else{
					my @all = split/\t/,$line;
					if ($hash{$all[0]}){
						print OUT $line;
		    	}
				}
	    }
	    close IN;
	    close OUT;
	    
	    my $commForPermission = "chmod g+w $outputFile";
	    system($commForPermission);
	    #-------------- run IterativeWGCNA docker image -----#
	    my $comm = "mkdir $mainDirectory/SecondStrandExcludePseudogeneOutputs; chmod g+w $mainDirectory/SecondStrandExcludePseudogeneOutputs";
	    system($comm);

	    my $outputDir = $mainDirectory . "/SecondStrandExcludePseudogeneOutputs";

	    my $inputFileForWGCNA = "$mainDirectory/$outputFile";
	    my $command = "singularity run  docker://jbrestel/iterative-wgcna -i $inputFileForWGCNA  -o  $outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25";
	    #my $command = "singularity run --bind $mainDirectory:/home/docker   docker://jbrestel/iterative-wgcna -i /home/docker$outputFile  -o  /home/docker/$outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25"; 
	    
	    my $results  =  system($command);
	    
	    #-------------- parse Module Membership -----#
	    my $commgw = "mkdir $mainDirectory/SecondStrandExcludePseudogeneOutputs/SecondStrandMMResultsForLoading; chmod g+w $mainDirectory/SecondStrandExcludePseudogeneOutputs/SecondStrandMMResultsForLoading";
	    system($commgw);

	    my $outputDirModuleMembership = "$mainDirectory/SecondStrandExcludePseudogeneOutputs/SecondStrandMMResultsForLoading/";
	    
	    open(MM, "<", "$outputDir/merged-0.25-membership.txt") or die "Couldn't open $outputDir/merged-0.25-membership.txt for reading";
	    my %MMHash;
	    while (my $line = <MM>) {
				if ($. == 1){
					next;
				}else{
					chomp($line);
					$line =~ s/\r//g;
					my @all = split/\t/,$line;
					push @{$MMHash{$all[1]}}, "$all[0]\t$all[2]\n";
				}
	    }
	    close MM;
	    
	    my @files;
	    my @modules;
	    my @allKeys = keys %MMHash;
	    my @ModuleNames = grep { $_ ne 'UNCLASSIFIED' } @allKeys; 
	    for my $i(@ModuleNames){
				push @modules,$i . " " . $self->getInputSuffixMM() . " " . "ExcludePseudogene";
				push @files,"$i" . "_2nd" . "\.txt" . " " . $self->getInputSuffixMM() . " " . "ExcludePseudogene" ;
				open(MMOUT, ">$outputDirModuleMembership/$i" . "_2nd_ExcludePseudogene" . "\.txt") or die $!;
				print MMOUT "geneID\tcorrelation_coefficient\n";
				for my $ii(@{$MMHash{$i}}){
					print MMOUT $ii;
				}
				close MMOUT;
	    }
	    my %inputProtocolAppNodesHash;
	    foreach(@modules) {
				push @{$inputProtocolAppNodesHash{$_}}, map { $_ . " " . $self->getInputSuffixMM() } sort keys %inputs;
	    }
	    
	    $self->setInputProtocolAppNodesHash(\%inputProtocolAppNodesHash);
	    $self->setNames(\@modules);                                                                                           
	    $self->setFileNames(\@files);
	    $self->setProtocolName("WGCNA");
	    $self->setSourceIdType("gene");
	    $self->createConfigFile();
	    
	    #-------------- parse Module Eigengene -----#
	    #-- copy module_egene file to one upper dir and the run doTranscription --#
	    my $CPcommand = "cp  $outputDir/merged-0.25-eigengenes.txt  . ; 
                         mv merged-0.25-eigengenes.txt merged-0.25-eigengenes_2ndStrand_ExcludePseudogene.txt ";
	    my $CPresults  =  system($CPcommand);
	    
	    my $egenes = CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles->new(
			{mainDirectory => "$mainDirectory", inputFile => "merged-0.25-eigengenes_2ndStrand_ExcludePseudogene.txt",makePercentiles => 0,doNotLoad => 0, profileSetName => "$profileSetName"}
			);
	    $egenes ->setTechnologyType("RNASeq");
	    $egenes->setProtocolName("WGCNAME");
	    
	    $egenes ->munge();
	    
		}
	}  
} # End second strand processing



1;

