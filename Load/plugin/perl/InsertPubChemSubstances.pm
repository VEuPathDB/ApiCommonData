package ApiCommonData::Load::Plugin::InsertPubChemSubstances;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------
# Plugin to load PubChem Substance data
# ----------------------------------------------------------

use strict;
use warnings;

use XML::Twig;
use GUS::PluginMgr::Plugin;
use GUS::Model::bindu::PubChemSubstance;


my %subst;
my $subst_id;

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
Plugin to load PubChem Substances out of a single XML file, into bindu.PubChemSubstance
DESCR

  my $purpose = <<PURPOSE;
Plugin to load PubChem Substances
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load PubChem Substances
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
bindu.PubChemSubstance
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

  my $roots = { 'PC-Substance_sid' => 0,
		'PC-Compound' =>1,
		'PC-Substance_source/PC-Source/PC-Source_db/PC-DBTracking' => 1,
		'PC-Substance_synonyms' => 0
	      };

  my $handlers = { 'PC-Substance_sid/PC-ID' => \&get_ID,
		   'PC-Compound' => \&get_CID,
		   'PC-Substance_source/PC-Source/PC-Source_db/PC-DBTracking'  => \&get_KEGG,
		   'PC-Substance_synonyms' => \&get_Syns
		 };
  my $twig = new XML::Twig(TwigRoots => $roots,
			   TwigHandlers => $handlers);


  my $fileDir = $self->getArg('fileDir');
  my $fileName = $self->getArg('fileName');

  my $file = $fileDir. "/" . $fileName;
  $twig->parsefile($file);

  $self->insertPubChemSubstance();

}

sub insertPubChemSubstance {
  my $self = shift;
  my $count;

  # process array of hashes (of hashes) for each substance
  my @data = keys(%subst);  # keys of outer hash are substance IDs
  foreach my $sid (@data) {

    my %y = %{$subst{$sid}};
    my @props = keys(%y);   # keys of inner hash are various properties for each substance

    foreach my $p (@props) {
      if ($p ne 'synonymns') {
	# print "$sid, $p, " . $subst{$sid}{$p} . " \n";

	my $pubChemSubst = GUS::Model::bindu::PubChemSubstance->new({ substance_id => $sid,
								      property     => $p,
								      value        => $subst{$sid}{$p}
								    });
	$pubChemSubst->submit();

      } else {
	my @syns = @{ $subst{$sid}{synonymns} };
	foreach my $s (@syns) {
	  # skip KEGG_ID, as it is repeated as a synonym in the XML file
	  # print "$sid, synonymn, $s \n" if ($s ne $subst{$sid}{KEGG});
	  if ($s ne $subst{$sid}{KEGG}) {
	    my $pubChemSubst = GUS::Model::bindu::PubChemSubstance->new({ substance_id => $sid,
									  property     => $p,
									  value        => $s
									});
	    $pubChemSubst->submit();
	  }
	}
      }
    }
    $count++;
    $self->undefPointerCache() if $count % 100 == 0;


    $self->log("Inserted entries for $count PubChem Substances.");
  }

}

sub get_ID {
  my ($twig, $ele) = @_;
  my $id = $ele->first_child('PC-ID_id')->text;

  $subst_id = $id;

}

sub get_Syns {
  my ($twig, $ele) = @_;

  my @desc = $ele->find_by_tag_name('PC-Substance_synonyms_E');
  my @synonyms;
  foreach my $des (@desc) {

    push (@synonyms, $des->text);
  }
  $subst{$subst_id}{synonymns} = \@synonyms;
}


sub get_KEGG {
  my ($twig, $ele) = @_;
  my $name = $ele->first_child('PC-DBTracking_name')->text;
  my $id = $ele->first_child('PC-DBTracking_source-id')->text;

  $subst{$subst_id}{$name} = $id;
}


sub get_CID {
  my ($twig, $ele) = @_;
  my @cidArr = $ele->find_by_tag_name('PC-CompoundType_id_cid');

  foreach my $cid (@cidArr) {
  $subst{$subst_id}{CID} = $cid->text;
  }
}

sub undoTables {
  my ($self) = @_;

  return ('bindu.PubChemSubstance');
}


return 1;
