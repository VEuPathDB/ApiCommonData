package conversionFileUpdater;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
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
		
		String fileDir = "ApiCommonData";
		
		ArrayList<String> message = new ArrayList<String>();
		
		// get replace column name and values
		if (inputFilename.contains(fileDir))	message.add("Replace file: \n  " + inputFilename.substring(inputFilename.indexOf(fileDir)) + "\n----------------\n\n");	
		else									message.add("Replace file: \n  " + inputFilename + "\n----------------\n\n");
		
		ArrayList <String[]> replaceFile = readCSVFile(inputFilename);
		
		String[] replaceHeaders = replaceFile.get(0);
		
		Hashtable<String, Hashtable<String,String>> replaceObjects 
			= new Hashtable<String, Hashtable<String,String>>();

		
		for(int i = 1; i < replaceFile.size(); i ++ ) {
			String[] row = replaceFile.get(i);
						
			String iri = row[0];
			
			Hashtable<String,String> colVals = new Hashtable<String,String>();
			
			for(int j = 1; j < row.length; j ++) {
				String name = replaceHeaders[j];
				String value = row[j];
				
				if (name.equalsIgnoreCase("new IRI"))	name = "IRI";
				
				colVals.put(name, value);
			}
			
			replaceObjects.put(iri, colVals);
		}
		
		// find names of conversion files
		ArrayList <String> conversionFilenames = new ArrayList <String>();
		
		walk(path, conversionFilenames);	
		
		if (conversionFilenames.size() == 0) 
			System.out.println("No conversion file under " + path);
		
		// walk through conversion file
		for (int counter = 0; counter < conversionFilenames.size(); counter++) { 
			
			// read conversion file
			String filename = conversionFilenames.get(counter);
			
			if (filename.contains(fileDir))	message.add("Conversion file: \n  " + filename.substring(filename.indexOf(fileDir)) + "\n"); 
			else							message.add("Conversion file: \n  " + filename + "\n"); 
	          
			ArrayList <String[]> conversionFile = readCSVFile(filename);
	          
			// get column position may need to be updated in the conversion File, and new column need to add

	        // header of conversion file
	        String[] headers = conversionFile.get(0);
	        
      	  	// Find IRI column in the conversion file
      	  	int iriPos = -1;
      	  	
  	  		for (int n = 0; n < headers.length; n++) {
  	  			if (headers[n].equalsIgnoreCase("IRI")) {
  	  				iriPos = n;
  	  				break;
  	  			} 
  	  		}
  	  		
  	  		if (iriPos < 0) {
  	  			message.add("WARNING: The conversion file does not have IRI column, cannot update automatically\n----------------\n\n");
  	  		} 
  	  		else {	        
  	  			Hashtable<String, Integer> updateColumn = new Hashtable<String, Integer>();
	        
  	  			ArrayList <String> newColHeaders = new ArrayList <String>();
	          
  	  			for (int m = 1; m < replaceHeaders.length; m ++) {
  	  				boolean newCol = true;
      	  		
  	  				String cname = replaceHeaders[m];
   
  	  				for (int n = 0; n < headers.length; n++) {
  	  					if (cname.equalsIgnoreCase(headers[n])) {
  	  						updateColumn.put(cname, new Integer(n));
  	  						newCol = false;
  	  						break;
  	  					}
  	  				}
      	  		
  	  				if (newCol) {
  	  					if (cname.equalsIgnoreCase("new IRI"))	updateColumn.put("IRI", new Integer(iriPos));
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
				
  	  				if (replaceObjects.containsKey(iri)) {
  	  					int rowNum = l + 1;
  	  					

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
					
  	  					conversionFile.set(l,row);
					
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
  	  								
  	  								update = true;;
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
  	  			}	
	  		
  	  			if (update) {
  	  				String outFilename = filename.substring(0, filename.length()-4) + "_temp.csv";
  	  					  		
  	  				writeCSVfile(outFilename, conversionFile, newColumn);
	  			
  	  				if (outFilename.contains(fileDir))	message.add("\n\nwrite updated file to: \n  " + outFilename.substring(outFilename.indexOf(fileDir)) + "\n---------------\n\n"); 
  	  				else								message.add("\n\nwrite updated file to: \n  " + outFilename + "\n---------------\n\n"); 

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
	
	public static ArrayList <String[]> readTabFile (String inputFile) {
		System.out.println("Input is a tab-delimited file");

		ArrayList <String[]> matrix = new ArrayList <String[]> ();
		
		BufferedReader br = null;
		try {
			br = new BufferedReader(new FileReader(inputFile));
			String line = null;

			while( (line = br.readLine()) != null)
			{
				// comment line start with ##, will be ignored
				if (!(line.trim().startsWith("##") || line.trim().length()==0)) {
					String[] items = line.split("\t");
					for (int i = 0; i<items.length; i++)	items[i] = cleanString(items[i]);
					matrix.add(items);
				}
			}
			System.out.println("Successfully read input text file: " + inputFile);
		} catch (FileNotFoundException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		} finally {
			try {
				if ( br != null ) br.close();
			}
			catch (IOException ex) {
				ex.printStackTrace();
			}
		}

		return matrix;
	}	

	@SuppressWarnings("resource")
	public static ArrayList <String[]> readCSVFile (String inputFile) {
		//System.out.println("Read file: " + inputFile +"\n");

		ArrayList <String[]> matrix = new ArrayList <String[]> ();
		
		try {
            	CSVReader csvReader = new CSVReader(Files.newBufferedReader(Paths.get(inputFile), StandardCharsets.UTF_8));

            	String[] row;
            	while ((row = csvReader.readNext()) != null) {  
            		for (int i = 0; i<row.length; i++)	row[i] = cleanString(row[i]);
            		matrix.add(row);
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
