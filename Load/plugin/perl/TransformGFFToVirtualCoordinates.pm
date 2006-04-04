package ApiCommonData::Load::Plugin::TransformGFFToVirtualCoordinates;

use strict;
use base qw(GUS::PluginMgr::Plugin);

use GUS::PluginMgr::Plugin;
use Bio::Tools::GFF;

my $argsDeclaration =
  [
   fileArg({ name           => 'inputFile',
	     descr          => 'The input GFF file',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => 'GFF format',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

   fileArg({ name           => 'outputFile',
	     descr          => 'The output GFF file',
	     reqd           => 1,
	     mustExist      => 0,
	     format         => 'GFF format',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

   stringArg({ name           => 'extDbRlsSpec',
	       descr          => 'the ExternalDatabaseRelease specification of the sequences referred to by the input GFF',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0,
	     }),

   stringArg({ name           => 'virtualExtDbRlsSpec',
	       descr          => 'the ExternalDatabaseRelease specification of the virutal sequences to which the output GFF will refer',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0,
	     }),

   stringArg({ name           => 'gffVersion',
	       descr          => 'version of GFF being read and written',
	       reqd           => 0,
               default        => 2.5,
	       constraintFunc => undef,
	       isList         => 0,
	     }),

   stringArg({ name           => 'groupTag',
	       descr          => 'For GFF versions < 3, one must specify which of the tags found in the group column is the group tag',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0,
	     }),
  ];

my $purpose = <<PURPOSE;
Convert an input GFF file/stream using real sequence coordinates to
the equivalent virtual sequence coordinates (as defined by a virtual
sequence mapping already stored in GUS).
PURPOSE


my $purposeBrief = <<PURPOSE_BRIEF;
Convert real sequence coordinates to virtual coordinates in GFF.
PURPOSE_BRIEF

my $notes = <<NOTES;
When input sequences do not participate in a virtual sequence, no
mapping is performed.  For proper operation, this plugin also requires
that NASequence entries have correct (non-NULL) 'length' attributes.
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
None.
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
DoTS.VirtualSequence, DoTS.SequencePiece
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
No restart necessary; this plugin does not save any information to the
database.
RESTART

my $failureCases = <<FAIL_CASES;
None known.
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

  $self->initialize({ requiredDbVersion => 3.5,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation
		    });

  return $self;
}

sub run {
  my ($self) = @_;

  my $inputFile = $self->getArg("inputFile");
  my $outputFile = $self->getArg("outputFile");

  my $groupTag = $self->getArg("groupTag");
  my $gffVersion = $self->getArg("gffVersion");

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg("extDbRlsSpec"));
  my $virtualExtDbRlsId = $self->getExtDbRlsId($self->getArg("virtualExtDbRlsSpec"));

  my $gffIn  = Bio::Tools::GFF->new(-file => $inputFile,
				    -gff_version => $gffVersion,
				    -preferred_groups => [$groupTag]
				   );

  my $gffOut = Bio::Tools::GFF->new(-file => ">$outputFile",
				    -gff_version => $gffVersion,
				    -preferred_groups => [$groupTag]
				   );

  my $dbh = $self->getQueryHandle(); 
  
  my $map = ApiCommonData::Load::VirtualSequenceMap->new({ extDbRlsId  => $extDbRlsId,
							   virtDbRlsId => $virtualExtDbRlsId,
							   dbh         => $dbh,
							 });

  while (my $feature = $gffIn->next_feature) {

    my $seqId = $feature->location()->seq_id();
    my $result = $map->map($feature->location());

    if ($result) {

      # calculate new location in virtual coordinates:
      my $virtualLocation = $result->match();

      unless ($virtualLocation) {
	die <<EODIE;
Could not map feature to virtual coordinates:
@{[$feature->gff_string()]}

Usually, this happens because the specified input coordinates are
outside the known boundaries of the sequence.
EODIE
	next;
      }

      # change the feature's location to the virtual coordinate location
      $feature->location($virtualLocation);

      # also change the feature's reference sequence to the virtual sequence
      $feature->seq_id($virtualLocation->seq_id());

      # if the feature has CodingStart/CodingEnd attributes, these
      # also need to be mapped:
      if ($feature->has_tag('CodingStart')) {
	my ($codingStart) = $feature->each_tag_value('CodingStart');
	$result = $map->map(Bio::Location::Simple->new(-seq_id => $seqId,
						       -start  => $codingStart,
						       -end    => $codingStart)
			   );
	if ($result) {
	  $feature->remove_tag('CodingStart');
	  $feature->add_tag_value('CodingStart' => $result->match()->start());
	}
      }
      if ($feature->has_tag('CodingEnd')) {
	my ($codingEnd) = $feature->each_tag_value('CodingEnd');
	$result = $map->map(Bio::Location::Simple->new(-seq_id => $seqId,
						       -start  => $codingEnd,
						       -end    => $codingEnd)
			   );
	if ($result) {
	  $feature->remove_tag('CodingEnd');
	  $feature->add_tag_value('CodingEnd' => $result->match()->end());
	}
      }

      # then alter Target coordinate direction, if present, because
      # new absolute coordinates may not be in the same strand as the
      # original relative coordinates:
      if ($feature->has_tag('Target')) {
	my ($target) = $feature->each_tag_value('Target');
	my ($begin, $end) = $target =~ m/(\d+)\s+(\d+)\s*$/o;
	if ( $begin > $end ) {
	  ($begin, $end) = ($end, $begin);
	  # flip strandedness on feature:
	  $feature->strand(- $feature->strand);
	  $target =~ s/\d+(\s+)\d+(\s*$)/$begin$1$end$2/;
	  $feature->remove_tag('Target');
	  $feature->add_tag_value(Target => $target);
	}
      }
    }

    $gffOut->write_feature($feature);
  }

my $msg = "Transformation complete.\n";

return $msg;

}
