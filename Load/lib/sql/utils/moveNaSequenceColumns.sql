-------------------------------------------------------------------------------
-- This script is meant to work in tandem with createNaSequenceViews.sql.  That
-- script redefines the five views against dots.NaSequenceImp so that they all
-- alias NaSequenceImp to "source_id".  This script handles the case where data
-- have already been loaded into the old view definitions.  It does this by
-- moving data from the former to the new home of source_id, swapping out other
-- data as necessary. Obviously, this should be run only once, only when needed.

UPDATE dots.NaSequenceImp
SET string1 = string2, string2 = string1
WHERE subclass_view='VirtualSequence';

UPDATE dots.NaSequenceImp
SET string1 = '', string2 = string1
WHERE subclass_view='Assembly';

------------------------------

exit
