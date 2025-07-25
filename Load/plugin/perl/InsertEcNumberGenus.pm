package ApiCommonData::Load::Plugin::InsertEcNumberGenus;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------
use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::EcNumberGenus;
use GUS::Model::DoTS::AASequenceEnzymeClass;
use GUS::Model::SRes::TaxonName;
use GUS::Model::SRes::EnzymeClass;
use GUS::Model::DoTS::AASequence;

my $argsDeclaration =
  [

  ];

my $purpose = <<PURPOSE;
To load ApiDB.EcNumberGenus table
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
To load ApiDB.EcNumberGenus table
PURPOSE_BRIEF

my $notes = <<NOTES;

NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB::EcNumberGenus
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
sres.taxonname
sres.enzymeclass
dots.aasequenceenzymeclass
dots.aasequence
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
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

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  my $dbh = $self->getDbHandle();

  my $sql = <<EOF;
SELECT DISTINCT tn.name, ec.ec_number 
FROM sres.taxonname tn, dots.aasequenceenzymeclass aaec, dots.aasequence aas, sres.enzymeclass ec
WHERE aaec.aa_sequence_id = aas.aa_sequence_id
AND aas.taxon_id = tn.taxon_id
AND aaec.enzyme_class_id = ec.enzyme_class_id
EOF

  my $stmt = $dbh->prepareAndExecute($sql);
  my $count;
  while ( my ($name, $ecNumber) = $stmt->fetchrow_array() ) {
      my ($genus) = split(/\s+/, $name);    
      my $ecgenus= GUS::Model::ApiDB::EcNumberGenus-> new({EC_NUMBER => $ecNumber,
		                                           genus => $genus
		                                         });
      $ecgenus->submit();

      $count++;
      if ($count % 1000 == 0) {
          $self->log("Inserted $count Entries into EcNumberGenus");
          $self->undefPointerCache();
      }
  } 
  return("Loaded $count ApiDB::EcNumberGenus");
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.EcNumberGenus',
	 );
}

1;
