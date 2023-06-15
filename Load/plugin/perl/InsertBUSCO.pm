package ApiCommonData::Load::Plugin::InsertBUSCO;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::Busco;


# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

my $argsDeclaration  =
    [

     stringArg({name           => 'extDbRlsSpec',
                descr          => 'External Database Spec for this study',
                reqd           => 1,
                constraintFunc => undef,
                isList         => 0, }),

     stringArg({ name => 'orgAbbrev',
                 descr => 'eg tgonME49',
                 constraintFunc=> undef,
                 reqd  => 1,
                 isList => 0,
               }),

     fileArg({ name => 'genomeFile',
               descr => 'busco short summary file',
               constraintFunc=> undef,
               format         => '',
               reqd  => 1,
               isList => 0,
               mustExist => 1,
             }),

     fileArg({ name => 'proteinFile',
               descr => 'optional busco short summary file',
               constraintFunc=> undef,
               format         => '',
               reqd  => 0,
               isList => 0,
               mustExist => 0,
             }),

    ];


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

  my $description = <<DESCR;
Load BUSCO scores for an organism
 Complete BUSCOs (C)
 Complete and single-copy BUSCOs (S)
 Complete and duplicated BUSCOs (D)
 Fragmented BUSCOs (F)
 Missing BUSCOs (M)
DESCR

  my $purpose = <<PURPOSE;
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Load BUSCO scores for an organism
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.BUSCO
AFFECT

  my $tablesDependedOn = <<TABD;
TABD

  my $howToRestart = <<RESTART;
No restart provided. Undo and re-run.
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


sub new {
  my ($class) = @_;
  my $self = {};
  bless($self, $class);

  $self->initialize ({ requiredDbVersion => 4.0,
			cvsRevision => '$Revision$',
			name => ref($self),
			argsDeclaration => $argsDeclaration,
			documentation => $documentation
		      });

  return $self;
}

sub run {
  my ($self) = @_;

  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);

  my $organismAbbrev = $self->getArg('orgAbbrev');

  my ($orgId) = $self->sqlAsArray( Sql => "select organism_id from apidb.organism where abbrev = '$organismAbbrev'" );

  $self->parseAndLoadBuscoFile($self->getArg('genomeFile'), 'genome', $orgId, $extDbRlsId);


  my $msg = "Loaded BUSCO summary for $organismAbbrev:  genome";

  my $proteinFile = $self->getArg('proteinFile');
  if(-e $proteinFile) {
    $self->parseAndLoadBuscoFile($proteinFile, 'protein', $orgId, $extDbRlsId);
    $msg = $msg . " and protein";
  }

  return $msg;
}



sub parseAndLoadBuscoFile {
  my ($self, $file, $type, $organismId, $extDbRlsId) =  @_;

  open(FILE, '<', $file) or die "Could not open file $file for reading: $!";

  my %hash = ("organism_id" => $organismId,
              "sequence_type" => $type,
              "external_database_release_id" => $extDbRlsId
      );

  while (<FILE>) {
    chomp;
    if (/\s+(\d+)\s+.+\(([CSDFM])\)/) {
      my $buscoField = "${2}_score";

      $hash{$buscoField} = $1;
    }
  }

  my $busco = GUS::Model::ApiDB::Busco->new(\%hash);
  $busco->submit();
}


sub undoTables {
  return qw(ApiDB.Busco
           );
}
