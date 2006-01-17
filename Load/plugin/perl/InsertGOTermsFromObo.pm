package ApiComplexa::DataLoad::Plugin::InsertGOTermsFromObo;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

use GUS::Model::SRes::GOTerm;
use GUS::Model::SRes::GORelationship;
use GUS::Model::SRes::GORelationshipType;
use GUS::Model::SRes::GOSynonym;

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
	       descr          => 'external database release version for the GO ontology',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0,
	     }),
  ];

my $purpose = <<PURPOSE;
Insert all terms from a Gene Ontology OBO file.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert all terms from a Gene Ontology OBO file.
PURPOSE_BRIEF

my $notes = <<NOTES;
MINIMUM_LEVEL, MAXIMUM_LEVEL, and NUMBER_OF_LEVELS fields are
currently left at a default of 1; i.e. with respect to the schema,
this plugin is (marginally) incomplete.
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
SRes.GOTerme, SRes.GORelationship, SRes.GORelationshipType, SRes.GOSynonym
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
None.
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
Just reexecute the plugin; all existing terms, synonyms and
relationships (defined by the specified External Database Release)
will be removed.
RESTART

my $failureCases = <<FAIL_CASES;
If GO associations have been entered for pre-existing terms, this
plugin won't be able to delete the terms (integrity violation), and
the plugin will die; you'll need to first delete the associations
before reexecuting this plugin.
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

  my $oboFile = $self->getArg('oboFile');
  open(OBO, "<$oboFile") or $self->error("Couldn't open '$oboFile': $!\n");

  my $cvsRevision = $self->_parseCvsRevision(\*OBO);

  my $extDbRlsName = $self->getArg('extDbRlsName');
  my $extDbRlsVer = $self->getArg('extDbRlsVer');

  $self->error("extDbRlsVer $extDbRlsVer does not match CVS revision $cvsRevision\n")
    unless $cvsRevision eq $extDbRlsVer;

  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsName, $extDbRlsVer);

  $self->_deleteTermsAndRelationships($extDbRlsId);

  $self->_parseTerms(\*OBO, $extDbRlsId);

  close(OBO);

  $self->_calcTransitiveClosure($extDbRlsId);
}

sub _parseTerms {

  my ($self, $fh, $extDbRlsId) = @_;

  my $block = "";
  while (<$fh>) {
    if (m/^\[ ([^\]]+) \]/x) {
      $self->_processBlock($block, $extDbRlsId)
	if $block =~ m/\A\[Term\]/; # the very first block will be the
                                    # header, and so should not get
                                    # processed; also, some blocks may
                                    # be [Typedef] blocks
      $self->undefPointerCache();
      $block = "";
    }
    $block .= $_;
  }

  $self->_processBlock($block, $extDbRlsId)
    if $block =~ m/\A\[Term\]/; # the very first block will be the
                                # header, and so should not get
                                # processed; also, some blocks may be
                                # [Typedef] blocks
}

sub _processBlock {

  my ($self, $block, $extDbRlsId) = @_;

  $self->{_count}++;

  my ($id, $name, $def, $comment,
      $synonyms, $relationships,
      $isObsolete) = $self->_parseBlock($block);

  my $goTerm = $self->_retrieveGOTerm($id, $name, $def, $comment,
				      $synonyms, $isObsolete,
				      $extDbRlsId);

  for my $relationship (@$relationships) {
    $self->_processRelationship($goTerm, $relationship, $extDbRlsId);
  }

  warn "Processed $self->{_count} terms\n" unless $self->{_count} % 500;

}

sub _processRelationship {

  my ($self, $childTerm, $relationship, $extDbRlsId) = @_;

  my ($type, $parentId) = @$relationship;

  my $parentTerm = $self->_retrieveGOTerm($parentId, undef, undef, undef,
					  undef, undef, $extDbRlsId);

  my $goRelationshipType =
    $self->{_goRelationshipTypeCache}->{$type} ||= do {
      my $goType = GUS::Model::SRes::GORelationshipType->new({ name => $type });
      unless ($goType->retrieveFromDB()) {
	$goType->submit();
      }
      $goType;
    };
  

  my $goRelationship =
    GUS::Model::SRes::GORelationship->new({
      parent_term_id          => $parentTerm->getGoTermId(),
      child_term_id           => $childTerm->getGoTermId(),
      go_relationship_type_id => $goRelationshipType->getGoRelationshipTypeId(),
    });

  $goRelationship->submit();
}

sub _retrieveGOTerm {

  my ($self, $id, $name, $def, $comment,
      $synonyms, $isObsolete, $extDbRlsId) = @_;

  my $goTerm = GUS::Model::SRes::GOTerm->new({
    go_id                        => $id,
    source_id                    => $id,
    external_database_release_id => $extDbRlsId,
  });

  unless ($goTerm->retrieveFromDB()) {
    $goTerm->setName("Not yet available");
    $goTerm->setMinimumLevel(1);
    $goTerm->setMaximumLevel(1);
    $goTerm->setNumberOfLevels(1);
  }
  
  # some of these may not actually yet be available, if we've been
  # called while building a relationship:

  $goTerm->setName($name) if length($name);
  $goTerm->setDefinition($def) if length($def);
  $goTerm->setCommentString($comment) if length($comment);
  $goTerm->setIsObsolete(1) if ($isObsolete && $isObsolete eq "true");

  $self->_setGOTermSynonyms($goTerm, $synonyms, $extDbRlsId) if $synonyms;

  $goTerm->submit();

  return $goTerm;
}

sub _setGOTermSynonyms {

  my ($self, $goTerm, $synonyms, $extDbRlsId) = @_;

  for my $synonym (@$synonyms) {
    my ($type, $text) = @$synonym;
    my $goSynonym = GUS::Model::SRes::GOSynonym->new({
      text                         => $text,
      external_database_release_id => $extDbRlsId,
    });
    $goTerm->addChild($goSynonym);
  }
}


sub _parseBlock {

  my ($self, $block) = @_;

  my ($id) = $block =~ m/^id:\s+(GO:\d+)/m;
  my ($name) = $block =~ m/^name:\s+(.*)/m;
  my ($comment) = $block =~ m/^comment:\s+(.*)/m;
  my ($def) = $block =~ m/^def:\s+(.*)/ms;
  ($def) = extract_quotelike($def);
  $def =~ s/\A"|"\Z//msg;

  # remove OBO-format special character escaping:
  $comment =~ s/ \\ ([
                       \: \, \" \\
                       \( \) \[ \] \{ \}
                       \n
                     ])
               /$1/xg;

  $def =~ s/ \\ ([
                   \: \, \" \\
                   \( \) \[ \] \{ \}
                   \n
                 ])
           /$1/xg;


  my @synonyms;
  while ($block =~ m/^((?:\S+_)?synonym):\s+\"([^\"]*)\"/mg) {
    push @synonyms, [$1, $2];
  }

  while ($block =~ m/^alt_id:\s+(GO:\d+)/mg) {
    push @synonyms, ["alt_id", $1];
  }

  my @relationships;
  while ($block =~ m/^is_a:\s+(GO:\d+)/mg) {
    push @relationships, ["is_a", $1];
  }

  while ($block =~ m/^relationship:\s+part_of\s+(GO:\d+)/mg) {
    push @relationships, ["part_of", $1];
  }

  my ($isObsolete) = $block =~ m/^is_obsolete:\s+(\S+)/m;

  return ($id, $name, $def, $comment, \@synonyms, \@relationships, $isObsolete)
}

sub _calcTransitiveClosure {

  my ($self, $extDbRlsId) = @_;

  my $dbh = $self->getQueryHandle();

  $dbh->do("DROP TABLE go_tc");
  $dbh->do(<<EOSQL);
    CREATE TABLE go_tc (
      child_id NUMBER(10,0) NOT NULL,
      parent_id NUMBER(10,0) NOT NULL,
      depth NUMBER(3,0) NOT NULL,
      PRIMARY KEY (child_id, parent_id)
    )
EOSQL

  $dbh->do(<<EOSQL);
    INSERT INTO go_tc (child_id, parent_id, depth)
    SELECT go_term_id,
           go_term_id,
           0
    FROM   SRes.GOTerm
    WHERE  external_database_release_id = $extDbRlsId
EOSQL

  $dbh->do(<<EOSQL);

    INSERT INTO go_tc (child_id, parent_id, depth)
    SELECT child_term_id,
           parent_term_id,
           1
    FROM   SRes.GORelationship gr,
           SRes.GOTerm gtc,
           SRes.GOTerm gtp
    WHERE  gtc.go_term_id = gr.child_term_id
      AND  gtp.go_term_id = gr.parent_term_id
      AND  gtc.external_database_release_id = $extDbRlsId
      AND  gtp.external_database_release_id = $extDbRlsId
EOSQL

  my $select = $dbh->prepare(<<EOSQL);
    SELECT DISTINCT tc1.child_id,
                    tc2.parent_id,
                    tc1.depth + 1
    FROM   go_tc tc1,
           go_tc tc2
    WHERE  tc1.parent_id = tc2.child_id
      AND  tc2.depth = 1
      AND  tc1.depth = ?
      AND  NOT EXISTS (
             SELECT 'x'
             FROM go_tc tc3
             WHERE tc3.child_id = tc1.child_id
               AND tc3.parent_id = tc2.parent_id
           )
EOSQL

  my $insert = $dbh->prepare(<<EOSQL);
    INSERT INTO go_tc (child_id, parent_id, depth)
               VALUES (    ?,      ?,      ?)
EOSQL

  my ($oldsize) =
    $dbh->selectrow_array("SELECT COUNT(*) FROM go_tc");

  my ($num) = $dbh->selectrow_array("SELECT COUNT(*) FROM SRes.GOTerm WHERE external_database_release_id = $extDbRlsId");
  warn "GO Terms: $num\n";
  ($num) = $dbh->selectrow_array("SELECT COUNT(*) FROM SRes.GORelationship");
  warn "Relationships: $num\n";
  warn "starting size: $oldsize\n";

  my $newsize = 0;
  my $len = 1;

  while (!$newsize || $oldsize < $newsize) {
    $oldsize = $newsize || $oldsize;
    $newsize = $oldsize;
    $select->execute($len++);
    while(my @data = $select->fetchrow_array) {
      $insert->execute(@data);
      $newsize++;
    }
    warn "Transitive closure (length $len): added @{[$newsize - $oldsize]} edges\n";
  }

  my $closureRelationshipType =
      GUS::Model::SRes::GORelationshipType->new({ name => 'closure' });

  unless ($closureRelationshipType->retrieveFromDB()) {
    $closureRelationshipType->submit();
  }

  my $closureRelationshipTypeId = $closureRelationshipType->getGoRelationshipTypeId();

  my $sth = $dbh->prepare("SELECT child_id, parent_id, depth FROM go_tc");
  $sth->execute();


  while (my ($child_id, $parent_id, $depth) = $sth->fetchrow_array()) {
    $self->undefPointerCache();
    my $goRelationship = GUS::Model::SRes::GORelationship->new({
      parent_term_id          => $parent_id,
      child_term_id           => $child_id,
      go_relationship_type_id => $closureRelationshipTypeId,
    });
    $goRelationship->submit();
  }
  
  $dbh->do("DROP TABLE go_tc");
}

sub _deleteTermsAndRelationships {

  my ($self, $extDbRlsId) = @_;

  my $dbh = $self->getQueryHandle();

  my $goTerms = $dbh->prepare(<<EOSQL);

  SELECT go_term_id
  FROM   SRes.GOTerm
  WHERE  external_database_release_id = ?

EOSQL

  my $deleteRelationships = $dbh->prepare(<<EOSQL);

  DELETE
  FROM   SRes.GORelationship
  WHERE  parent_term_id = ?
     OR  child_term_id = ?

EOSQL

  my $deleteSynonyms = $dbh->prepare(<<EOSQL);

  DELETE
  FROM   SRes.GOSynonym
  WHERE  go_term_id = ?

EOSQL

  my $deleteTerm = $dbh->prepare(<<EOSQL);

  DELETE
  FROM   SRes.GOTerm
  WHERE  go_term_id = ?

EOSQL
  
  $goTerms->execute($extDbRlsId);
  while (my ($goTermId) = $goTerms->fetchrow_array()) {
    $deleteRelationships->execute($goTermId, $goTermId);
    $deleteSynonyms->execute($goTermId);
    $deleteTerm->execute($goTermId);
  }
}

sub _parseCvsRevision {

  my ($self, $fh) = @_;

  my $cvsRevision;
  while (<$fh>) {
    if (m/cvs version\: \$Revision: (\S+)/) {
      $cvsRevision = $1;
      last;
    }
  }

  unless (length $cvsRevision) {
    $self->error("Couldn't parse out the CVS version!\n");
  }

  return $cvsRevision;
}

sub undoTables {
  my ($self) = @_;

  return ('SRes.GORelationship',
	  'SRes.GORelationshipType',
	  'SRes.GOSynonym',
	  'SRes.GOTerm',
	 );
}
