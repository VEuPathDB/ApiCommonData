package conversionFileUpdater;

import org.kohsuke.args4j.Option;

/**
 *  Process arguments passed from command line for OWLconversionUpdater.java
 *
 *  @author Jie Zheng
 *  University of Pennsylvania <br>
 * 	Date: April-18-2021 <br>
 */
public class OWLconversionUpdaterOptions {
    @Option(name="-path", 
    		usage ="Directory that contains the files for updating", 
    		required = false)
    private String path = "/Users/jiezheng/Documents/VEuPathDB-git/ApiCommonData/Load/ontology/";

    @Option(name="-input", 
    		usage ="filename including full path that contains the term ID with associated updating information", 
    		required = false)
    private String input = "/Users/jiezheng/Documents/VEuPathDB-git/ApiCommonData/Load/ontology/conversionUpdate/replace_EDA.csv";
    
    @Option(name="-messageFilename", 
    		usage ="filename including full path used to write the message regarding conversion file updates", 
    		required = false)
    private String messageFilename = "/Users/jiezheng/Documents/VEuPathDB-git/ApiCommonData/Load/ontology/conversionUpdate/message.txt";    

    public String getPath () {
    	return this.path;
    }
    
    public String getInput () {
    	return this.input;
    }
    
    public String getMessageFilename () {
    	return this.messageFilename;
    }
}
