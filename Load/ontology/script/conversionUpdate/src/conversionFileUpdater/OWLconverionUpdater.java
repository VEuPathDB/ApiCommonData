package conversionFileUpdater;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Hashtable;

import org.kohsuke.args4j.CmdLineException;
import org.kohsuke.args4j.CmdLineParser;

import com.opencsv.CSVReader;
import com.opencsv.CSVWriter;

/**
 *  Update clinEpi conversion files
 *   
 *  @author Jie Zheng
 *  University of Pennsylvania <br>
 * 	Date: April-18-2021 <br>
 */

public class OWLconverionUpdater {
	static final String COLNAME_IRI = "IRI";
	static final String COLNAME_LABEL = "label";	
	static final String COLNAME_NEW_IRI = "new IRI";
	static final String COLNAME_PARENT_IRI = "parentIRI";
	static final String COLNAME_PARENT_LABEL = "parentLabel";
	
	public static void main(String[] args) throws IOException {
		OWLconversionUpdaterOptions bean = new OWLconversionUpdaterOptions();
	    CmdLineParser parser = new CmdLineParser(bean);

	    try {
	        parser.parseArgument(args);
	    } catch( CmdLineException e ) {
	        System.err.println(e.getMessage());
	        parser.printUsage(System.err);
	        System.exit(1);
	    }

		String path = bean.getPath();
		
		String inputFilename = bean.getInput();
		
		String messageFilename = bean.getMessageFilename();
		
		//String fileDir = "ApiCommonData";
		
		boolean overwrite = bean.getOverwrite().equalsIgnoreCase("true") ? true : false;
		
		ArrayList<String> message = new ArrayList<String>();
		
		// Read replace file to get replace column name and values
		message.add("Replace file: \n  " + inputFilename + "\n----------------\n\n");
				
		ArrayList <String[]> replaceFile = readCSVFile(inputFilename, true);

		System.out.println("read replace file " + inputFilename);
		
		String[] replaceHeaders = replaceFile.get(0);
		
		// replace term and its annotations based on the IRI
		Hashtable<String, Hashtable<String,String>> replaceObjects 
			= new Hashtable<String, Hashtable<String,String>>();
		//replaceObjects key, term IRI, value, column name/value 
		
		// replace parent term IRI or label based on the parent term IRI
		Hashtable<String,String> replaceParents 
			= new Hashtable<String,String>();
		
		for(int i = 1; i < replaceFile.size(); i ++ ) {
			String[] row = replaceFile.get(i);
						
			String iri = row[0];
			
			Hashtable<String,String> colVals = new Hashtable<String,String>();
			
			for(int j = 1; j < row.length; j ++) {
				String name = replaceHeaders[j];
				String value = row[j].trim();
							
				if (name.equalsIgnoreCase(COLNAME_NEW_IRI))	{
					name = COLNAME_IRI;
			
					if (value.length() > 0)		replaceParents.put(iri, value); // replace parent term IRI
				}
				
				if (!name.startsWith("#"))	colVals.put(name, value);
			}
	
			replaceObjects.put(iri, colVals);
		}
		
		/** print the replace information
		System.out.println("--- replace objects information --- ");
		for (String objectKey : replaceObjects.keySet()) {
			System.out.println("key: " + objectKey);
			Hashtable<String,String> replaceObject = replaceObjects.get(objectKey);
			for (String key: replaceObject.keySet()) {
			    System.out.println("  colName " + key + " -> " + replaceObject.get(key));
			} 	  						
		}		
		System.out.println("END ---"); 
		**/ 	  						
		
		// find names of conversion files
		ArrayList <String> conversionFilenames = new ArrayList <String>();
		
		walk(path, conversionFilenames);	
		
		if (conversionFilenames.size() == 0) 
			System.out.println("No conversion file under " + path);
		
		// walk through conversion file
		for (int counter = 0; counter < conversionFilenames.size(); counter++) { 
			
			// read conversion file
			String filename = conversionFilenames.get(counter);
			
			System.out.println("conversion file - " + filename);
			
			message.add("Conversion file: \n  " + filename + "\n"); 
	          
			ArrayList <String[]> conversionFile = readCSVFile(filename, false);
	          
			// get column position may need to be updated in the conversion File, and new column need to add

	        // header of conversion file
	        String[] headers = conversionFile.get(0);
	        
      	  	// Find IRI and Parent IRI column in the conversion file
      	  	int iriPos = -1;
      	  	int parentIriPos = -1;
      	  	
  	  		for (int n = 0; n < headers.length; n++) {
  	  			if (headers[n].equalsIgnoreCase(COLNAME_IRI)) {
  	  				iriPos = n;
  	  			} 
  	  			if (headers[n].equalsIgnoreCase(COLNAME_PARENT_IRI)) {
  	  				parentIriPos = n;
  	  			} 		
  	  		}
  	  		
  	  		if (iriPos < 0) {
  	  			message.add("WARNING: The conversion file does not have IRI column, cannot update automatically\n----------------\n\n");
  	  		} 
  	  		else {	        
  	  			Hashtable<String, Integer> updateColumn = new Hashtable<String, Integer>();
	        
  	  			// check whether the replace file contains the column header that are not in the conversion file
  	  			ArrayList <String> newColHeaders = new ArrayList <String>();
	          
  	  			for (int m = 1; m < replaceHeaders.length; m ++) {
  	  				boolean newCol = true;
      	  		
  	  				String cname = replaceHeaders[m];
  	  				
  	  				if (cname.startsWith("#"))	break;
   
  	  				for (int n = 0; n < headers.length; n++) {
  	  					if (cname.equalsIgnoreCase(headers[n])) {
  	  						updateColumn.put(cname, new Integer(n));
  	  						newCol = false;
  	  						break;
  	  					}
  	  				}
      	  		
  	  				if (newCol) {
  	  					if (cname.equalsIgnoreCase(COLNAME_NEW_IRI))	updateColumn.put(COLNAME_IRI, new Integer(iriPos));
  	  					else newColHeaders.add(cname);
  	  				}  	  			
  	  			}
  	  		
  	  			String[] newColumnHeaders = null;  
      	  
  	  			ArrayList <String[]> newColumn = null;
      	  	 
  	  			// add new columns if there is any      	  	
  	  			if (newColHeaders.size() > 0) {
  	  				newColumnHeaders = newColHeaders.toArray(new String[newColHeaders.size()]);
      	  		
  	  				newColumn = new ArrayList <String[]>();
      	  		
  	  				newColumn.add(newColumnHeaders);
  	  			}
      	  	
  	  			boolean update = false;
	          
  	  			// update the conversion file  
  	  			for(int l = 1; l < conversionFile.size(); l ++ ) {
  	  				boolean rowUpdate = false;
  	  				
  	  				String[] row = conversionFile.get(l);				
  	  				String iri = row[iriPos];
  	  				String parentIri = row[parentIriPos];
  	  				
  	  				if (replaceObjects.containsKey(iri) || replaceParents.containsKey(parentIri)) {
  	  					int rowNum = l + 1;
  	  					
  	  					// update term annotations based on term IRI
  	  					if (replaceObjects.containsKey(iri)) {
  	  						Hashtable<String,String> replaceObject = replaceObjects.get(iri);
   	  						
  	  						for(String colName : updateColumn.keySet()) {	
  	  							if (replaceObject.get(colName).length() > 0) {
  	  								int pos = updateColumn.get(colName).intValue();
  	  								String old_str = row[pos];
  	  								String new_str = replaceObject.get(colName);
  	  							
  	  								if (! old_str.equals(new_str)) {  	  							
  	  									row[pos] = replaceObject.get(colName);
  	  								
  	  									if (!rowUpdate)	{
  	  										message.add("\n  row " + rowNum + ": " + iri);
  	  										rowUpdate = true;
  	  									}  	  								
  	  								
  	  									if (old_str.length() > 0) message.add("\n   - " + colName + ": '" + old_str + "' replaced by '"+ new_str + "'");
  	  									else message.add("\n   - " + colName + ": add '" + new_str + "'");
 	  								
  	  									update = true;
  	  								}
  	  								//System.out.println("   " + colName + ", replace: " + conversionFile.get(l)[pos]);
  	  								//System.out.println("     with: " + replaceObject.get(colName));						
  	  							}	
  	  						}
  	  						
										
  	  						// add new columns if any
  	  						if (newColumnHeaders != null) {
  	  							String[] newVals = new String[newColumnHeaders.length];
						
  	  							for (int k = 0; k < newColumnHeaders.length; k ++) {
  	  								newVals[k] = replaceObject.get(newColumnHeaders[k]);
  	  								if (newVals[k].length() > 0) {   	  								
  	  									if (!rowUpdate)	{
  	  										message.add("\n  row " + rowNum + ": " + iri);
  	  										rowUpdate = true;
  	  									}

  	  									message.add("\n   - " + newColumnHeaders[k] + ": add '" + newVals[k] + "'");
  	  								
  	  									update = true;
  	  								}  	  							
  	  							}
  	  							newColumn.add(newVals);
  	  						} 
  	  					} else {				
  	  						if (newColumnHeaders != null) {
  	  							String[] newVals = new String[newColumnHeaders.length];
					
  	  							for (int k = 0; k < newColumnHeaders.length; k ++) {
  	  								newVals[k] = "";
  	  							}
					
  	  							newColumn.add(newVals);				
  	  						}
  	  					}
  	  					
	    	  			// update parent terms, IRI
	  	  	  			if (replaceParents.containsKey(parentIri)) {
	    	  				row[parentIriPos] = replaceParents.get(parentIri);
	    	  					  	    	  					
	    	  				if (!rowUpdate)	{
	    	  					message.add("\n  row " + rowNum + ": " + iri);
	    	  					rowUpdate = true;
	    	  				}
	    	  					
	  						message.add("\n   - " + COLNAME_PARENT_IRI + ": '" + parentIri + "' replaced by '" + row[parentIriPos] + "'");
				
	  						update = true;
	    	  			}
	    	  				
	    	  			conversionFile.set(l,row);
  	  				}
  	  			}	
	  		
  	  			if (update) {
  	  				String outFilename = overwrite ? filename : filename.substring(0, filename.length()-4) + "_temp.csv";
  	  				  	  					  		
  	  				writeCSVfile(outFilename, conversionFile, newColumn);
	  			
  	  				message.add("\n\nwrite updated file to: \n  " + outFilename + "\n---------------\n\n"); 

  	  			} else {
  	  				message.add("  - not find any term need to be updated\n----------------\n\n");
  	  			}
  	  		} 
		}
		
		System.out.println("Detailed message of updating conversion files is available in the file:\n   " + messageFilename);
		writeFile(messageFilename, message);
	}
	
	public static void writeCSVfile (String filename, ArrayList <String[]> list1, ArrayList <String[]> list2) 
			throws IOException {

		CSVWriter writer = new CSVWriter(new FileWriter(filename));
				
		for(int l = 0; l < list1.size(); l ++ ) {
			String[] line = list1.get(l);
			
			if(list2 != null)	
				line = concatTwoStringArrays(list1.get(l), list2.get(l));
			
			writer.writeNext(line);
		}
		
		writer.close();	      
	}

	public static void writeFile (String filename, ArrayList <String> list) 
			throws IOException {
		
		BufferedWriter writer = new BufferedWriter(new FileWriter(filename));
				
		for(int l = 0; l < list.size(); l ++ ) {
			writer.write(list.get(l));
		}
		
		writer.close();	      
	}
	
	public static String[] concatTwoStringArrays(String[] s1, String[] s2) {
		
	    String[] result = new String[s1.length+s2.length];
	    
	    int i;
	    
	    for (i=0; i<s1.length; i++)
	        result[i] = s1[i];
	    
	    int tempIndex =s1.length; 
	    
	    for (i=0; i<s2.length; i++)
	        result[tempIndex+i] = s2[i];
	    
	    return result;
	}

	public static void walk( String path, ArrayList<String> filenames ) {
		File root = new File( path );
		File[] list = root.listFiles();

		if (list == null) return;

		for ( File f : list ) {
			if ( f.isDirectory() ) {
				walk( f.getAbsolutePath(), filenames);
				//System.out.println( "Dir:" + f.getAbsoluteFile() );
			}
			else {
				//System.out.println( "File:" + f.getAbsoluteFile() );

				String filename = f.getAbsoluteFile().toString();
				
				if (filename.endsWith("conversion.csv")) {
					filenames.add(filename);
					//System.out.println("    " + filename);
				}			
			}
		}
	}
	
	
	@SuppressWarnings("resource")
	public static ArrayList <String[]> readCSVFile (String inputFile, boolean ignoreComment) {
		//System.out.println("Read file: " + inputFile +"\n");

		ArrayList <String[]> matrix = new ArrayList <String[]> ();
		
		try {
            	CSVReader csvReader = new CSVReader(Files.newBufferedReader(Paths.get(inputFile), StandardCharsets.UTF_8));

            	String[] row;
            	
            	while ((row = csvReader.readNext()) != null) { 
            		for (int i = 0; i<row.length; i++)	row[i] = cleanString(row[i]);
            		
            		// ignore the line starts with '#', which is comment line 
            		if(!(ignoreComment && row[0].startsWith("#"))) 	matrix.add(row);
            	}
		} catch (FileNotFoundException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		} 
		
		return matrix;
	}
	
	public static String cleanString (String s) {
		s = s.trim().replaceAll("^\"|\"$", "");	

		return s;
	}	
}
