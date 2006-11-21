#! /usr/bin/perl
                                                                                             
package pcbiPubmed;
require Exporter;
@ISA = qw (Exporter);
@EXPORT = qw (
            setPubmedID,
            fetchAuthorList,
            fetchPublication,
            fetchPubmedUrl
            );

use strict;
use LWP::Simple;
use XMLUtils;
                                                                                             
my $ncbiEutilsUrl = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?"
                    . "db=pubmed&retmode=xml&rettype=abstract&id=";
                                                                                             
my $publicationPubmedUrl = "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?"
                            . "cmd=Retrieve&amp;db=PubMed&amp;list_uids=";

my ($id, $content);


sub setPubmedID {
    my ($pubmed_id) = @_;
	$id = $pubmed_id;
	
	$content = LWP::Simple::get ($ncbiEutilsUrl . $pubmed_id)
}
                                                                                             
sub fetchPubmedUrl {
    return $publicationPubmedUrl . $id;
}
                                                                                             
sub fetchAuthorList {
	my @authors;
	my $aContent = XMLUtils::extractTagContent ($content, "AuthorList");

	foreach my $author (XMLUtils::extractAllTags ($aContent, "Author")) {
		my $attrValue = XMLUtils::getAttrValue ($author, "Author", "ValidYN");
		#Some of them don't have this attribute.
	    if (!$attrValue || $attrValue eq "Y") {
			my $lastname = XMLUtils::extractTagContent ($author, "LastName");
	        #my $initials = XMLUtils::extractTagContent ($author, "Initials");
	        #push @authors, "$lastname $initials";
			return "$lastname et al.";
	    }
	}
	
	#return join (", ", @authors);
}
                                                                                             
sub fetchTitle {
    my $title = XMLUtils::extractTagContent($content, "ArticleTitle");
	return $title;
}
                                                                                             
sub fetchPublication {    
	my $publication = XMLUtils::extractTag ($content, "Journal");
	my ($pubName, $pubVolume, $pubIssue, $pubDate, $pubPages);
	
	# The name of the journal can come from one of the three sources
	#	1. ISOAbbreviation
	#	2. Title
	#	3. MedlineTA
	# Use the same order of preference in obtaining a name.
	# Don't know what's the difference between Title and MedlineTA, but
	# one of them didn't have Title, but had MedlineTA.
	
	if (!($pubName = XMLUtils::extractTagContent ($publication, "ISOAbbreviation"))) {
		if (!($pubName = XMLUtils::extractTagContent ($publication, "Title"))) {
			$pubName = XMLUtils::extractTagContent ($content, "MedlineTA");
		}
	}
	                                                                               
	# Publication Date can have three forms:
	#   1. Year and Month, and optionally Day. 
	#   2. Year and Season
	#   3. MedlineDate
	                                                                               
	my ($pubYear, $pubSeason, $pubMonth, $pubDay, $pubMedlineDate);
	if ($pubYear = XMLUtils::extractTagContent ($publication, "Year")) {
	    if ($pubMonth = XMLUtils::extractTagContent ($publication, "Month")) {
			if ($pubDay = XMLUtils::extractTagContent ($publication, "Day")) {
		        $pubDate = "$pubYear $pubMonth $pubDay";
			} else {
				$pubDate = "$pubYear $pubMonth";
			}
	    } else {
	        $pubDate = "$pubYear "
	                    . XMLUtils::extractTagContent($publication, "Season");
	    }
	} else {
	    $pubDate = XMLUtils::extractTagContent ($publication, "MedlineDate");
	}
	                                                                               
	$pubVolume = XMLUtils::extractTagContent ($publication, "Volume");
	$pubIssue = XMLUtils::extractTagContent ($publication, "Issue");
	                                                                               
	# Pagination can have two forms:
	#   1. MedlinePgn - indicates both start and end
	#   2. StartPage, and optionally EndPage
	my $pages = XMLUtils::extractTagContent ($content, "Pagination");
	$pubPages = XMLUtils::extractTagContent ($pages, "MedlinePgn")
	    or $pubPages = XMLUtils::extractTagContent ($pages, "StartPage")
	                . "-"
	                . XMLUtils::extractTagContent ($pages, "EndPage");
	                                                                               
	return "$pubName $pubDate;$pubVolume($pubIssue):$pubPages";
}
                                                                                             
1;

