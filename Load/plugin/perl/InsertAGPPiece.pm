package ApiCommonData::Load::Plugin::InsertAGPPiece;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::ApiDB::AGPPiece;

use Bio::PrimarySeq;
use Bio::Tools::SeqStats;
use GUS::Supported::Util;

sub getArgsDeclaration {
my $argsDeclaration  =
[

fileArg({name => 'agpFile',
         descr => 'file of virtual seq being assembled from parts in agp format',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format=>'Text'
        }),
];

return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

my $description = <<NOTES;
NOTES

my $purpose = <<PURPOSE;
Load AGPPiece Table
PURPOSE

my $purposeBrief = <<PURPOSEBRIEF;
Load AGPPiece Table
PURPOSEBRIEF

my $syntax = <<SYNTAX;
SYNTAX

my $notes = <<NOTES;
The file:
Tab delimited
cols are 1-object,2-object_beginning,3-object_end,4-part_number,5-component_type(N=gap w/known length,U-gap w/o known length,W=wgs contig,P=predraft,O=other seq,G=whole genome finishing),6-component_id if 5 not N(U) else gap_length,7-component_beg if 5 not N(U) else gap_type (fragment,etc),8-component_end if 5 not N(U) else yes/no gap is beetween adjacent lines,9-orientation(+=forward,-=reverse,0=unknown, na=not applicable) if 5 not N(U) else not used
All object and component distances should be sequential and non-overlapping, all beg <= end
1-based (first base =1 and not 0)
make sure there are not carriage returns in the file, ^M, if so run dos2unix
NOTES

my $tablesAffected = <<AFFECT;
Apidb.AGPPiece
AFFECT

my $tablesDependedOn = <<TABD;
TABD

my $howToRestart = <<RESTART;
no restart
RESTART

my $failureCases = <<FAIL;
FAIL

my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};

return ($documentation);

}


sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = {requiredDbVersion => 4.0,
		       cvsRevision => '$Revision$',
		       cvsTag => '$Name$',
		       name => ref($self),
		       revisionNotes => '',
		       argsDeclaration => $args,
		       documentation => $documentation
		      };

  $self->initialize($configuration);

  return $self;
}


sub run {
  my $self = shift;

  my $file = $self->getArg('agpFile');

  my $results = $self->processFile($file);

  my $stmt = "$results ApiDB.AGPPiece rows inserted\n";

  return $stmt;
}


sub processFile {
  my ($self, $file) = @_;

  open(FILE, "<$file") or die "Couldn't open file '$file':\n";

  my $count;

  while (<FILE>) {
    chomp;
    next if ($_ =~ /^#/ || $_ =~ /^\s*$/);

    my @arr = split(/\t/, $_);

    my $sourceId = $arr[0];

    # By default, components with unknown orientation (?, 0 or na) are treated as if they had + orientation.
    $arr[8] =~ s/[na0\?]/+/g unless $arr[4] =~ /[NU]/;

    my $startMin = $arr[1];
    my $endMax = $arr[2];
    my $partNumber = $arr[3];
    my $partType = $arr[4];

    my ($gapLength, $gapType, $linkageEvidence, $pieceId, $pieceStart, $pieceEnd, $orientation, $linkage, $isReversed, $hasLinkage);

    if ($arr[4] =~ /[NU]/) {
      $gapLength = $arr[5];
      $gapType = $arr[6];
      $linkage = $arr[7];
      $linkageEvidence = $arr[8];

      $hasLinkage = $linkage eq 'yes' ? 1 : 0;
    }
    else {
      $pieceId = $arr[5];
      $pieceStart = $arr[6];
      $pieceEnd = $arr[7];
      $orientation = $arr[8];

      $isReversed = $orientation eq '+' ? 0 : 1;

    }



    my $agpPiece = GUS::Model::ApiDB::AGPPiece->new({source_id => $sourceId,
                                                     start_min => $startMin,
                                                     end_max => $endMax,
                                                     part_number => $partNumber,
                                                     part_type => $partType,
                                                     piece_id => $pieceId,
                                                     piece_start => $pieceStart,
                                                     piece_end => $pieceEnd,
                                                     is_reversed => $isReversed,
                                                     gap_length => $gapLength,
                                                     gap_type => $gapType,
                                                     has_linkage => $hasLinkage,
                                                     linkage_evidence => $linkageEvidence,
                                                    });

    $agpPiece->submit();
    $agpPiece->undefPointerCache();

    $count++;
  }
  close (FILE);

  return $count;
}

sub undoTables {
  return ("ApiDB.AGPPiece")

}


1;

