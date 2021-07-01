1. Epidemiology project at 3 sites in India
- 2 yr clinic study at 3 sites with ~3500 patients enrolled
- 2 yr cross-sectional study at 3 sites with ~3300 patients enrolled
- 1 yr longitudinal study at 2 sites with ~400 patients enrolled
- reactive case detection at 2 sites with ~1000 patients enrolled
- all with patient clinical history, parasitemia, PCR diagnosis, some with follow-up after drug treatment
- many samples used in: Felgner protein array studies (500 samples), drug resistance gene deep sequencing (250 samples), and will be used in COI deep sequencing (50) & Pv whole genome sequencing (30-40) assays

2. Cerebral malaria projects at IGH (led by Sam Wassmer)
- 60 CM & UM patients (final total to be enrolled: 160 patients) with patient clinical history, parasitemia, MRI scans, fundoscopy, and ~22 Pf genomes sequenced


longitudinal study:
	every 3 month visits, seldom have unscheduled visit

censor data
	1000 household in each site

section study
	clinical visit, collect household
	
	
More details
-----------------------------------------------------
Here is a recap of CSCMI just FYI, to help in interpreting the dictionaries.  The CSCMI operates at 3 field sites in India (Chennai, Nadiad, Raurkela).  At each site there may be the following projects:

Census  -  a baseline demographic survey of the data capture area.  These data are also used to select households for the 'Cross Sectional'  and "Longitudinal' project, below. Census projects exist for all three sites

Question: 
=========
Are there overlapped participants in Census project with 'Cross Sectional'  and "Longitudinal' project? If so, does it tracked, eg. use same subject_id?
=========


Clinic - 'passive' case detection: data for subjects who visit a designated local clinic that partners with the CSCMI.  They may or may not have malaria.  If they have malaria, there can be followup visit data for them.  CLinic projects exist for all three sites

Cross-Sectional (CX)- CSCMI workers go to randomly selected households (a 'cross section' of households in the area) in the capture area and enroll both malarious and non-malarious subjects.  The households are selected based on Census project data, so all Cross Sectional records have a field that records the related Census record UID.  If subjects were found to have malaria, they will have followup visit data.  Cross Sectional  projects exist for all 3 sites 

Longitudinal (CL) -- CSCMI workers go to 100 'sentinal' households and enroll both malarious and non-malarious subjects.  Every subject is revisited 4 or more times across the year, so every subject has multiple followup data records.  The households are selected based on Census project data, so all Longitdinal records have a field that records the related Census record UID.  Longitudinal projects exist for Chennai and Raurkela only.
 
Reactive Case Detection (RCD) -- CSCMI workers go to households known to have had malarious occupants ('index' households), and to nearby households ('proximal' and 'distal' households) and enroll currently malarious and  nonmalarious subjects.  The 'index' households are chosen from Cross Sectional data, so RCD cases have a field that records the related Cross Sectional record UID.  RCD projects exist for Chennai and Nadiad only.  


Questions:

what different between Clinic-based from Community-based?