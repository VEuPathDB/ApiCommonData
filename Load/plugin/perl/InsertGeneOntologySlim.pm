package ApiCommonData::Load::Plugin::InsertGeneOntologySlim;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use Data::Dumper;
use GUS::Model::SRes::OntologyTerm;
use GUS::Model::ApiDB::GoSubset; 
use Text::Balanced qw(extract_quotelike extract_delimited);



my $argsDeclaration =
  [
   fileArg({ name           => 'oboFile',
	     descr          => 'The Gene Ontology OBO file',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => 'OBO format',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

   stringArg({ name           => 'extDbRlsName',
	       descr          => 'external database release name for the GO ontology',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0,
	     }),

   stringArg({ name           => 'extDbRlsVer',
	       descr          => 'external database release version for the GO ontology. Must be equal to the data-version of the GO ontology as stated in the oboFile',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0,
	     }),
  ];

my $purpose = <<PURPOSE;
Insert all terms from a Gene Ontology OBO file that have a go subset declared.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert all terms from a Gene Ontology OBO file that have a go subset declared.
PURPOSE_BRIEF

my $notes = <<NOTES;
This plugin must use the same obo file as used in the gus supported plugin insertGeneOntology.
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
apidb.GoSubset
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
sres.OntologyTerm
TABLES_DEPENDED_ON

###### NOT SURE WHAT THE HowtoREstart WILL BE 

my $howToRestart = <<RESTART;
RESTART

###### NOT SURE WHAT THE FAILURE CASES WILL BE 

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation =
  { purpose          => $purpose,
    purposeBrief     => $purposeBrief,
    notes            => $notes,
    tablesAffected   => $tablesAffected,
    tablesDependedOn => $tablesDependedOn,
    howToRestart     => $howToRestart,
    failureCases     => $failureCases
  };

sub new {
  my ($class) = @_;
  $class = ref $class || $class;

  my $self = bless({}, $class);

  $self->initialize({ requiredDbVersion => 4.0,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation
		    });

  return $self;
}

sub run {
  my ($self) = @_;


  my $oboFile = $self->getArg('oboFile');
  open(OBO, "<$oboFile") or $self->error("Couldn't open '$oboFile': $!\n");

  my $dataVersion = $self->_parseDataVersion(\*OBO);

  my $extDbRlsName = $self->getArg('extDbRlsName');
  my $extDbRlsVer = $self->getArg('extDbRlsVer');

  #$self->error("extDbRlsVer $extDbRlsVer does not match data-version $dataVersion of the obo file\n")
  #  unless $dataVersion eq $extDbRlsVer;

  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsName, $extDbRlsVer);
#  my $termsToCheck = $self->queryForOntologyTermIds();
#  print Dumper $termsToCheck;
  my %goTerms;
  my %subsets;
  my $goTerm;
  my $count = 0;
  my $count2 = 0;
  my %subs;
 while (my $ line =<OBO>) {
      chomp $line;
      
      if($line=~ m/^id.+(GO:\d+)$/) {
#       die "getting here\n";
#	  $self->undefPointerCache();
	  $goTerm = $1;
	  if (exists $goTerms{$goTerm}){
	      die "there are multiple entries for go term $goTerm\n";
	  }
	  else {
	      $goTerms{$goTerm} =1;
	  }
      }
      elsif ($line =~ m/^subset:\s(.+)$/) {
	  my $subsetTerm=$1;
#       print $subsetTerm."\t";
        push (@{$subsets{$goTerm}}, $subsetTerm);
#	  my $go=$goTerm;
#	  
#	  $go =~ s/:/_/;
##	  my $ontologyTermId= $termsToCheck->{$go};
##	  my $ontologyTermId=$self->queryForOntologyTermId($go);
##	  $self->userError("go term $go specified but not found in ontology table") unless($ontologyTermId);
 
##	  my $goSubset = GUS::Model::ApiDB::GoSubset->new({
##	      go_subset_term                    =>$subsetTerm,
##	      ontology_term_id        => $ontologyTermId,
##	      external_database_release_id => $extDbRlsId,
##							  });
#	  print Dumper $goSubset;
	 # undef $goSubset;
      }
      else {
	  next;
      }

  
  }

  close(OBO);
  
  foreach my $element(keys %subsets) {
      my $go=$element;
      
      $go =~ s/:/_/;
      #   my $ontologyTermId= $termsToCheck->{$go};
      #    $self->userError("go term $go specified but not found in ontology table") unless($ontologyTermId);
      my $ontologyTermId=$self->queryForOntologyTermId($go);
      $self->userError("go term $go specified but not found in ontology table") unless($ontologyTermId);
      
      foreach my $subs (@{$subsets{$element}}) {
	  my $goSubset = GUS::Model::ApiDB::GoSubset->new({
	      go_subset_term                    => $subs,
	      ontology_term_id        => $ontologyTermId,
	      external_database_release_id => $extDbRlsId,
							  });
#	  print Dumper $goSubset;
	  $count2 ++;
      }
      $self->undefPointerCache() if $count++ % 500 == 0;

  }
#      $self->undefPointerCache() if $count++ % 500 == 0;

  return "Inserted $count2 GoSubsets";

}


sub _parseDataVersion {

  my ($self, $fh) = @_;

  my $dataVersion;
  while (<$fh>) {
    #if (m/^version\: (\S+)$/) {
    if (m/version\: releases\/(\S+)$/) {
      $dataVersion = $1;
      last;
    }
  }

  unless (length $dataVersion) {
    $self->error("Couldn't parse out the data-version!\n");
  }

  return $dataVersion;
}

sub queryForOntologyTermIds {
    my ($self) = @_;
#    $goTerm =~ s/:/_/;
    my $dbh = $self->getQueryHandle();
    my $query = "select distinct ontology_term_id, source_id from sres.ontologyterm where source_id like 'GO_%'";
    
    my $sh = $dbh->prepare($query);
    $sh->execute();
    
    my %terms;
    while(my ($id,$go) = $sh->fetchrow_array()) {
	$terms{$go}=$id;

    }
	return \%terms;

    $sh->finish();
    
}
sub queryForOntologyTermId {
    my ($self, $goTerm) = @_;
    $goTerm =~ s/:/_/;
    my $dbh = $self->getQueryHandle();
    my $query = "select distinct ontology_term_id from sres.ontologyterm where source_id = '$goTerm'";
    my $sh = $dbh->prepare($query);
    $sh->execute();
    my $term;

    while(my ($id) = $sh->fetchrow_array()) {
#	$terms{$go}=$id;
	$term=$id;
    }
	return $term;
    undef $term;
    $sh->finish();
    
}




sub undoTables {
  my ($self) = @_;

  return ('ApiDB.GoSubset');
}


1;


