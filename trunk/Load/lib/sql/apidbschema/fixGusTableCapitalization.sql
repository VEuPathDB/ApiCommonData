UPDATE core.TableInfo
SET name = 'AAFeatureComment'
WHERE name = 'AAFEATURECOMMENT';

UPDATE core.TableInfo
SET name = 'AAFeatureDbRef'
WHERE name = 'AAFEATUREDBREF';

UPDATE core.TableInfo
SET name = 'CompositeElementDbRef'
WHERE name = 'COMPOSITEELEMENTDBREF' OR name = 'CompositeElementDbRref';

UPDATE core.TableInfo
SET name = 'CompositeElementNASequence'
WHERE name = 'COMPOSITEELEMENTNASEQUENCE';

UPDATE core.TableInfo
SET name = 'ElementDbRef'
WHERE name = 'ELEMENTDBREF';

UPDATE core.TableInfo
SET name = 'ElementNASequence'
WHERE name = 'ELEMENTNASEQUENCE';

exit
