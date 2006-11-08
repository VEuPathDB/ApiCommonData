package ApiCommonData::Load::Plugin::InsertSnpDesc;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::SnpFeature;
use GUS::Model::DoTS::SeqVariation;
use GUS::Model::DoTS::NALocation;


# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [
     stringArg({name => 'skipExtDbRlsSpec',
		descr => 'what are the external database name|version pairs that should NOT be updated',
		constraintFunc => undef,
		reqd => 0,
		isList => 1
	       }),

    ];
  return $argsDeclaration;
}

# ---------------------------------------------------------------------
# Documentation
# ---------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Inserts a list of strain:allele:product into the description feild of DoTS.SnpFeature";

  my $purpose = <<PLUGIN_PURPOSE;
Inserts a list of "strain:allele:product" for the different strains into the description feild of DoTS.SnpFeature.  The information is pulled from the DoTS.SeqVariation entries for the SnpFeature.
PLUGIN_PURPOSE

  my $tablesAffected = [['DoTS::SnpFeature', 'The description field will be filled in with a list of strain:allele:product information.']];

  my $tablesDependedOn = [['SRes::ExternalDatabaseRelease',  'The releases to be skipped must be found here.'],['DoTS.SnpFeature','The SNPs exist here.'],['DoTS.SeqVariation','Information on the alleles for different strains exists here.']];

  my $howToRestart = "";

  my $failureCases = "None known.";

  my $notes = "";

  my $documentation = { purpose=>$purpose,
			purposeBrief=>$purposeBrief,
			tablesAffected=>$tablesAffected,
			tablesDependedOn=>$tablesDependedOn,
			howToRestart=>$howToRestart,
			failureCases=>$failureCases,
			notes=>$notes
		      };

  return $documentation;
}

# ----------------------------------------------------------------------
# create and initalize new plugin instance.
# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $argumentDeclaration = &getArgumentsDeclaration();


  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision$',
                     name => ref($self),
                     revisionNotes => '',
                     argsDeclaration => $argumentDeclaration,
                     documentation => $documentation
		    });

  return $self;
}


# ----------------------------------------------------------------------
# run method to do the work
# ----------------------------------------------------------------------


sub run{
  my ($self) = @_;
  my @snps;
  my @extDbRlsList;
  my $extDbSpecList;

  if ($self->getArg('skipExtDbRlsSpec')) {
    $extDbSpecList = $self->getArg('skipExtDbRlsSpec');
    foreach my $extDbSpec (@$extDbSpecList){
      my $extDbRls = $self->getExtDbRlsId($extDbSpec);
      push(@extDbRlsList, $extDbRls);
    }
  }

  $self->{revComp} = {A => 'T',
		      T => 'A',
		      C => 'G',
		      G => 'C'};

  $self->getSnpIds(\@snps, \@extDbRlsList);

  my $count = $self->createDescription(\@snps);

  my $msg = "Finished updating $count rows.";

  return $msg;
}

sub getSnpIds{
  my ($self, $snps, $extDbRlsList) = @_;
  my $extDbRls;

  $self->log("Acquiring SNP IDs...");

  my $sql = <<EOSQL;
     SELECT na_feature_id
     FROM DoTS.SnpFeature
EOSQL

  if(scalar(@$extDbRlsList)){
    $extDbRls = join(",", @$extDbRlsList);
    $sql .= "WHERE external_database_release_id NOT IN ($extDbRls)";
  }

    my $stmt = $self->prepareAndExecute($sql);
    while (my ($snpId) = $stmt->fetchrow_array()) {
      push(@$snps, $snpId);
    }
}

sub createDescription{
  my ($self, $snps) = @_;
  my $sql;
  my $stmt;
  my $count = 0;

  foreach my $snpId (@$snps){
    my $strains;
    my $strainsRevComp;
    my %alleles;
    my %products;

    $sql = <<EOSQL;
     SELECT strain, allele, product
     FROM DoTS.SeqVariation
     WHERE parent_id = $snpId
EOSQL

    $stmt = $self->prepareAndExecute($sql);
    while (my ($strain, $allele, $product) = $stmt->fetchrow_array()) {
      $strain =~ s/\s//g;
      $allele =~ s/\s//g;
      uc($allele);

      $alleles{$allele}++;

      my $revCompAllele;
      if($product){
	$product =~ s/\s//g;
	$products{$allele} = $product;

	$strains .= "\"$strain\:$allele\:$product\" ";

	$revCompAllele = $self->{revComp}->{$allele};
	$strainsRevComp .= "\"$strain\:$revCompAllele\:$product\" ";

      }else{
	$strains .= "\"$strain\:$allele\" ";

	$revCompAllele = $self->{revComp}->{$allele};
	$strainsRevComp .= "\"$strain\:$revCompAllele\" ";
      }
    }

    my $snpFeat = $self->addMajorMinorInfo($snpId, \%alleles, \%products);
    $snpFeat->setStrains($strains);
    $snpFeat->setStrainsRevcomp($strainsRevComp);
    $snpFeat->submit;
    $count++;
    $self->undefPointerCache();

    if ($count % 100 == 0){
      $self->log("Updated $count rows");
    }
  }

  return $count;
}

sub addMajorMinorInfo{
  my ($self, $snpId, $alleles, $products) = @_;
  my $majorAllele;
  my $majorAlleleCount;
  my $minorAllele;
  my $minorAlleleCount;
  my $majorProduct;
  my $majorProductCount;
  my $minorProduct;
  my $minorProductCount;
  my @sortedAlleleKeys;

  foreach my $allele (sort {$$alleles{$b} <=> $$alleles{$a}} keys %$alleles){
    push(@sortedAlleleKeys, $allele) unless($allele eq "");
  }

  $majorAllele = @sortedAlleleKeys[0];
  $majorAlleleCount = $$alleles{$majorAllele};
  $minorAllele = @sortedAlleleKeys[1];
  $minorAlleleCount = $$alleles{$minorAllele};
  $majorProduct = $$products{$majorAllele};
  $minorProduct = $$products{$minorAllele};


  my $snpFeat = GUS::Model::DoTS::SnpFeature->new({na_feature_id => $snpId});
  $snpFeat->retrieveFromDB();

  $snpFeat->setMajorAllele($majorAllele);
  $snpFeat->setMajorAlleleCount($majorAlleleCount);
  $snpFeat->setMajorProduct($majorProduct);
  $snpFeat->setMinorAllele($minorAllele);
  $snpFeat->setMinorAlleleCount($minorAlleleCount);
  $snpFeat->setMinorProduct($minorProduct);

  return $snpFeat;
}

1;
