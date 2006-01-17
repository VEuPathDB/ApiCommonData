#!/usr/bin/perl

# -------------------------------------------------------------
# LoadPfam.pm
#
# Load a release of Pfam into GUS.  Assumes that the 
# ExternalDatabase table has already been populated with
# entries for the databases to which Pfam links (see below
# for the full list.)
# 
# Most recently tested on 17 March 2003 against Pfam Release 8.0,
# specifically the following file:
#  <ftp://ftp.sanger.ac.uk/pub/databases/Pfam/Pfam-A.full.gz>
#
# This is the GUS3.0 version converted from ImportPfam in GUSdev. The code has
# been modified to take into account the extra table;
#
#   Was: DbRef -> ExternalDatabase
#   Now: SRes.DBRef -> SRes::ExternalDatabaseRelease -> SRes::ExternalDatabase
#
# Because of this it uses the lastest ExternalDatabaseRelease (by date).
#
# DbRefPfamEntrys are created for all DbRef types, not just Medline
# ones as ImportPfam did. I think this was a bug in the old version.
#
#
# Created: Mon Mar 17 13:39:56 GMT 2003
#
# Author:  Paul Mooney (Original by Jonathan Crabtree)
# Edited:  E. Robinson (allow autoloading of pfam divs) 
#
# $Revision$ $Date$ $Author$
# -------------------------------------------------------------


package GUS::Common::Plugin::LoadPfam;
@ISA = qw(GUS::PluginMgr::Plugin); #defines what is inherited

use strict;

use DBI;

use GUS::Model::DoTS::PfamEntry;
use GUS::Model::DoTS::DbRefPfamEntry;
use GUS::Model::SRes::DbRef;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;


# ----------------------------------------------------------
# GUSApplication
# ----------------------------------------------------------

sub new {
    my $class = shift;
    my $self  = {};
    bless($self,$class);

    my $usage   = 'Import a release of Pfam into GUS.';
    my $easycsp =
        [{
             o => 'release',
             r => 1,
             t => 'string',
             h => ('Pfam release number.'),
         },
         {
             o => 'flat_file',
             r => 1,
             t => 'string',
             h => ("Flat file containing the release of Pfam to load.  Expects\n" .
                   "\t\t\tthe file containing the annotation and full alignments in Pfam\n" .
                   "\t\t\tformat of all Pfam-A families (called \"Pfam-A.full\" in release 5.2)\n" .
                   "\t\t\tThe specified file may be in gzip (.gz) or compressed (.Z) format."),
         },
         {
             o => 'load_divs',
             r => 0,
             t => 'boolean',
             h => ("Flag to indicate to plugins whether to auto-load divs.\n"),
         },
         {
             o => 'parse_only',
             h => ("Parse the Pfam input file without submitting any information into the \n" .
                   "\t\t\tdatabase; can be used to validate the parser against a new Pfam \n" .
                   "\t\t\trelease before actually trying to load the data.\n"),
             t => 'boolean',
         }];

    $self->initialize({requiredDbVersion => {},
                       cvsRevision    => '$Revision$', # cvs fills this in!
                       cvsTag         => '$Name$', # cvs fills this in!
                       name           => ref($self),
                       revisionNotes  => 'make consistent with GUS 3.0',
                       easyCspOptions => $easycsp,
                       usage          => $usage
                       });

    return $self;
}

# Hash for mapping Pfam name to GUS name for a DB
#
sub setupNameHash {
    my ($self) = @_;

  if ($self->getArg('load_divs')) {
    $self->{'nameForDB'} = {'EXPERT'          => 'expert',
                            'MIM'             => 'mim',
                            'PFAMB'           => 'pfamb',
                            'PRINTS'          => 'prints',
                            'PROSITE'         => 'prosite',
                            'PROSITE_PROFILE' => 'prosite',
                            'SCOP'            => 'scop',
                            'PDB'             => 'pdb',
                            'SMART'           => 'smart',
                            'URL'             => 'url',
                            'INTERPRO'        => 'interpro',
                            'MEROPS'          => 'merops',
                            'HOMSTRAD'        => 'homstrad',
                            'CAZY'            => 'cazy',
                            'LOAD'            => 'load',
                        };
  }
  else {
    $self->{'nameForDB'} = {'EXPERT'          => 'Pfam expert',
                            'MIM'             => 'mim',
                            'PFAMB'           => 'Pfam-B',
                            'PRINTS'          => 'PRINTS',
                            'PROSITE'         => 'prosite',
                            'PROSITE_PROFILE' => 'prosite',
                            'SCOP'            => 'SCOP',
                            'PDB'             => 'pdb',
                            'SMART'           => 'SMART',
                            'URL'             => 'URL',
                            'INTERPRO'        => 'INTERPRO',
                            'MEROPS'          => 'MEROPS',
                            'HOMSTRAD'        => 'HOMSTRAD',
                            'CAZY'            => 'CAZy',
                            'LOAD'            => 'LOAD',
                        };
  }
}


sub createDBs {
 my ($self, $flatfile, $openCmd) = @_;
 my $pfamVer = $self->getArgs->{'release'};
     
 my %dBHash = {};
   %dBHash->{'MEDLINE'} = 'medline';
    #=GF DR   PROSITE; PDOC00633;
    #=GF DR   SMART; 14_3_3;
    #=GF DR   INTERPRO; IPR000308;
    open(PFAM, $openCmd);
      while(<PFAM>) {
        if (/^#=GF DR\s+([A-Z]+)/) {
           %dBHash->{$1} = lc($1);
        }
      }

#check that all DBs exist and have releases, otherwise, create them.
foreach my $feat (keys %dBHash) {
 unless (%dBHash->{$feat} eq '') {
   my $dbEntry = GUS::Model::SRes::ExternalDatabase->new();
      $dbEntry->setName($feat);
      $dbEntry->setLowercaseName(%dBHash->{$feat});
        unless ( $dbEntry->retrieveFromDB() ) {
                   $dbEntry->submit();
                }
        my $dbId = $dbEntry->getId();

   my $dbRlsEntry = GUS::Model::SRes::ExternalDatabaseRelease->new();
      $dbRlsEntry->setExternalDatabaseId($dbId);
        unless ( $dbRlsEntry->retrieveFromDB() ) {
                    $dbRlsEntry->setVersion('unk.');
                    $dbRlsEntry->setDescription("External DB entry in PFam $pfamVer");
                    $dbRlsEntry->submit();
                 }
 }
}
}

# Check command line args and open the flat_file for parsing, which can be in
# .gz format. Create PfamEntrys and link to the correct DbRef (create as need
# be) by adding DbRefPfamEntry for each.
#
# Finish by showing summary of how many records have been created.
#
sub run {
    my $self      = shift;
    my $flatFile  = $self->getArgs->{'flat_file'};
    my $release   = $self->getArgs->{'release'};

    die "No release specified"   if (not defined($release));
    die "No flat file specified" if (not defined($flatFile));

    print STDERR "ImportPfam: COMMIT ", $self->getArgs->{'commit'} ? "****ON****" : "OFF", "\n";
    print STDERR "ImportPfam: reading Pfam release $release from $flatFile\n";

    die "Unable to read $flatFile" if (not -r $flatFile);

    # Uncompress Pfam file on the fly if necessary, using gunzip
    # NOTE;
    # This should be specified in the $GUS_HOME/config/GUS-PluginMgr.prop
    #
    my $openCmd =
        ($flatFile =~ /\.(gz|Z)$/) ? "gunzip -c $flatFile |" : $flatFile;

    #optional load of Pfam Divisions into SRes.externaldatabaserelease
    if ($self->getArgs->{'load_divs'}) {
       $self->log('loading divs');
       $self->createDBs($flatFile, $openCmd) ;
    }


    # Setup hash mapping 
    #
    $self->setupNameHash();

    # Read ExternalDatabase table into memory
    # 
    my $dbh    = $self->getQueryHandle;
    my $extDbs = $self->readExternalDbReleases($dbh);

    # Statement used to look up DbRef entries for a given DB name
    #
    my $dbrefSth = $dbh->prepare("select db_ref_id from SRes.DbRef " .
				 "where  external_database_release_id = ? ".
                                 "and    lowercase_primary_identifier = ?");
    $self->{'dbrefSth'} = $dbrefSth;

    my $entry    = {};
    my $lastCode = undef;

    my $numEntries = 0;
    my $numRefs    = 0;

    open(PFAM, $openCmd);

  OUTER:
    while(<PFAM>) {

	# Skip these lines
	#
	next if (/^\# STOCKHOLM 1\.0$/);

	if (/^\#=GF (\S\S)\s+(\S.*)$/) {
	    my $code  = $1;
	    my $value = $2;

	    # Single-valued attributes
	    #
	    # AC One word in the form PFxxxxx or PBxxxxxx
	    # ID One word less than 16 characters
	    # DE 80 characters or less.
	    # AU Author of the entry.
	    # AL The method used to align the seed members.
	    # PI A single line, with semi-colon separated old identifiers
	    #
	    if ($code =~ /^(AC|ID|DE|AU|AL|PI)$/) {
		die "Multiple line entry with code '$code'" if ($lastCode eq $code);
		$entry->{$code} = $value;
	    } 
	    
	    # List-valued attributes
	    #
	    # RM MEDLINE UIs
	    # DR DB references
	    #
	    elsif ($code =~ /^(RM|DR)$/) {
		my $cur = $entry->{$code};

		if (not(defined($cur))) {
		    $entry->{$code} = [$value];
		} else {
		    push(@$cur, $value);
		}
	    }

	    # CC comment section; multiple lines
	    #
	    elsif ($code eq 'CC') {
		my $cur = $entry->{'CC'};

		if (not(defined($cur))) {
		    $entry->{'CC'} = $value;
		} else {
		    $entry->{'CC'} .= " " . $value;
		}
	    }

	    # Alignment -> end of entry
	    # 
	    elsif ($code eq 'SQ') {
		$entry->{'SQ'} = $value;  # number of sequences

                # Skip lines until end of Pfam Entry: '//'
                # then add records to DB
                # 
		while(<PFAM>) {
		    if (/^\/\/$/) {
			$self->addRecords($entry, $extDbs, \$numEntries, \$numRefs);

			# Reset for next entry.
			#
			$entry = {};
			++$numEntries;
                        $self->undefPointerCache();
			next OUTER;
		    }
		}
	    }
	    $lastCode = $code;
	} 
    }
    close(PFAM);

    my $summary = undef;

    if ($self->getArgs->{'parse_only'}) {
	$summary = "Parsed $numEntries entries and $numRefs new database references from Pfam release $release.";
    } else {
	$summary = "Loaded $numEntries entries and $numRefs database references from Pfam release $release.";
    }
    print STDERR $summary, "\n";
    return $summary;
}

# ----------------------------------------------------------
# Other subroutines
# ----------------------------------------------------------

# Reads ExternalDatabase and ExternalDatabaseRelease tables into a hash
# indexed on 'name' with value of the last release by date.
#
sub readExternalDbReleases() {
    my($self, $dbh) = @_;
    my $verbose     = $self->getArgs->{'verbose'};

    print "In readExternalDbReleases()\n" if $verbose;

    my $dbHash = {};
    my $sth    = $dbh->prepare("select * from SRes.ExternalDatabase");
    $sth->execute();

    my $sth2   = $dbh->prepare("select * ".
                               "from   SRes.ExternalDatabaseRelease ".
                               "where  external_database_id = ? ".
                               "order by release_date desc");

    while (my $row = $sth->fetchrow_hashref('NAME_lc')) {
	my $name    = $row->{'name'};
        my $extDbId = $row->{'external_database_id'};


        # Make sure only the last release is fetched and used
        $sth2->execute($extDbId);
        my $exDbRelRow = $sth2->fetchrow_hashref('NAME_lc');
        my %copy       = %$exDbRelRow;

	# normalize to lowercase
	$name            =~ tr/A-Z/a-z/;
	$dbHash->{$name} = \%copy;
    }
    $sth->finish();
    return $dbHash;
}

# Creates PfamEntry directly, calls other routines to create
# DbRef and DbRefPfamEntry.
#
sub addRecords {
    my ($self, $entry, $extDbs, $numEntries, $numRefs) = @_;

    print STDERR "$$numEntries: ", $entry->{'AC'}, "\n";

    # Write Pfam entry to the database
    #
    my $pe = GUS::Model::DoTS::PfamEntry->new();

    # Mandatory attributes
    #
    $pe->set('release',   $self->getArgs->{'release'});
    $pe->set('accession', $entry->{'AC'});

    # escape single quotes
    #
    $entry->{'ID'} =~ s/'/''/g; #' This is for emacs only
    $entry->{'DE'} =~ s/'/''/g; #'

    $pe->set('identifier',     $entry->{'ID'});
    $pe->set('definition',     $entry->{'DE'});
    $pe->set('number_of_seqs', $entry->{'SQ'});

    # Optional attributes
    #
    $pe->set('author', $entry->{'AU'}) if (defined($entry->{'AU'}));
    $pe->set('alignment_method', $entry->{'AL'}) if (defined($entry->{'AL'}));

    if (defined($entry->{'CC'})) {
        # escape single quotes
        #
        $entry->{'CC'} =~ s/'/''/g;          # ' <- for emacs syntax highlighter
        $pe->set('comment_string', $entry->{'CC'});
    } 

    $pe->submit() if (!$self->getArgs->{'parse_only'});
    my $entryId = $pe->get('pfam_entry_id');
    my $links   = {}; # store flag for each $links->{$dbRefId} to say DbRefPfamEntry has had a submit()

    # MEDLINE references
    #
    my $mrefs  = $entry->{'RM'};
    my $mlDbId = &getExtDbRelId($extDbs, 'medline');

    foreach my $mref (@$mrefs) {
        my($muid) = ($mref =~ (/^(\d+)$/));

        if( $self->createReferences($links, $entryId, $mlDbId, $muid) ){
            ++$$numRefs;
        }
    }

    # Other database references
    #        DR   EXPERT; jeisen@leland.stanford.edu;
    #        DR   MIM; 236200;
    #        DR   PFAMB; PB000001;
    #        DR   PRINTS; PR00012;
    #        DR   PROSITE; PDOC00017;
    #        DR   PROSITE_PROFILE; PS50225;
    #        DR   SCOP; 7rxn; sf;
    #        DR   PDB; 2nad A; 123; 332;
    #        DR   SMART; CBS;
    #        DR   URL; http://www.gcrdb.uthscsa.edu/;
    #
    my $dbrefs = $entry->{'DR'};

    foreach my $dbref (@$dbrefs) {
        my($db, $id, $rest) = ($dbref =~ /^([^;]+);\s*([^;]+);(.*)$/);
        die "Unable to parse $dbref" if (not defined($id));

        my $correct_name = $self->{'nameForDB'}->{$db} || $db;

        my $dbId = &getExtDbRelId($extDbs, $correct_name); #$self->{'nameForDB'}->{$db});

        if( $self->createReferences($links, $entryId, $dbId, $id) ){
            ++$$numRefs;
        }
    }
}

# Create DbRef and DbRefPfamEntry and return
# Returns 1 on sucess, 0 if DbRefPfamEntry could not be created
#
sub createReferences {
    my ($self, $links, $pfamEntryId, $ExtDbRelId, $id, $secondaryId, $remark) = @_;

    my $dbRefId   = $self->getDbRefId($ExtDbRelId,
                                      $id,
                                      $secondaryId,
                                      $remark);

    if (defined($dbRefId)) {
        my $link =
          GUS::Model::DoTS::DbRefPfamEntry->new({'pfam_entry_id' => $pfamEntryId,
                                                 'db_ref_id'     => $dbRefId});

        if (not(defined($links->{$dbRefId}))) {
            $link->submit() if (!$self->getArgs->{'parse_only'});
            $links->{$dbRefId} = 1;
            return 1;
        } elsif (!$self->getArgs->{'parse_only'}) {
            print STDERR "Duplicate reference to db_ref_id $dbRefId from pfam_entry_id $pfamEntryId\n";
            return 0;
        }
    }
}


# Return the external_database_release_id of the most recent 
# ExternalDatabaseRelease that corresponds to the ExternalDatabase 
# whose name is $name.  (Assuming that $extDbRels is the hash 
# generated by readExternalDbReleases().
#
sub getExtDbRelId {
    my($extDbRels, $name) = @_;

    $name     =~ tr/A-Z/a-z/; # Normalize to lowercase

    my $db    = $extDbRels->{$name};
    my $relId = $db->{'external_database_release_id'} if defined($db);
    
    die "Unable to find most recent ExternalDatabaseRelease for ExternalDatabase '$name', \$relId = '$relId'" if (not defined($relId));
    return $relId;
}

# Return the ID of a DbRef, if it already exists. If several exist, return the
# first. Otherwise create the DbRef and submit it before returning the newly
# generated ID.
#
sub getDbRefId {
    my($self, $extDbRelId, $primaryId, $secondaryId, $remark) = @_;

    my $verbose     = $self->getArgs->{'verbose'};
    my $parseOnly   = $self->getArgs->{'parse_only'};
    my $lcPrimaryId = $primaryId;
    $lcPrimaryId    =~ tr/A-Z/a-z/;
    
    my $ids      = [];
    my $dbrefSth = $self->{'dbrefSth'};

    $dbrefSth->execute($extDbRelId, $lcPrimaryId);

    while (my($id) = $dbrefSth->fetchrow_array()) {
        push(@$ids, $id);
    }

    my $idCount = scalar(@$ids);

    # Not in the database; create and add a new entry
    #
    if ($idCount == 0) {
	my $dbRef = GUS::Model::SRes::DbRef->new({
	    'external_database_release_id' => $extDbRelId,
	    'primary_identifier'   => $primaryId,
	    'lowercase_primary_identifier' => $lcPrimaryId,
	});
	
	if (defined($secondaryId) && $secondaryId) {
	    my $lcSecondaryId = $secondaryId;
	    $lcSecondaryId    =~ tr/A-Z/a-z/;
	    $dbRef->set('secondary_identifier',   $secondaryId);
	    $dbRef->set('lowercase_secondary_id', $lcSecondaryId);
	}

	$dbRef->set('remark', $remark) if (defined($remark) && $remark);

	if ($parseOnly) {
	    return 1; 
	} else {
	    $dbRef->submit();
	    return $dbRef->get('db_ref_id');
	}
    }
    
    # One copy in the database
    #
    elsif ($idCount == 1) {
	return $ids->[0];
    }

    # Multiple copies in the database; use the first one and 
    # print a warning message
    #
    else {
	print STDERR "WARNING - multiple rows ($idCount) for DbRef with external_db_id=$extDbRelId, primary_id=$primaryId\n";
	return $ids->[0];
    }
}

1;

