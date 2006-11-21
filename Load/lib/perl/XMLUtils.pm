#! /usr/bin/perl

# Author: Praveen Chakravarthula (praveenc@pcbi.upenn.edu)
# Purpose: Quick and dirty collection of XML parsing functions.

package XMLUtils;
                                                                                             
require Exporter;
@ISA = qw (Exporter);
@EXPORT = qw (
            spliceByTag,
            extractTag,
            extractTagContent,
            extractAllTags,
            deleteTag,
            deleteAllTags,
            getAttrValue,
			getTagName,
			getChildContent,
			encloseTag
            );
                                                                                             
use strict;

#
#	Returns the XML string with the first occurrence of the given
#	tag deleted.
#
sub deleteTag {
    my ($content, $tag) = @_;
                                                                                             
    my ($pre, $tagContent, $post) = spliceByTag ($content, $tag);
    return $pre . $post;
}

#
#	Returns an XML string with all the occurrences of the given
#	tag deleted.
#
sub deleteAllTags {
    my ($content, $tag) = @_;
                                                                                             
    my $tagBeginPattern = getTagBeginPattern($tag);
    do {
        deleteTag ($content, $tag);
    } while ($content =~ /$tagBeginPattern/);
                                                                                             
    return $content;
}

#
# Returns the first occurrence of the given tag.
#
sub extractTag {
    my ($content, $tag) = @_;
                                                                                             
    my ($pre, $tagContent, $post) = spliceByTag ($content, $tag);
    return $tagContent;
}

sub extractTagContent {
	my ($content, $tag) = @_;
	return getChildContent (extractTag ($content, $tag));
}

#
#	Returns all the occurrences of the given tag from the content
#	as an array.
#
sub extractAllTags {
    my ($content, $tag) = @_;
                                                                                             
    my @tagContents;
    my $tagBeginPattern = getTagBeginPattern($tag);
    do {
		my ($pre, $tc, $post) = spliceByTag ($content, $tag);
		#print "$tc\n";
        push @tagContents, $tc;
		$content = $post;
    } while ($content =~ /$tagBeginPattern/);

	return @tagContents;
}

#	Internal utility routine that returns the regular expression
#	representing the beginning of a tag pattern in XML
sub getTagBeginPattern {
    my ($tag) = @_;
    return "<" . $tag . "(\s*[^>]*)?/?>";
}

#	Internal utility routine that returns the regular expression
#	representing the ending of a tag pattern in XML
sub getTagEndPattern {
    my ($tag) = @_;
    return "<\/$tag>";
}

#
#	Return the attribute value of the named attribute
#	of the first occurrence specified tag in the given 
#	content.
#
sub getAttrValue {
    my ($content, $tag, $attrName) = @_;
                                                                                             
    my $tagBegin = getTagBeginPattern($tag);
    $content =~ /$tagBegin/;
                                                                                             
    my $temp = $&;
    $temp =~ s/\/?>//;
    foreach my $attr (grep {/=/} split(/\s+/, $temp)) {
        my ($aName, $aValue) = split (/=/, $attr);
        if ($aName eq $attrName) {
            $aValue =~ s/^[\'\"]//;
            $aValue =~ s/[\'\"]$//;
                                                                                             
            return $aValue;
        }
    }
                                                                                             
    return "";
}

#
#	Finds the first occurence of the given tag in the content, and
#	replaces it with the replacement string provided.
#

sub replaceTag {
	my ($content, $tag, $replacement) = @_;
	my ($pre, $tagContent, $post) = spliceByTag ($content, $tag);
	return $pre . $replacement . $post;
}

#
#	Subsitute the tag contents (including the begin tag, attributes,
#	and the end tag) based on a given function reference (pointer).
#	The function is expected to take one argument - the existing tag 
#	content, and return the modified tag content. The modified content
#	must be valid XML.
#
sub replaceAllTags {
	my ($content, $tag, $replacementFunc) = @_;
	my $modified = "";	
	my $beginTag = getTagBeginPattern ($tag);
	
	my ($pre, $tagContent, $post);
	do {
		($pre, $tagContent, $post) = spliceByTag ($content, $tag);
		$modified .= $pre . &{$replacementFunc}($tagContent);
		$content = $post;
	} while ($content =~ /$beginTag/);

	$modified .= $post;

	return $modified;
}

#
#	Splices the given XML string into 3 parts, based on the
#	given tag. The first part is the XML string before the 
#	first occurence of the tag, the second string is the
#	tag content, and the last string is the XML content in 
#	the given string after the tag. 

#	Concatenating the three returned strings will give the 
#	original XML input string.
#

sub spliceByTag {
    my ($content, $tag) = @_;

    my $tagBeginPat = getTagBeginPattern($tag);
    my $tagEndPat = getTagEndPattern($tag);

    $content =~ /$tagBeginPat/;

    my $pre = $`;
    my $tagContent = $&;
    my $rest = $';

    #there may not be an end tag, if the begin tag
    #is implicitly closed

    if ($tagContent =~ /\/>$/) {
        return ($pre, $tagContent, $rest);
    }
                                                                                           
    $rest =~ /$tagEndPat/;
    $tagContent .= $` . $&;
    my $post = $';

    return ($pre, $tagContent, $post);
}

#
#	Return the name of the tag at the highest level
#

sub getTagName {
	my ($content) = @_;
	$content =~ /<[a-zA-Z0-9_]+/;
	my $tagName = $&;
	$tagName =~ s/^<//;
	return $tagName;
}

sub getChildContent {
	my ($content) = @_;
	my $tag = getTagName ($content);
	my $begin = getTagBeginPattern ($tag);
	my $end = getTagEndPattern ($tag);
	
	#print "$tag: $begin -- $end\n";

	$content =~ s/$begin//;
	$content =~ s/$end//;
	return $content;
}

sub encloseTag {
	my ($content, $tag) = @_;
	return "<" . $tag . ">" . $content . "</" . $tag .">";
}

1;
