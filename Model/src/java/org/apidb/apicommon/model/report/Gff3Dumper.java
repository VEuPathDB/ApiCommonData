/**
 * 
 */
package org.apidb.apicommon.model.report;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.security.NoSuchAlgorithmException;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactoryConfigurationError;

import org.apache.log4j.Logger;
import org.gusdb.wdk.model.AnswerValue;
import org.gusdb.wdk.model.Question;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.report.Reporter;
import org.json.JSONException;
import org.xml.sax.SAXException;

/**
 * @author xingao
 * 
 */
public class Gff3Dumper {

    private static final Logger logger = Logger.getLogger(Gff3Dumper.class);

    /**
     * @param args
     * @throws WdkModelException
     * @throws WdkUserException
     * @throws IOException
     * @throws ClassNotFoundException
     * @throws IllegalAccessException
     * @throws InstantiationException
     * @throws JSONException
     * @throws SQLException
     * @throws SAXException
     * @throws TransformerException
     * @throws TransformerFactoryConfigurationError
     * @throws ParserConfigurationException
     * @throws NoSuchAlgorithmException
     */
    public static void main(String[] args) throws WdkModelException,
            WdkUserException, IOException, NoSuchAlgorithmException,
            ParserConfigurationException, TransformerFactoryConfigurationError,
            TransformerException, SAXException, SQLException, JSONException,
            InstantiationException, IllegalAccessException,
            ClassNotFoundException {
        if (args.length != 4 && args.length != 6) {
            System.err.println("Invalid parameters.");
            printUsage();
            System.exit(-1);
        }
        Map<String, String> cmdArgs = new HashMap<String, String>();
        for (int i = 0; i < args.length - 1; i += 2) {
            cmdArgs.put(args[i].trim().toLowerCase(), args[i + 1].trim());
        }

        // get params
        String modelName = cmdArgs.get("-model");
        String organismArg = cmdArgs.get("-organism");
        String baseDir = cmdArgs.get("-dir");
        if (modelName == null || organismArg == null) {
            System.err.println("Missing parameters.");
            printUsage();
            System.exit(-1);
        }
        if (baseDir == null || baseDir.length() == 0) baseDir = ".";

        // TEST
        logger.info("Initializing....");

        // load config
        Map<String, String> config = new LinkedHashMap<String, String>();
        config.put(Reporter.FIELD_FORMAT, "text");

        // construct wdkModel
        String gusHome = System.getProperty(Utilities.SYSTEM_PROPERTY_GUS_HOME);
        WdkModel wdkModel = WdkModel.construct(modelName, gusHome);

        String[] organisms = organismArg.split(",");
        for (String organism : organisms) {
            dumpOrganism(wdkModel, organism.trim(), config, baseDir);
        }
        System.out.println("Finished.");
    }

    private static void dumpOrganism(WdkModel wdkModel, String organism,
            Map<String, String> config, String baseDir)
            throws WdkUserException, WdkModelException, IOException,
            NoSuchAlgorithmException, SQLException, JSONException {
        long start = System.currentTimeMillis();

        // decide the path-file name
        logger.info("Preparing gff file....");
        File dir = new File(baseDir, organism.replace(' ', '_'));
        if (!dir.exists() || !dir.isDirectory()) dir.mkdirs();
        int pos = organism.indexOf(" ");
        String fileName = organism;
        if (pos >= 0)
            fileName = organism.substring(0, 1).toLowerCase() + "_"
                    + organism.substring(pos + 1);
        fileName += ".gff";
        File gffFile = new File(dir, fileName);
        PrintWriter writer = new PrintWriter(new FileWriter(gffFile));

        // prepare reporters
        logger.info("Preparing reporters....");

        Map<String, String> params = new LinkedHashMap<String, String>();
        params.put("gff_organism", organism);

        Question seqQuestion = (Question) wdkModel.resolveReference("SequenceDumpQuestions.SequenceDumpQuestion");
        AnswerValue sqlAnswer = seqQuestion.makeAnswerValue(params);
        Gff3Reporter seqReport = (Gff3Reporter) sqlAnswer.createReport("gff3",
                config);

        Question geneQuestion = (Question) wdkModel.resolveReference("GeneDumpQuestions.GeneDumpQuestion");
        AnswerValue geneAnswer = geneQuestion.makeAnswerValue(params);
        config.put(Gff3Reporter.FIELD_HAS_PROTEIN, "yes");
        Gff3Reporter geneReport = (Gff3Reporter) geneAnswer.createReport(
                "gff3Dump", config);

        // collect the header from sequence reporter
        logger.info("Collecting header....");
        seqReport.writeHeader(writer);

        // collect the sequence records
        logger.info("Collecting sequence records....");
        seqReport.writeRecords(writer);

        // collect the gene records
        logger.info("Collecting gene records....");
        geneReport.writeRecords(writer);

        // collect the protein sequences
        logger.info("Collecting protein sequences....");
        writer.println("##FASTA");
        geneReport.writeSequences(writer);

        // collect the genomic sequences
        logger.info("Collecting genomic sequences....");
        seqReport.writeSequences(writer);

        writer.flush();
        writer.close();

        long end = System.currentTimeMillis();
        System.out.println("GFF3 file saved at " + gffFile.getAbsolutePath()
                + ".");
        logger.info("Time spent " + ((end - start) / 1000.0) + " seconds.");
    }

    public static void printUsage() {
        System.out.println();
        System.out.println("Usage: gff3Dump -model <model_name> -organism "
                + "<organism_list> [-dir <base_dir>]");
        System.out.println();
        System.out.println("\t\t<model_name>:\tThe name of WDK supported model;");
        System.out.println("\t\t<organism_list>: a list of organism names, "
                + "delimited by a comma;");
        System.out.println("\t\t<base_dir>: Optional, the base directory for "
                + "the output files. If not specified, the current directory "
                + "will be used.");
        System.out.println();
    }
}
