#!/usr/bin/perl -w
use strict;
use Env qw(HOME USER);
use Data::Dumper;
use Bio::Root::Version;
use version;
use Bio::DB::Taxonomy;
use Getopt::Long;
my $VERSION = version->parse($Bio::Root::Version::VERSION);

my @tax_levels = qw(superkingdom kingdom phylum class order family genus);
my %wanted_rank = map { $_ => 1 } @tax_levels;
my $nodesfile = "$HOME/lib/taxonomy/nodes.dmp";
my $namefile = "$HOME/lib/taxonomy/names.dmp";
my $indexdir = "/tmp/ncbi_taxonomy-$USER";
my $infile = 'orthoOrgs.tab';
GetOptions(
'nodes:s' => \$nodesfile,
'names:s' => \$namefile,
'index:s' => \$indexdir,
'i|in:s' => \$infile,
);
mkdir($indexdir) unless -d $indexdir;
my $taxdb = Bio::DB::Taxonomy->new(-source => 'flatfile',
				   -directory => $indexdir,
				   -nodesfile => $nodesfile,
				   -namesfile => $namefile);

open(my $fh => $infile) || die "cannot open $infile: $!";
my $header = <$fh>;
chomp($header);
my @header = split('\t',$header);
print join("\t", @tax_levels,@header),"\n";
while (<$fh>) {
  chomp;
  my ($name, $taxid,@rest) = split(/\t/,$_);

  if ( ! defined $name ) {
    warn("empty line $_");
    next;
  }

  my $taxon;
  if ( $VERSION == version->parse('1.4') ) {
    # API 1.4
    $taxon = $taxdb->get_Taxonomy_Node(-taxonid => $taxid);
  } else {
    # API 1.6+
    $taxon = $taxdb->get_taxon(-taxonid => $taxid);
  }
  my %taxonomy;
  if ( $taxon ) {
#    my @class = $taxon->classification(@tax_levels);
#    warn("class is @class\n");
    if ( $VERSION == version->parse('1.4') ) {
      my $ancestor = $taxon->parent_id;
      # root node parent_id is 1
      while ( $ancestor > 1  ) {
	my $rank = $taxon->rank;
	if ( $wanted_rank{$rank} ) {
	  $taxonomy{$rank} = $taxon->node_name;
	}
	$taxon = $taxdb->get_Taxonomy_Node(-taxonid => $ancestor);
	$ancestor = $taxon->parent_id;
      }
    } else {
      while ( my $ancestor = $taxon->ancestor ) {
	my $rank = $taxon->rank;
	if ( $wanted_rank{$rank} ) {
	  $taxonomy{$rank} = join(" ", @{$taxon->name('scientific')});
	}
	$taxon = $ancestor;
      }
    }

  } else {
    warn("cannot find taxon for $taxid ($name)\n");
  }
  print join(",",(map { $taxonomy{$_} || '' } @tax_levels),$name,$taxid,@rest),"\n";
}
