package ApiCommonData::Load::Plugin::InsertPubChemCompounds;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------
# Plugin to load PubChem Compound data
# ----------------------------------------------------------

use strict;
use warnings;

use XML::Twig;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::PubChemCompound;


my %cmpd;
my $cmpd_id;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     stringArg({ name => 'fileDir',
		 descr => 'full path to xml files',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
		 mustExist => 1,
	       }),
     stringArg({ name => 'fileName',
		 descr => 'xml data file',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
		 mustExist => 0,
	       })
    ];

  return $argsDeclaration;
}

# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load PubChem Compounds out of a single XML file, into ApiDB.PubChemCompound
DESCR

  my $purpose = <<PURPOSE;
Plugin to load PubChem Compounds
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load PubChem Compounds
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.PubChemCompound
AFFECT

  my $tablesDependedOn = <<TABD;
TABD

  my $howToRestart = <<RESTART;
No restart provided. Must undo and reload.
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = { purpose          => $purpose,
                        purposeBrief     => $purposeBrief,
                        tablesAffected   => $tablesAffected,
                        tablesDependedOn => $tablesDependedOn,
                        howToRestart     => $howToRestart,
                        failureCases     => $failureCases,
                        notes            => $notes
                      };

  return ($documentation);
}

# ----------------------------------------------------------

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();
  my $args = &getArgsDeclaration();
  my $configuration = { requiredDbVersion => 3.6,
                        cvsRevision => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };
  $self->initialize($configuration);
  return $self;
}

# ----------------------------------------------------------

sub run {
  my $self = shift;

  my $roots = { 'PC-Compound_id' => 0,
		'PC-Compound_props' => 0,
	      };

  my $handlers = { 'PC-Compound_id/PC-CompoundType/PC-CompoundType_id' => \&get_ID,
		   'PC-Compound_props/PC-InfoData' => \&get_DATA,
		 };

  my $twig = new XML::Twig(TwigRoots => $roots,
			   TwigHandlers => $handlers);

  my $fileDir = $self->getArg('fileDir');
  my $fileName = $self->getArg('fileName');

  my $file = $fileDir. "/" . $fileName;
  $twig->parsefile($file);

  $self->insertPubChemCompound();

}


# get CIDs of already_loaded PubChem compounds
sub getExistingCids {
  my ($self) = @_;
  my %cidHash;

  my $sql = "SELECT distinct compound_id from ApiDB.PubChemCompound";

  my $dbh = $self->getQueryHandle();
  my $sth = $dbh->prepareAndExecute($sql);

  while(my $cid = $sth->fetchrow_array()){
    $cidHash{$cid} = 1;
  }
  return \%cidHash;
}



sub insertPubChemCompound {
  my $self = shift;
  my $count;

  # get list (as hash) of compound (IDs) that are already in the database
  my $hashRef=$self->getExistingCids();
  my %loadedCids = %$hashRef;


  my @data = keys(%cmpd);  # keys of outer hash are compound IDs
  foreach my $cid (@data) {

    # load compound if CID is not in database
    if ($loadedCids{$cid}) {
      $self->log("Ignoring CID $cid; it is already present in ApiDB.PubChemCompound.");
    } else {

      my %y = %{$cmpd{$cid}};
      my @props = keys(%y);   # keys are inner various properties for each compound

      foreach my $p (@props) {
	my ($property, $type) = split(/\|type\=/, $p);

	# print "$cid, $p, " . $cmpd{$cid}{$p} . " \n";

	my $pubChemCmpd = GUS::Model::ApiDB::PubChemCompound->new({ compound_id => $cid,
								    property    => $property,
								    type        => $type,
								    value       => $cmpd{$cid}{$p}
								  });
	$pubChemCmpd->submit();
      }

      $count++;
      $self->undefPointerCache() if $count % 100 == 0;

      $self->log("Inserted entries for $count PubChem Compounds.");

    }
  }

}




sub get_ID {
  my ($twig, $ele) = @_;
  my $id = $ele->first_child('PC-CompoundType_id_cid')->text;

  $cmpd_id = $id;
}


sub get_DATA {
  my ($twig, $ele) = @_;
  my @fields = ('IUPAC Name', 'InChI', 'InChIKey', 'Mass', 'Molecular Formula', 'Molecular Weight', 'SMILES', 'Weight');


  my $prop = $ele->next_elt('PC-Urn_label')->text;
  my $type = ($ele->next_elt('PC-Urn_name'))? $ele->next_elt('PC-Urn_name')->text : '';
  my $key = $prop . "|type=". $type; # combine property and type

  if ({map { $_ => 1 } @fields}->{$prop} ) {
    my $val = $ele->first_child('PC-InfoData_value')->text;

    $cmpd{$cmpd_id}{$key} = $val;

  }

}




sub undoTables {
  my ($self) = @_;

  return ('ApiDB.PubChemCompound');
}


return 1;
