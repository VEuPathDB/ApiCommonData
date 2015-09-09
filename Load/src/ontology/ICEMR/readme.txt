Terminology used for ICEMR project

Organizational terms
- All ICEMR groups will use same hierarchy, all these organizational terms with ICEMR domain IDs

Data dictionary
- All data dictionary terms are added as leaf classes  
- All these terms should have mapped ontology terms
- In principle, mapping between data dictionary to ontology terms should be one to one. 
- If no mapped ontology term found for any data dictionary, we can generate internal temporary terms with TEMP domain IDs. 

Controlled vocabulary of data dictionary
- The controlled vocabulary are added as individuals
- All these terms should have mapped ontology terms
- The mapped ontology terms might be same as the ontology terms used as data dictionary and can belong to more than one class types
Notes: In this case, we must be sure that the original terms used in the project mean same thing.
- If no mapped ontology term found for any data dictionary, we can generate internal temporary terms with TEMP domain IDs.

Temporary terms
	The temporary terms will only have label and ID. Meanwhile, contact corresponding ontologies or prepare to add them in the EuPath ontology. The temporary terms will be deprecated when the terms are available in the ontology. Based on the need, we can decide whether we deprecate the temperoray terms following OBO Foundry/OBI deprecation policy
