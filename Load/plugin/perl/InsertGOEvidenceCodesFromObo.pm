#######################################################################
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | fixed
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
##                 InsertGOEvidenceCodesFromObo.pm
##
## Creates a new entry in table SRes.GOEvidenceCode to represent
## a new GO evidence code in GUS
## $Id$
##
#######################################################################
 
package ApiCommonData::Load::Plugin::InsertGOEvidenceCodesFromObo;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::SRes::OntologyTerm;

use Text::Balanced qw(extract_quotelike);

my @missingCodes = qw(RCA);

my $argsDeclaration = 
  [
   fileArg({ name           => 'oboFile',
	     descr          => 'The Evidence Code OBO file',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => 'OBO format',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

     stringArg({name => 'extDbRlsSpec',
       descr => 'Sres externaldatabase name and version',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

  ];

my $purposeBrief = <<PURPOSEBRIEF;
Creates new entries in table SRes.OntologyTerm to represent GO evidence codes in GUS.
PURPOSEBRIEF
    
my $purpose = <<PLUGIN_PURPOSE;
Creates new entries in table SRes.OntologyTerm to represent GO evidence codes in GUS.
PLUGIN_PURPOSE

my $tablesAffected = 
	[['SRes.OntologyTerm', 'The entry representing the new evidence code is created here']];

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

    $self->initialize({requiredDbVersion => 4.0,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

#######################################################################
# Main Routine
#######################################################################

sub run {
  my ($self) = @_;

  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);

  my $oboFile = $self->getArg('oboFile');
  open(OBO, "<$oboFile") or $self->error("Couldn't open '$oboFile': $!\n");

  $self->{_count} = 0;

  my %seen;

  $self->_parseTerms(\*OBO, \%seen, $extDbRlsId);

  close(OBO);
  
  for my $missing (grep { !$seen{$_} } @missingCodes) {
    my $evidenceCode = GUS::Model::SRes::OntologyTerm->new({name => $missing, source_id => $missing, external_database_release_id => $extDbRlsId});
    $evidenceCode->submit();
  }

  warn "Done; inserted $self->{_count} codes\n";
}

sub _parseTerms {
  my ($self, $fh, $seen, $extDbRlsId) = @_;

  my $block = "";
  while (<$fh>) {
    if (m/^\[ ([^\]]+) \]/x) {
      $self->_processBlock($block, $seen, $extDbRlsId)
	if $block =~ m/\A\[Term\]/; # the very first block will be the
                                    # header, and so should not get
                                    # processed; also, some blocks may
                                    # be [Typedef] blocks
      $self->undefPointerCache();
      $block = "";
    }
    $block .= $_;
  }

  $self->_processBlock($block, $seen, $extDbRlsId)
    if $block =~ m/\A\[Term\]/; # the very first block will be the
                                # header, and so should not get
                                # processed; also, some blocks may be
                                # [Typedef] blocks
}

sub _processBlock {
  my ($self, $block, $seen, $extDbRlsId) = @_;

  my @evidCodes = keys (%$seen);

  my ($name, $def) = $self->_parseBlock($block);

  # if evidence code seen already, ignore it repeat occurrence.
  return  if ($name &&  (grep {$_ eq $name} @evidCodes));

  return unless ($name && $name =~ m/^\w+$/);

  my $evidenceCode = GUS::Model::SRes::OntologyTerm->new({name => $name, definition => $def, source_id => $name, external_database_release_id => $extDbRlsId});
  $evidenceCode->submit();

  $seen->{$name}++;
  $self->{_count}++;
}

sub _parseBlock {
  my ($self, $block) = @_;

   $block =~ s/synonym:\s"<new synonym>"\sRELATED \[\]//;
#  my ($name) = $block =~ m/^exact_synonym:\s+(.*)/ms;
  my ($name) = $block =~ m/^synonym:\s+([ ":?][A-Z].*)/ms ;

  if ($name) {
    ($name) = extract_quotelike($name);
    $name =~ s/\A"|"\Z//msg;
    $name =~ s/ \\ ([
                      \: \, \" \\
                      \( \) \[ \] \{ \}
                      \n
                    ])
              /$1/xg;
  }

  my ($def) = $block =~ m/^def:\s+(.*)/ms;
  if ($def) {
    ($def) = extract_quotelike($def);
    $def =~ s/\A"|"\Z//msg;
    $def =~ s/ \\ ([
                     \: \, \" \\
                     \( \) \[ \] \{ \}
                     \n
                   ])
             /$1/xg;
  }

  return ($name, $def);
}

sub undoTables {
  my ($self) = @_;

  return ('SRes.OntologyTerm');
}

1;
