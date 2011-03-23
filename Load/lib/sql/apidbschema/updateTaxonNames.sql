update sres.TaxonName
set name_class = 'scientific name',
    modification_date = sysdate
where name = 'Aspergillus nidulans'
  and name_class != 'scientific name';

update sres.TaxonName
set name_class = 'genbank anamorph',
    modification_date = sysdate
where name = 'Emericella nidulans'
  and name_class != 'genbank anamorph';

update sres.TaxonName
set name_class = 'scientific name',
    modification_date = sysdate
where name = 'Fusarium graminearum'
  and name_class != 'scientific name';

update sres.TaxonName
set name_class = 'genbank anamorph',
    modification_date = sysdate
where name = 'Gibberella zeae'
  and name_class != 'genbank anamorph';

update sres.TaxonName
set name_class = 'scientific name',
    modification_date = sysdate
where name = 'Cryptococcus neoformans'
  and name_class != 'scientific name';

update sres.TaxonName
set name_class = 'genbank anamorph',
    modification_date = sysdate
where name = 'Filobasidiella neoformans'
  and name_class != 'genbank anamorph';

exit
