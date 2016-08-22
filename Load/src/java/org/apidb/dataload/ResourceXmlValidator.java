package org.apidb.dataload;

import java.io.IOException;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.Options;
import org.gusdb.fgputil.CliUtil;
import org.gusdb.fgputil.xml.XmlValidator;
import org.xml.sax.SAXException;

public class ResourceXmlValidator {

  /**
   * Validates a resources XML file against the RNG schema
   * 
   * @param args should be a single-item array where the one item is the path to an XML file
   * @throws IOException if unable to read schema or XML files
   * @throws SAXException if input files are not valid XML
   */
  public static void main(String[] args) throws IOException, SAXException {
      XmlValidator validator = new XmlValidator("lib/rng/resources.rng");
      validator.validate(getFilenameFromArgs(args));
  }

  /**
   * Parse and validate command line arguments and extract passed filename
   * 
   * @param args command line arguments
   * @return filename input by user
   * @throws
   */
  private static String getFilenameFromArgs(String[] args) {
    Options options = new Options();
    CliUtil.addOption(options, "f", "", true);
    String cmdlineSyntax = System.getProperty("cmdName") + " -f resources_xml_file";
    String cmdDescrip = "Validate a resources XML file against the RNG schema.";
    CommandLine cmdLine = CliUtil.parseOptions(cmdlineSyntax, cmdDescrip, "", options, args);
    if (cmdLine == null) System.exit(1);
    return cmdLine.getOptionValue("f");
  }
}
