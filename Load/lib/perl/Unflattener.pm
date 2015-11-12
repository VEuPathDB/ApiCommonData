package ApiCommonData::Load::Unflattener;

## a customized method to replace Bio::SeqFeature::Tools::Unflattener->unflatten_seq method in bioperl1.6.9
## due to a pseudogene bug
## a gene with a pseudo tag has been unflatted to pseudogene but subsequent parent-children structures have not been coded correctly yet
## e.g. tRNA has been unflatted to pseudotRNA but it is not the pseudogene's child any more. it is same as CDS->pseudoCDS
## meanwhile pseudotRNA and pseudoCDS are not a correct SO term yet
## the method unflatten_seq is the same as Bio::SeqFeature::Tools::Unflattener->unflatten_seq method except the block for pseudogene has been commented out

use base qw /Bio::SeqFeature::Tools::Unflattener/;

sub unflatten_seq_test {
  die "die for testing first\n";
}

sub unflatten_seq {
   my ($self,@args) = @_;

    my($seq, $resolver_method, $group_tag, $partonomy, 
       $structure_type, $resolver_tag, $use_magic, $noinfer) =
	$self->_rearrange([qw(SEQ
                              RESOLVER_METHOD
                              GROUP_TAG
                              PARTONOMY
			      STRUCTURE_TYPE
			      RESOLVER_TAG
			      USE_MAGIC
			      NOINFER
			     )],
                          @args);

   # seq we want to unflatten
   $seq = $seq || $self->seq;
   if (!$self->seq) {
       $self->seq($seq);
   }


   # prevent bad argument combinations
   if ($partonomy &&
       defined($structure_type)) {
       $self->throw("You cannot set both -partonomy and -structure_type\n".
		    "(the former is implied by the latter)");
   }

   # remember the current value of partonomy, to reset later
   my $old_partonomy = $self->partonomy;
   $self->partonomy($partonomy) if defined $partonomy;

   # remember old structure_type
   my $old_structure_type = $self->structure_type;
   $self->structure_type($structure_type) if defined $structure_type;

   # if we are sourcing our data from genbank, all the
   # features should be flat (eq no sub_SeqFeatures)
   my @flat_seq_features = $seq->get_SeqFeatures;
   my @all_seq_features = $seq->get_all_SeqFeatures;

   # sanity checks
   if (@all_seq_features > @flat_seq_features) {
       $self->throw("It looks as if this sequence has already been unflattened");
   }
   if (@all_seq_features < @flat_seq_features) {
       $self->throw("ASSERTION ERROR: something is seriously wrong with your features");
   }

   # tag for ungrouping; usually /gene or /locus_tag
   #     for example:        /gene="foo"
   $group_tag = $group_tag || $self->group_tag;
   if ($use_magic) {
       # use magic to guess the group tag
       my @sfs_with_locus_tag =
	 grep {$_->has_tag("locus_tag")} @flat_seq_features;
       my @sfs_with_gene_tag =
	 grep {$_->has_tag("gene")} @flat_seq_features;
       my @sfs_with_product_tag =
	 grep {$_->has_tag("product")} @flat_seq_features;
	 
#        if ($group_tag && $self->{'trust_grouptag'}) { # dgg suggestion
# 
#         }
#        elsif
       if (@sfs_with_locus_tag) {
        # dgg note: would like to -use_magic with -group_tag = 'gene' for ensembl genomes
        # where ensembl gene FT have both /locus_tag and /gene, but mRNA, CDS have /gene only
	   if ($group_tag && $group_tag ne 'locus_tag') {
	       $self->throw("You have explicitly set group_tag to be '$group_tag'\n".
			    "However, I detect that some features use /locus_tag\n".
			    "I believe that this is the correct group_tag to use\n".
			    "You can resolve this by either NOT setting -group_tag\n".
			    "OR you can unset -use_magic to regain control");
	   }

	   # use /locus_tag instead of /gene tag for grouping
	   # see GenBank entry AE003677 (version 3) for an example
	   $group_tag = 'locus_tag';
           if ($self->verbose > 0) {
               warn "Set group tag to: $group_tag\n";
           }
       }

       # on rare occasions, records will have no /gene or /locus_tag
       # but it WILL have /product tags. These serve the same purpose
       # for grouping. For an example, see AY763288 (also in t/data)
       if (@sfs_with_locus_tag==0 &&
           @sfs_with_gene_tag==0 &&
           @sfs_with_product_tag>0 &&
           !$group_tag) {
	   $group_tag = 'product';
           if ($self->verbose > 0) {
               warn "Set group tag to: $group_tag\n";
           }
           
       }
   }
   if (!$group_tag) {
       $group_tag = 'gene';
   }

   # ------------------------------
   # GROUP FEATURES using $group_tag
   #     collect features into unstructured groups
   # ------------------------------

   # -------------
   # we want to generate a list of groups;
   # each group is a list of SeqFeatures; this
   # group probably (but not necessarily)
   # corresponds to a gene model.
   #
   # this array will look something like this:
   # ([$f1], [$f2, $f3, $f4], ...., [$f97, $f98, $f99])
   #
   # there are also 'singleton' groups, with one member.
   # for instance, the 'source' feature is in a singleton group;
   # the same with others such as 'misc_feature'
   my @groups = ();
   # -------------

   # --------------------
   # we hope that the genbank record allows us to group by some grouping
   # tag.
   # for instance, most of the time a gene model can be grouped using
   # the gene tag - that is where you see
   #                    /gene="foo"
   # in a genbank record
   # --------------------
   
   # keep an index of groups by their
   # grouping tag
   my %group_by_tag = ();
   

   # iterate through all features, putting them into groups
   foreach my $sf (@flat_seq_features) {
       if (!$sf->has_tag($group_tag)) {
	   # SINGLETON
           # this is an ungroupable feature;
           # add it to a group of its own
           push(@groups, [$sf]);
       }
       else {
	   # NON-SINGLETON
           my @group_tagvals = $sf->get_tag_values($group_tag);
           if (@group_tagvals > 1) {
	       # sanity check:
               # currently something can only belong to one group
               $self->problem(2,
			      ">1 value for /$group_tag: @group_tagvals\n".
			      "At this time this module is not equipped to handle this adequately", $sf);
           }
	   # get value of group tag
           my $gtv = shift @group_tagvals;
           $gtv || $self->throw("Empty /$group_tag vals not allowed!");

           # is this a new group?
           my $group = $group_by_tag{$gtv};
           if ($group) {
               # this group has been encountered before - add current
               # sf to the end of the group
               push(@$group, $sf);
           }
           else {
               # new group; add to index and create new group
               $group = [$sf];  # currently one member; probably more to come
               $group_by_tag{$gtv} = $group;
               push(@groups, $group);
           }
       }
   }
   
   # as well as having the same group_tag, a group should be spatially
   # connected. if not, then the group should be split into subgroups.
   # this turns out to be necessary in the case of multicopy genes.
   # the standard way to represent these is as spatially disconnected
   # gene models (usually a 'gene' feature and some kind of RNA feature)
   # with the same group tag; the code below will split these into 
   # seperate groups, one per copy.
   @groups = map { $self->_split_group_if_disconnected($_) } @groups;

   # remove any duplicates; most of the time the method below has
   # no effect. there are some unusual genbank records for which
   # duplicate removal is necessary. see the comments in the
   # _remove_duplicates_from_group() method if you want to know
   # the ugly details
   foreach my $group (@groups) {
       $self->_remove_duplicates_from_group($group);
   }

   # -


### since these pseudo- issue does not code completely for the gene structure
### comment it out temporarily
#
#   # PSEUDOGENES, PSEUDOEXONS AND PSEUDOINTRONS
#   # these are indicated with the /pseudo tag
#   # these are mapped to a different type; they should NOT
#   # be treated as normal genes
#   foreach my $sf (@all_seq_features) {
#       if ($sf->has_tag('pseudo')) {
#           my $type = $sf->primary_tag;
#           # SO type is typically the same as the normal
#           # type but preceeded by "pseudo"
#           if ($type eq 'misc_RNA' || $type eq 'mRNA') { 
#            # dgg: see TypeMapper; both pseudo mRNA,misc_RNA should be pseudogenic_transcript
#               $sf->primary_tag("pseudotranscript");
#           }
#           else {
#               $sf->primary_tag("pseudo$type");
#           }
#       }
#   }
#
   # now some of the post-processing that follows which applies to
   # genes will NOT be applied to pseudogenes; this is deliberate
   # for example, gene models are normalised to be gene-transcript-exon
   # for pseudogenes we leave them as pseudogene-pseudoexon

   # --- MAGIC ---
   my $need_to_infer_exons = 0;
   my $need_to_infer_mRNAs = 0;
   my @removed_exons = ();
   if ($use_magic) {
       if (defined($structure_type)) {
	   $self->throw("Can't combine use_magic AND setting structure_type");
       }
       my $n_introns =
	 scalar(grep {$_->primary_tag eq 'exon'} @flat_seq_features);
       my $n_exons =
	 scalar(grep {$_->primary_tag eq 'exon'} @flat_seq_features);
       my $n_mrnas =
	 scalar(grep {$_->primary_tag eq 'mRNA'} @flat_seq_features);
       my $n_mrnas_attached_to_gene =
	 scalar(grep {$_->primary_tag eq 'mRNA' &&
			$_->has_tag($group_tag)} @flat_seq_features);
       my $n_cdss =
	 scalar(grep {$_->primary_tag eq 'CDS'} @flat_seq_features);
       my $n_rnas =
	 scalar(grep {$_->primary_tag =~ /RNA/} @flat_seq_features);  
       # Are there any CDS features in the record?
       if ($n_cdss > 0) {
           # YES
           
	   # - a pc gene model should contain at the least a CDS

           # Are there any mRNA features in the record?
	   if ($n_mrnas == 0) {
               # NO mRNAs:
	       # looks like structure_type == 1
	       $structure_type = 1;
	       $need_to_infer_mRNAs = 1;
	   }
	   elsif ($n_mrnas_attached_to_gene == 0) {
               # $n_mrnas > 0
               # $n_mrnas_attached_to_gene = 0
               #
               # The entries _do_ contain mRNA features,
               # but none of them are part of a group/gene, i.e. they
               # are 'floating'

	       # this is an annoying weird file that has some floating
	       # mRNA features; 
	       # eg ftp.ncbi.nih.gov/genomes/Schizosaccharomyces_pombe/
               
               if ($self->verbose) {
                   my @floating_mrnas =
                     grep {$_->primary_tag eq 'mRNA' &&
                             !$_->has_tag($group_tag)} @flat_seq_features;
                   printf STDERR "Unattached mRNAs:\n";
                   foreach my $mrna (@floating_mrnas) {
                       $self->_write_sf_detail($mrna);
                   }
                   printf STDERR "Don't know how to deal with these; filter at source?\n";
               }

	       foreach (@flat_seq_features) {
		   if ($_->primary_tag eq 'mRNA') {
		       # what should we do??
		       
		       # I think for pombe we just have to filter
		       # out bogus mRNAs prior to starting
		   }
	       }

	       # looks like structure_type == 2
	       $structure_type = 2;
	       $need_to_infer_mRNAs = 1;
	   }
	   else {
	   }

	   # we always infer exons in magic mode
	   $need_to_infer_exons = 1;
       }
       else {
	   # this doesn't seem to be any kind of protein coding gene model
	   if ( $n_rnas > 0 ) {
	       $need_to_infer_exons = 1;
	   }
       }

       $need_to_infer_exons = 0 if $noinfer; #NML

       if ($need_to_infer_exons) {
	   # remove exons and introns from group -
	   # we will infer exons later, and we
	   # can always infer introns from exons
	   foreach my $group (@groups) {
	       @$group = 
		 grep {
		     my $type = $_->primary_tag();
		     if ($type eq 'exon') {
			 # keep track of all removed exons,
			 # so we can do a sanity check later
			 push(@removed_exons, $_);
		     }
		     $type ne 'exon' && $type ne 'intron'
		 } @$group;
	   }
	   # get rid of any groups that have zero members
	   @groups = grep {scalar(@$_)} @groups;
       }
   }
   # --- END OF MAGIC ---
   
   # LOGICAL ASSERTION
   if (grep {!scalar(@$_)} @groups) {
       $self->throw("ASSERTION ERROR: empty group");
   }

   # LOGGING
   if ($self->verbose > 0) {
       printf STDERR "GROUPS:\n";
       foreach my $group (@groups) {
	   $self->_write_group($group, $group_tag);
       }
   }
   # -

   # --------- FINISHED GROUPING -------------


   # TYPE CONTAINMENT HIERARCHY (aka partonomy)
   # set the containment hierarchy if desired
   # see docs for structure_type() method
   if ($structure_type) {
       if ($structure_type == 1) {
	   $self->partonomy(
                            {CDS => 'gene',
                             exon => 'CDS',
                             intron => 'CDS',
                            }
                           );
       }
       else {
	   $self->throw("structure_type $structure_type is currently unknown");
       }
   }

   # see if we have an obvious resolver_tag
   if ($use_magic) {
       foreach my $sf (@all_seq_features) {
	   if ($sf->has_tag('derived_from')) {
	       $resolver_tag = 'derived_from';
	   }
       }
   }

   if ($use_magic) {
       # point all feature types without a container type to the root type.
       #
       # for example, if we have an unanticipated feature_type, say
       # 'aberration', this should by default point to the parent 'gene'
       foreach my $group (@groups) {
	   my @sfs = @$group;
	   if (@sfs > 1) {
	       foreach my $sf (@sfs) {
		   my $type = $sf->primary_tag;
		   next if $type eq 'gene';
		   my $container_type = $self->get_container_type($type);
		   if (!$container_type) {
		       $self->partonomy->{$type} = 'gene';
		   }
	       }
	   }
       }
   }

   # we have done the first part of the unflattening.
   # we now have a list of groups; each group is a list of seqfeatures.
   # the actual group itself is flat; we may want to unflatten this further;
   # for instance, a gene model can contain multiple mRNAs and CDSs. We may want
   # to link the correct mRNA to the correct CDS via the bioperl sub_SeqFeature tree.
   #
   # what we would end up with would be
   #  gene1
   #    mRNA-a
   #      CDS-a
   #    mRNA-b
   #      CDS-b
   my @top_sfs = $self->unflatten_groups(-groups=>\@groups,
                                         -resolver_method=>$resolver_method,
					 -resolver_tag=>$resolver_tag);
   
   # restore settings
   $self->partonomy($old_partonomy);

   # restore settings
   $self->structure_type($old_structure_type);

   # modify the original Seq object - the top seqfeatures are now
   # the top features from each group
   $seq->remove_SeqFeatures;
   $seq->add_SeqFeature(@top_sfs);

   # --------- FINISHED UNFLATTENING -------------

   # lets see if there are any post-unflattening tasks we need to do

   

   # INFERRING mRNAs
   if ($need_to_infer_mRNAs) {
       if ($self->verbose > 0) {
	   printf STDERR "** INFERRING mRNA from CDS\n";
       }
       $self->infer_mRNA_from_CDS(-seq=>$seq, -noinfer=>$noinfer);
   }

   # INFERRING exons
   if ($need_to_infer_exons) {

       # infer exons, one group/gene at a time
       foreach my $sf (@top_sfs) {
	   my @sub_sfs = ($sf, $sf->get_all_SeqFeatures);
	   $self->feature_from_splitloc(-features=>\@sub_sfs);
       }

       # some exons are stated explicitly; ie there is an "exon" feature
       # most exons are inferred; ie there is a "mRNA" feature with
       # split locations
       #
       # if there were exons explicitly stated in the entry, we need to
       # do two things:
       #
       # make sure these exons are consistent with the inferred exons
       #  (you never know)
       #
       # transfer annotation (tag-vals) from the explicit exon to the
       # new inferred exon
       if (@removed_exons) {
	   my @allfeats = $seq->get_all_SeqFeatures;

	   # find all the inferred exons that are children of mRNA
	   my @mrnas =  grep {$_->primary_tag eq 'mRNA'} @allfeats;
	   my @exons =  
	     grep {$_->primary_tag eq 'exon'}
	       map {$_->get_SeqFeatures} @mrnas;

	   my %exon_h = (); 	   # index of exons by location;

	   # there CAN be >1 exon at a location; we can represent these redundantly
	   # (ie as a tree, not a graph)
	   push(@{$exon_h{$self->_locstr($_)}}, $_) foreach @exons;
	   my @problems = ();      # list of problems;
	                           # each problem is a 
	                           # [$severity, $description] pair
	   my $problem = '';
	   my ($n_exons, $n_removed_exons) =
	     (scalar(keys %exon_h), scalar(@removed_exons));
	   foreach my $removed_exon (@removed_exons) {
	       my $locstr = $self->_locstr($removed_exon);
	       my $inferred_exons = $exon_h{$locstr};
	       delete $exon_h{$locstr};
	       if ($inferred_exons) {
		   my %exons_done = ();
		   foreach my $exon (@$inferred_exons) {

		       # make sure we don't move stuff twice
		       next if $exons_done{$exon};
		       $exons_done{$exon} = 1;

		       # we need to tranfer any tag-values from the explicit
		       # exon to the implicit exon
		       foreach my $tag ($removed_exon->get_all_tags) {
			   my @vals = $removed_exon->get_tag_values($tag);
			   if (!$exon->can("add_tag_value")) {
			       # I'm puzzled as to what should be done here;
			       # SeqFeatureIs are not necessarily mutable,
			       # but we know that in practice the implementing
			       # class is mutable
			       $self->throw("The SeqFeature object does not ".
					    "implement add_tag_value()");
			   }
			   $exon->add_tag_value($tag, @vals);
		       }
		   }
	       } 
               else {
                   # no exons inferred at $locstr
		   push(@problems,
			[1, 
			 "there is a conflict with exons; there was an explicitly ".
			 "stated exon with location $locstr, yet I cannot generate ".
			 "this exon from the supplied mRNA locations\n"]);
	       }
	   }
	   # do we have any inferred exons left over, that were not
	   # covered in the explicit exons?
	   if (keys %exon_h) {
	       # TODO - we ignore this problem for now
	       push(@problems,
		    [1,
		     sprintf("There are some inferred exons that are not in the ".
			     "explicit exon list; they are the exons at locations:\n".
			     join("\n", keys %exon_h)."\n")]);
	   }

	   # report any problems
	   if (@problems) {
	       my $thresh = $self->error_threshold;
	       my @bad_problems = grep {$_->[0] > $thresh} @problems;
	       if (@bad_problems) {
		   printf STDERR "PROBLEM:\n";
		   $self->_write_hier(\@top_sfs);
		   # TODO - allow more fine grained control over this
		   $self->{_problems_reported} = 1;
		   $self->throw(join("\n",
				     map {"@$_"} @bad_problems));
	       }
	       $self->problem(@$_) foreach @problems;
	   }
       }
   }    
   # --- end of inferring exons --

   # return new top level features; this can also 
   # be retrieved via
   #   $seq->get_SeqFeatures();
#   return @top_sfs;
   return $seq->get_SeqFeatures;
}

1;
