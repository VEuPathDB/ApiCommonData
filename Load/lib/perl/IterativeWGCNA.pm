package ApiCommonData::Load::IterativeWGCNA;
use base qw(CBIL::TranscriptExpression::DataMunger);

use strict;
use CBIL::TranscriptExpression::Error;
use Data::Dumper;
use Exporter;
use File::Basename;

use DBI;
use DBD::Oracle;
use File::Temp qw/ tempfile /;
use Data::Dumper;

use lib "$ENV{GUS_HOME}/lib/perl";
use warnings;
use GUS::ObjRelP::DbiDatabase;

use DBI;
use DBD::Oracle;

sub getOrganism        { $_[0]->{organismAbbre} }

#-------------------------------------------------------------------------------
sub new {
  my ($class, $args) = @_; 

  my $mainDirectory = $args->{mainDirectory};
  my $inputfile = $mainDirectory. "/" . $args->{inputFile};
  my $organism = $args->{organismAbbre};
  my $cleanfile = &preprocessFile($inputfile,$organism);
  $args->{inputFile} = $cleanfile;


  my $self = $class->SUPER::new($args) ;          
  
  return $self;
}



sub preprocessFile {

    my ($file,$organism)=@_;
    #-------------- connect to database to only keep PROTEIN CODING GENES -----------------------------
    my $dbConnection = "PlasmoDB";
    my $dbLogin = "linxu123";
    my $dbPassword = "to5snpge";

    my $dbh = DBI->connect($dbConnection, $dbLogin, $dbPassword) or die "Unable to connect: DBI->errstr\n";
    my $stmt = $dbh->prepare("SELECT source_id
                              FROM ApidbTuning.geneAttributes ga
                              where organism = '$organism' AND gene_type = 'protein coding gene'");
    $stmt->execute();

    my %hash;

    my $proteinCodingGenes = $stmt->fetchrow_array();

    $hash{$proteinCodingGenes} = 1;

    $stmt->finish();

    #-------------- add 1st column header & only keep PROTEIN CODING GENES -----------------------------
    my $outputFile = "Preprocessed_" . basename($file);

    open(IN, "<", $file) or die "Couldn't open file $file for reading, $!";
    open(OUT,">$mainDirectory/$outputFile" ) or die "Couldn't open file $mainDirectory/$outputFile for writing, $!";


    while (my $line = <IN>){
	if ($. == 1){
	    my @all = split/\t/,$line;
	    $all[0] = 'Gene';
	    my $new_line = join("\t",@all);
	    print OUT $new_line; 
	}else{
	    my @all = split/\t/,$line;
	    if ($hash{$all[0]}){
		print OUT $line; 
	    }
	}
    }
    close IN;
    close OUT;

    return  $outputFile;
}


1;

