
package ApiCommonData::Load::IterativeWGCNAResults;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);

use strict;
#use CBIL::TranscriptExpression::Error;
use CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles;

use Data::Dumper;

use DBI;
use DBD::Oracle;

use GUS::Supported::GusConfig;

sub getPower        { $_[0]->{softThresholdPower} }
sub getOrganism        { $_[0]->{organism} }
sub getInputSuffixMM              { $_[0]->{inputSuffixMM} }
sub getInputSuffixME              { $_[0]->{inputSuffixME} }
sub getInputFile              { $_[0]->{inputFile} }
sub getprofileSetName              { $_[0]->{profileSetName} }
sub getTechnologyType              { $_[0]->{technologyType} }
sub getThreshold              { $_[0]->{threshold} }
sub getValueType              { $_[0]->{valueType} }
sub getQuantificationType              { $_[0]->{quantificationType} }


#-------------------------------------------------------------------------------
sub new {
  my ($class, $args) = @_; 
  $args->{sourceIdType} = "gene";
  my $self = $class->SUPER::new($args) ;          
  
  return $self;
}

#------ Note: Currently we only look at the first strand, and exclude pseudogenes ------------------------#
#---- Previous investigations considered the second strand, or running with protein coding genes only --- #

sub munge {
	my ($self) = @_;
	#------------- database configuration -----------#
	my $mainDirectory = $self->getMainDirectory();
	my $technologyType = $self->getTechnologyType();
	my $valueType = $self->getValueType();
	my $quantificationType = $self->getQuantificationType();
	my $strand = "firststrand"; # Only doing first strand analyses.
	my $profileSetName = $self->getprofileSetName();
	my $gusconfig = GUS::Supported::GusConfig->new("$ENV{GUS_HOME}/config/gus.config");
	my $dsn = $gusconfig->getDbiDsn();
	my $login = $gusconfig->getDatabaseLogin();
	my $password = $gusconfig->getDatabasePassword();

	my $dbh = DBI->connect($dsn, $login, $password, { PrintError => 1, RaiseError => 0})
		or die "Can't connect to the tracking database: $DBI::errstr\n";

	#--------- extract inputs -------#
	my $power = $self->getPower();
	my $inputFile = $self->getInputFile();
	my $organism = $self->getOrganism();
	my $threshold = $self->getThreshold();

	print "Using the first strand and excluding pseudogenes\n";
	my $preprocessedFile = "Preprocessed_" . $inputFile;
	my $sql = "SELECT ga.source_id,
							ta.length
						FROM apidbtuning.geneAttributes ga,
							apidbtuning.transcriptAttributes ta
						WHERE ga.organism = '$organism'
						AND ga.gene_type != 'pseudogene'
						AND ga.gene_id = ta.gene_id";
	my $stmt = $dbh->prepare($sql);
	$stmt->execute();

	# Create gene hash
	my %genesHash;
	my %geneLengthsHash;
	while(my ($genes, $transcript_length) = $stmt->fetchrow_array() ) {
		$genesHash{$genes} = 1;
		$geneLengthsHash{$genes} = $transcript_length;
	}
		
	$stmt->finish();


	#-------- Parse file and create input file for wgcna (called preprocessedFile) ---------#
	open(IN, "<", $inputFile) or die "Couldn't open file $inputFile for reading, $!";
	open(OUT,">$mainDirectory/$preprocessedFile") or die "Couldn't open file $mainDirectory/$preprocessedFile for writing, $!";
	
	my %inputSamples;
	# Read through inputFile. Format and apply a floor thresholding if necessary
	while (my $line = <IN>){
		# chomp $line; Removed because we actually want that new line char to show up at the end.
		if ($. == 1){
			# Handle headers
			my @headers = split("\t",$line);
			# chomp @headers; # Causing new line issues
			$headers[0] = 'Gene';
			print OUT join("\t",@headers);
			
			foreach(@headers[1 .. $#headers]){
				# Should the below come before printing?
				@headers = map {s/^\s+|\s+$//g; $_ } @headers;  # clean white space. Likely want to do a map not grep. Map returns each element of @all.
				$inputSamples{$_} = 1;
			}
		}else{
			# Each line describes one gene. First element is gene identifier
			my @geneLine = split("\t",$line);

			
			#### Let's change this to hard threshold that is a configuration in the xml threshold. Have it be in the native units (tpm or log2 ratio)
			# Will leave it to be set in the analysis config so that it can vary by dataset
			# Try running with a few cutoffs to see if any difference. Consider the wgcna output stats in optimization
			# Make sure to document in confluence! Also worth putting in readmes within the workspace directories
			# Picking 90%. Can add to the analysisConfig if necessary but keeping it simple for now.
			my $countSamplesPassingThreshold = 0;
			foreach(@geneLine[1 .. $#geneLine]){
				if ($_ > $threshold) {
					$countSamplesPassingThreshold++;
				}
			}

			if (($countSamplesPassingThreshold/$#geneLine) > 0.9) {
				$line = join("\t",@geneLine);
				# Fix for new line troubles
				chomp $line;
				$line = "$line\n";

				if ($genesHash{$geneLine[0]}){
					print OUT $line;
				}
			} else {
				print "$geneLine[0] had only $countSamplesPassingThreshold of $#geneLine samples passing the given reads threshold, so $geneLine[0] will not be included in the analysis.\n";
			}

		}
	}
	close IN;
	close OUT;
		
	#-------------- run IterativeWGCNA docker image -----#
	my $outputDir = "FirstStrandOutputs";
	my $outputDirFullPath = $mainDirectory . "/" . $outputDir;
	mkdir($outputDirFullPath);


	my $inputFileForWGCNA = "$mainDirectory/$preprocessedFile";
        my $command = "singularity run -H $mainDirectory docker://veupathdb/iterativewgcna -i $inputFileForWGCNA  -o  $outputDirFullPath  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25";
	#my $command = "singularity run --bind $mainDirectory:/home/docker   docker://jbrestel/iterative-wgcna -i /home/docker$outputFile  -o  /home/docker/$outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25"; 
	
	my $results  =  system($command);
	
	#-------------- parse Module Membership -----#
	my $outputDirModuleMembership = "FirstStrandMMResultsForLoading";
	my $outputDirModuleMembershipFullPath = $outputDirFullPath . "/" . $outputDirModuleMembership;
	mkdir($outputDirModuleMembershipFullPath);

	
	open(MM, "<", "$outputDirFullPath/merged-0.25-membership.txt") or die "Couldn't open $outputDirFullPath/merged-0.25-membership.txt for reading";
	my %MMHash;
	<MM>; # skip header
	while (my $line = <MM>) {
		chomp($line);
		my @all = split/\t/,$line;
		push @{$MMHash{$all[1]}}, "$all[0]\t$all[2]\n"; # also can just exclude Unclassified things
	}
	close MM;

		
	my @files;
	my @modules;
	my @allKeys = keys %MMHash;
	my @ModuleNames = grep { $_ ne 'UNCLASSIFIED' } @allKeys; # removes unclassifieds
	for my $i(@ModuleNames){
		push @modules,$i . " " . $self->getInputSuffixMM();
		push @files,"$outputDir/$outputDirModuleMembership" . "/$i" . "_1st" . "\.txt";
		open(MMOUT, ">$outputDirModuleMembershipFullPath/$i" . "_1st" . "\.txt") or die $!;
		print MMOUT "geneID\tcorrelation_coefficient\n";
		for my $ii(@{$MMHash{$i}}){
				print MMOUT $ii;
		}
		close MMOUT;
	}

	my %inputProtocolAppNodesHash;
	foreach(@modules) {
		push @{$inputProtocolAppNodesHash{$_}}, map { $_ } sort keys %inputSamples;
	}
		
	# Sets things for config file. What my instance of this object did (parameters)
	$self->setInputProtocolAppNodesHash(\%inputProtocolAppNodesHash);
	$self->setNames(\@modules);                                                                                           
	$self->setFileNames(\@files);
	$self->setProtocolName("WGCNA");
	$self->setSourceIdType("module");
	$self->createConfigFile();
		
		
	#-------------- parse Module Eigengene -----#

	#-- copy module_egene file to one upper dir and the run doTranscription --#
	my $CPcommand = "cp  $outputDirFullPath/merged-0.25-eigengenes.txt  . ; 
											mv merged-0.25-eigengenes.txt merged-0.25-eigengenes_1stStrand.txt ";
	my $CPresults  =  system($CPcommand);

	# Also something like sourceIdType. Default is "gene". In this case should probably be "eigengene" so that the plugin knows.
	my $egenes = CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles->new(
		{mainDirectory => "$mainDirectory", inputFile => "merged-0.25-eigengenes_1stStrand.txt",makePercentiles => 0,doNotLoad => 0, profileSetName => "$profileSetName"}
	);
	$egenes ->setTechnologyType("RNASeq");
        $egenes->setDisplaySuffix(" [$quantificationType" . " - $strand" . " - $valueType" . " - unique]");
	$egenes->setProtocolName("wgcna_eigengene"); # Will be consumed by the loader (insertAnalysisResults plugin). Also need to change it in the plugin
	
	# The following writes the appropriate rows in insert_study_results_config.txt
        $egenes ->munge();
			
}



1;

