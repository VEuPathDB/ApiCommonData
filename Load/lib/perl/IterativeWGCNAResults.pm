
package ApiCommonData::Load::IterativeWGCNAResults;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);

use strict;
#use CBIL::TranscriptExpression::Error;
use CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles;

use Data::Dumper;

use DBI;
use DBD::Oracle;

use GUS::Supported::GusConfig;

sub getStrandness        { $_[0]->{strandness} }
sub getPower        { $_[0]->{softThresholdPower} }
sub getOrganism        { $_[0]->{organismAbbre} }
sub getInputSuffixMM              { $_[0]->{inputSuffixMM} }
sub getInputSuffixME              { $_[0]->{inputSuffixME} }
sub getInputFile              { $_[0]->{inputFile} }
sub getprofileSetName              { $_[0]->{profileSetName} }
sub getTechnologyType              { $_[0]->{technologyType} }

#my $PROTOCOL_NAME = 'WGCNA';

#-------------------------------------------------------------------------------
sub new {
  my ($class, $args) = @_; 

  my $mainDirectory = $args->{mainDirectory};
  my $technologyType = $args->{technologyType};
  my $inputfile = $mainDirectory. "/" . $args->{inputFile};
  my $strandness = $args->{strandness};
  my $power = $args->{softThresholdPower};
  my $organism = $args->{organismAbbre};

  $args->{sourceIdType} = "gene"; ##### source_id type should be gene or module??????????
  my $self = $class->SUPER::new($args) ;          
  
  return $self;
}


sub munge {
    my ($self) = @_;
    #------------- database configuration -----------#
    my $strandness = $self->getStrandness();
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
    if($strandness eq 'firststrand'){
	my $power = $self->getPower();
	my $inputFile = $self->getInputFile();
	my $organism = $self->getOrganism();
	
	my $outputFile = "Preprocessed_" . $inputFile;
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
	    if ($. == 1){
		my @all = split("\t",$line);
		foreach(@all[1 .. $#all]){
		    #@all = grep {s/^\s+|\s+$//g; $_} @all;
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
        #-------------- run IterativeWGCNA docker image -----#
	my $outputDir = $mainDirectory . "/FirstStrandOutputs";
	my $comm = "chmod u=rwx,g=rwx,o=rwx  $outputDir";
	system($comm);

	my $inputFileForWGCNA = "$mainDirectory/$outputFile";
	my $command = "singularity run  docker://jbrestel/iterative-wgcna -i $inputFileForWGCNA  -o  $outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25";
	#my $command = "singularity run --bind $mainDirectory:/home/docker   docker://jbrestel/iterative-wgcna -i /home/docker$outputFile  -o  /home/docker/$outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25"; 


	my $results  =  system($command);

	#-------------- parse Module Membership -----#
	my $outputDirModuleMembership = "$mainDirectory/FirstStrandOutputs/FirstStrandMMResultsForLoading/";
	mkdir($outputDirModuleMembership, 0777) unless(-d $outputDirModuleMembership );
	
	open(MM, "<", "$outputDir/merged-0.25-membership.txt") or die "Couldn't open file for reading, $!";
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
            push @modules,$i . " " . $self->getInputSuffixMM();
            push @files,"$i\.txt" . " " . $self->getInputSuffixMM();
            open(MMOUT, ">$outputDirModuleMembership/$i\.txt") or die $!;
            print MMOUT "geneID\tcorrelation_coefficient\n";
            for my $ii(@{$MMHash{$i}}){
                print OUT $ii;
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
	my $CPcommand = "cp  $outputDir/merged-0.25-eigengenes.txt  .";
        my $CPresults  =  system($CPcommand);

	my $egenes = CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles->new(
	    {mainDirectory => "$mainDirectory", inputFile => "merged-0.25-eigengenes.txt",makePercentiles => 0,doNotLoad => 0, profileSetName => "$profileSetName"}
	    );
	$egenes ->setTechnologyType("RNASeq");
	$egenes ->munge();
    }


    #--second strand processing ------------------------------------------#
    if($strandness eq 'secondstrand'){
	my $power = $self->getPower();
	my $inputFile = $self->getInputFile();
	my $organism = $self->getOrganism();

	my $outputFile = "Preprocessed_" . $inputFile;
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
	    if ($. == 1){
		my @all = split("\t",$line);
		foreach(@all[1 .. $#all]){
		    #@all = grep {s/^\s+|\s+$//g; $_} @all;
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
        #-------------- run IterativeWGCNA docker image -----#
	my $outputDir = $mainDirectory . "/SecondStrandOutputs";
	mkdir($outputDir, 0777) unless(-d $outputDir );

	my $inputFileForWGCNA = "$mainDirectory/$outputFile";
	my $command = "singularity run  docker://jbrestel/iterative-wgcna -i $inputFileForWGCNA  -o  $outputDir  -v  --wgcnaParameters maxBlockSize=3000,networkType=signed,power=$power,minModuleSize=10,reassignThreshold=0,minKMEtoStay=0.8,minCoreKME=0.8  --finalMergeCutHeight 0.25";

	my $results  =  system($command);

	#-------------- parse Module Membership -----#
	my $outputDirModuleMembership = "$mainDirectory/SecondStrandOutputs/SecondStrandMMResultsForLoading/";
	mkdir($outputDirModuleMembership, 0777) unless(-d $outputDirModuleMembership );
	
	open(MM, "<", "$outputDir/merged-0.25-membership.txt") or die "Couldn't open file for reading, $!";
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
            push @modules,$i . " " . $self->getInputSuffixMM();
            push @files,"$i\.txt" . " " . $self->getInputSuffixMM();
            open(MMOUT, ">$outputDirModuleMembership/$i\.txt") or die $!;
            print MMOUT "geneID\tcorrelation_coefficient\n";
            for my $ii(@{$MMHash{$i}}){
                print OUT $ii;
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
	my $eigengenefile =  "$outputDir/merged-0.25-eigengenes.txt";

	my $egenes = CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles->new({inputFile => $eigengenefile});
	$egenes->setProtocolName("WGCNAME");
	$egenes->munge();

    }


}



1;

