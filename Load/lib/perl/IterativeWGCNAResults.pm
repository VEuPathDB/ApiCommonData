
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

#------ Note: Currently we only look at the first strand, and exclude pseudogenes ------------------------#
#---- Previous investigations considered the second strand, or running with protein coding genes only --- #

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

	#--------- extract inputs -------#
	my $power = $self->getPower();
	my $inputFile = $self->getInputFile();
	my $organism = $self->getOrganism();
	my $genetype = $self->getGeneType();
	my $readsThreshold = $self->getReadsThreshold();
	my $datasetName = $self->getDatasetName();

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

	# Create gene hash
	my %genesHash;
	my %geneLengthsHash;
	while(my ($genes, $transcript_length) = $stmt->fetchrow_array() ) {
		$genesHash{$genes} = 1;
		$geneLengthsHash{$genes} = $transcript_length;
	}
		
	$stmt->finish();

	#--------- Find average unique reads for this dataset ------------#
	my ($avg_unique_reads) = $dbh->selectrow_array("select avg(avg_unique_reads)
												from apidbtuning.rnaseqstats
												where dataset_name = '$datasetName'
												group by dataset_name");


	#-------- Parse file and create input file for wgcna (called outputFile) ---------#
	open(IN, "<", $inputFile) or die "Couldn't open file $inputFile for reading, $!";
	open(OUT,">$mainDirectory/$outputFile") or die "Couldn't open file $mainDirectory/$outputFile for writing, $!";
	
	my %inputs; #### ANN find out of these are wgcna inputs or what. I think these are samples.
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
				# @headers = map {s/^\s+|\s+$//g; $_ } @headers;  # clean white space. Likely want to do a map not grep. Map returns each element of @all.
				$inputs{$_} = 1;
			}
		}else{
			# Each line describes one gene. First element is gene identifier
			my @geneLine = split("\t",$line);

			# Calculate and apply the floor based on the pre-defiend readsThreshold
			my $hard_floor = $readsThreshold * 1000000 * $geneLengthsHash{$geneLine[0]} / $avg_unique_reads;
			foreach(@geneLine[1 .. $#geneLine]){
				if ($_ < $hard_floor) {
					$_ = $hard_floor;
				}
			}

			$line = join("\t",@geneLine);

			# Fix for new line troubles
			chomp $line;
			$line = "$line\n";

			if ($genesHash{$geneLine[0]}){
				print OUT $line;
			}

		}
	}
	close IN;
	close OUT;
		
	#-------------- run IterativeWGCNA docker image -----#
	mkdir("$mainDirectory/FirstStrandExcludePseudogeneOutputs");
	my $outputDir = $mainDirectory . "/FirstStrandExcludePseudogeneOutputs";

	my $inputFileForWGCNA = "$mainDirectory/$outputFile";
	my $command = "singularity run  docker://jbrestel/iterative-wgcna -i $inputFileForWGCNA  -o  $outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25";
	#my $command = "singularity run --bind $mainDirectory:/home/docker   docker://jbrestel/iterative-wgcna -i /home/docker$outputFile  -o  /home/docker/$outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25"; 
	
	my $results  =  system($command);
	print $results;
	
	#-------------- parse Module Membership -----#
	mkdir("$mainDirectory/FirstStrandExcludePseudogeneOutputs/FirstStrandMMResultsForLoading");
	my $outputDirModuleMembership = "$mainDirectory/FirstStrandExcludePseudogeneOutputs/FirstStrandMMResultsForLoading/";
	
	open(MM, "<", "$outputDir/merged-0.25-membership.txt") or die "Couldn't open $outputDir/merged-0.25-membership.txt for reading";
	my %MMHash;
	<MM>; # skip header
	while (my $line = <MM>) {
		chomp($line);
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
		
	# Sets things for config file. What my instance of this object did (parameters)
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

	# Also something like sourceIdType. Default is "gene". In this case should probably be "eigengene" so that the plugin knows.
	my $egenes = CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles->new(
		{mainDirectory => "$mainDirectory", inputFile => "merged-0.25-eigengenes_1stStrand_ExcludePseudogene.txt",makePercentiles => 0,doNotLoad => 0, profileSetName => "$profileSetName"}
	);
	$egenes ->setTechnologyType("RNASeq");
	# $egenes->setProtocolName("WGCNAME");
	$egenes->setProtocolName("WGCNAModuleEigengenes"); # Will be consumed by the loader (insertAnalysisResults plugin). Also need to change it in the plugin
	$egenes->createConfigFile(); # writes the config row
	
	$egenes ->munge();
			
}



1;

