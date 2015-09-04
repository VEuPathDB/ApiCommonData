package ApiCommonData::Load::Plugin::InsertRodentChrColors.pm

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Supported::Util;

use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::ApiDB::RodentChrColors;

my $argsDeclaration =
  [
   fileArg({name => 'mappingFile',
	    descr => 'A tab-delimited file with header row, mapping Rodent Malaria genome with Pfal genes',
	    reqd => 1,
	    mustExist => 1,
	    format => 'VI      1       light blue      #CCFFFF 0       MAL6P1.23       132606  MAL6P1.283      648830',
	    constraintFunc => undef,
	    isList => 0, }),
];

my $purpose = <<PURPOSE;
Assign colors for chromosomes
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Colors for chromosomes
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
No Restart utilities for this plugin.
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation = { purpose          => $purpose,
		      purposeBrief     => $purposeBrief,
		      notes            => $notes,
		      tablesAffected   => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart     => $howToRestart,
		      failureCases     => $failureCases };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.6,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});
  return $self;
}


sub run {
  my ($self) = @_;

  # method to read data into an array
  my @all_data =   $self->readFile();
  
  $self->addChromosomeColorTable(@all_data);

  return("$ct contigs assigned chromosome");
}


# method to read input file and save all the data in an array of hashes
sub readFile {
  my ($self) = @_;
  open(FILE, $self->getArg('mappingFile')) || die "Could Not open File for reading: $!\n";

  my $index = -1; #count of the number of break points
  my @data;       #array of data, between the break points
  my $file =  $self->getArg('mappingFile') ;
  open(FILE, $self->getArg('mappingFile')) || die "Could Not open File for reading: $!\n";

  while(<FILE>) {
    $index++;
    next if $index<1; #discard header row in file
    chomp;
    my %piece;
    my $temp; # going to ignore the Pfal gene positions
    ($piece{pfal_chr}, $piece{rmp_chr}, $piece{colorName}, $piece{colorValue}, $piece{is_reversed}, $piece{gene_left}, $temp, $piece{gene_right}, $temp) = split('\t', $_);
    push (@data, \%piece);
  }
  close(FILE);
  return(@data);
}

sub addChromosomeColorTable {
  my ($self, @arrData) = @_;
  my (%name, %color);

  for my $row (@arrData){
    my %row = %{$row};
    $name{$row{rmp_chr}} = $row{colorName};
    $color{$row{rmp_chr}} = $row{colorValue};
  }

  foreach my $key (sort keys(%name)) {
    my ($name, $value) = ($name{$key}, $color{$key});
    $self->log("COLORS: $key, $name, $value");
     my $profile = GUS::Model::ApiDB::RodentChrColors->
	      new({chromosome => $key,
		   color => $name,
		   value => $value
		   });
	  $profile->submit();
  }
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.RodentChrColors',
	 );
}


1;

