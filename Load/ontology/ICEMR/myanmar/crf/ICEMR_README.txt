This ICEMR_README.txt file was generated on 2021-07-08 by Sabrina McCutchan, Data Architect at the Duke Global Health Institute.



GENERAL INFORMATION

1. Title of Dataset(s): 
   + ICEMR_PreliminaryStudy_Data_clean (.dta and .csv)
   + ICEMR_DrugResistance_Data (.dta and .csv)
   + ICEMR_Serology_Data (.dta and .csv)

2. Author Information
	A. Principal Investigator Contact Information
		Name: Wendy Prudhomme-O'Meara
		Institution: Duke Global Health Institute (DGHI)
		Address: 
		310 Trent Drive, Durham, NC 27710
		Box 90519, Durham, NC 27708
		Email: wendy.omeara@duke.edu

	B. Associate or Co-investigator Contact Information
		Name: Joseph Egger
		Institution: Duke Global Health Institute (DGHI)
		Address: 
		310 Trent Drive, Durham, NC 27710
		Box 90519, Durham, NC 27708 
		Email: jre18@duke.edu

3. Date of data collection (single date, range, approximate date) : 2018-08-02 - 2019-09-03

4. Geographic location of data collection : Kachin State in China, Rakhine State in Myanmar, Sagaing Region in Myanmar

5. Information about funding sources that supported the collection of the data: 


SHARING/ACCESS INFORMATION

1. Licenses/restrictions placed on the data: 

2. Links to publications that cite or use the data: 

3. Links to other publicly accessible locations of the data: 

4. Links/relationships to ancillary data sets: 

5. Was data derived from another source? yes/no
	A. If yes, list source(s): 

6. Recommended citation for this dataset: 


DATA & FILE OVERVIEW

1. File List: 
   1. Programs
      a. ICEMR_Cur_00_Master.do (prepares ICEMR_PreliminaryStudy_Data_clean.dta)
      b. ICEMR_ChinaLab_00_Master.do (prepares ICEMR_DrugResistance_Data.dta and ICEMR_Serology_Data.dta)
      c. valuelabels.do (applies value label schemes to variables in all datasets)
   2. Derived
      a. ICEMR_PreliminaryStudy_Data_clean.dta 
      b. ICEMR_PreliminaryStudy_Data_clean.csv 
      c. ICEMR_DrugResistance_Data.dta
      d. ICEMR_DrugResistance_Data.csv
      e. ICEMR_Serology_Data.dta	
      f. ICEMR_Serology_Data.csv
   3. Doc
      a. ICEMR_PreliminaryStudy_Codebook.docx 
      b. ICEMR_Preliminary_CRF_baseline_v7.0.docx (blank baseline CRF)
      c. ICEMR_Preliminary_CRF_follow-up_v7.0.docx(blank follow-up CRF)
      d. ICEMR_DrugResistance_Codebook.docx
      e. Code book for variable of ICEMR NIPD Drug resistance markers_May 21 2021.docx (original "codebook" provided by China site lab for raw drug resistance data)	
      f. Experimental operation of P. vivax serology testing.pdf (description of how China site lab serology data was generated)

2. Relationship between files, if important: See notes above under File List.

3. Additional related data collected that was not included in the current data package: 
   Multiple variables were transformed or excluded from the datasets to reduce deductive disclosure risk. 

4. Are there multiple versions of the dataset? No


METHODOLOGICAL INFORMATION

1. Description of methods used for collection/generation of data: 
In the ICEMR Preliminary study, case report forms (CRFs) were administered to study participants using ODK software on Android tablets. CRF data were stored in a cloud database hosted by Ona. Biologic samples of blood spots and blood draws were also collected concurrnetly with the administration of CRFs. These samples were tested for malaria. The two variables "uspcr_result" and "positive" in ICEMR_PreliminaryStudy_Data_clean.dta report test results. 

Some biologic samples taken from the ICEMR Preliminary Study's China site were further analyzed for P. vivax antigen testing and sequencing drug resistance markers. n=96 samples underwent antigen/serology testing, representing samples taken a) from China site study participants b) at visit number 1 c) where the malaria test result was positive (positive==1). Only n=57 of these 96 samples were successfully sequenced for drug resistance due to very low DNA from usPCR+ samples. Drug resistance and seroloy testing were not done at the DMR or DSMRC sites. 

2. Methods for processing the data: 
The lab processing method used for serology data at the China site is described in "Experimental operation of P. vivax serology testing.pdf"

3. Instrument- or software-specific information needed to interpret the data: 
ICEMR_PreliminaryStudy_Data_clean.dta was processed in Stata/SE 16.1. 

Stata packages involved in processing: wordcb, codebookout


DATA-SPECIFIC INFORMATION FOR: ICEMR_PreliminaryStudy_Data_clean
1. Number of variables: 111
2. Number of cases/rows: 5,851 observations representing 2,700 unique study participants



DATA-SPECIFIC INFORMATION FOR: ICEMR_DrugResistance_Data.dta
1. Number of variables: 28
2. Number of cases/rows: 57 observations representing 57 unique study participants



DATA-SPECIFIC INFORMATION FOR: ICEMR_Serology_Data.dta
1. Number of variables: 6
2. Number of cases/rows: 4,032 observations representing 96 unique study participants

