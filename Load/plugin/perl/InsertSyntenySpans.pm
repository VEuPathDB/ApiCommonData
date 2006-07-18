package ApiCommonData::Load::Plugin::InsertSyntenySpans;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::ApiDB::Synteny;

my $argsDeclaration = 
  [
   fileArg({ name           => 'inputFile',
	     descr          => 'tab-delimited synteny span data',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => 'custom',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

   stringArg({name => 'seqTableA',
	      descr => 'where do we find sequence A',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

   stringArg({name => 'seqTableB',
	      descr => 'where do we find sequence B',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

   stringArg({name => 'extDbRlsSpecA',
	      descr => 'where do we find source_id\'s from sequence A',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

   stringArg({name => 'extDbRlsSpecB',
	      descr => 'where do we find source_id\'s from sequence A',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

   stringArg({name => 'syntenyDbRlsSpec',
	      descr => 'what is the external database release info for the synteny data being loaded',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),
  ];

my $purposeBrief = <<PURPOSEBRIEF;
Create entries for genomic synteny spans.
PURPOSEBRIEF
    
my $purpose = <<PLUGIN_PURPOSE;
Create entries for genomic synteny spans.
PLUGIN_PURPOSE

my $tablesAffected = "ApiDB.Synteny";


my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
Simply reexecute the plugin.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
None.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
None.
PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {
  my ($self) = @_;

  my $file = $self->getArg('inputFile');

  my $extDbRlsIdA = $self->getExtDbRlsId($self->getArg('extDbRlsSpecA'));

  my $extDbRlsIdB = $self->getExtDbRlsId($self->getArg('extDbRlsSpecB'));

  my $synDbRlsId = $self->getExtDbRlsId($self->getArg('syntenyDbRlsSpec'));

  open(IN, "<$file") or $self->error("Couldn't open file '$file': $!\n");
  while (<IN>) {
    chomp;
    $self->_handleSyntenySpan($_, $extDbRlsIdA, $extDbRlsIdB, $synDbRlsId);
  }
  close(IN);
}

sub _handleSyntenySpan {
  my ($self, $line, $extDbRlsIdA, $extDbRlsIdB, $synDbRlsId) = @_;

  my ($a_id, $b_id,
      $a_start, $a_len,
      $b_start, $b_len,
      $strand) = split(" ", $line);

  my ($a_pk) = $self->getQueryHandle()->selectrow_array(<<EOSQL, undef, $a_id, $extDbRlsIdA);
  SELECT na_sequence_id
  FROM   @{[$self->getArg('seqTableA')]}
  WHERE  source_id = ?
    AND  external_database_release_id = ?  
EOSQL
  $self->error("Couldn't find primary key for $a_id\n") unless $a_pk;
  
  my ($b_pk) = $self->getQueryHandle()->selectrow_array(<<EOSQL, undef, $b_id, $extDbRlsIdB);
  SELECT na_sequence_id
  FROM   @{[$self->getArg('seqTableB')]}
  WHERE  source_id = ?
    AND  external_database_release_id = ?  
EOSQL
  $self->error("Couldn't find primary key for $b_id\n") unless $b_pk;
  
  my $synteny = GUS::Model::ApiDB::Synteny->new({ a_na_sequence_id => $a_pk,
						  b_na_sequence_id => $b_pk,
						  a_start => $a_start,
						  b_start => $b_start,
						  a_end   => $a_start + $a_len - 1,
						  b_end   => $b_start + $b_len - 1,
						  is_reversed => $strand eq "-",
						  external_database_release_id => $synDbRlsId,
						   });
  $synteny->submit();
  $self->undefPointerCache();
}

sub undoTables {
  return qw(ApiDB.Synteny);
}

1;
