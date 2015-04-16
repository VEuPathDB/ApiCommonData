package org.apidb.dataload;

import java.io.IOException;
import java.net.URL;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.Options;
import org.apache.commons.digester.Digester;
import org.gusdb.fgputil.CliUtil;
import org.gusdb.fgputil.xml.XmlParser;

public class ResourceXmlValidator extends XmlParser {

  public ResourceXmlValidator() {
    super("lib/rng/resources.rng");
  }

  public void validateResourcesXml(String xmlFileName) throws IOException, Exception {
    configure();

    // construct urls to model file, prop file, and config file
    URL modelURL = makeURL(xmlFileName);

    if (!validate(modelURL))
      throw new Exception("validation failed.");
  }

  public static void main(String[] args) throws Exception {
    String cmdName = System.getProperty("cmdName");

    // process args
    Options options = declareOptions();
    String cmdlineSyntax = cmdName + " -f resources_xml_file";
    String cmdDescrip = "Validate a resources XML file against the RNG schema.";
    CommandLine cmdLine = CliUtil.parseOptions(cmdlineSyntax, cmdDescrip, "", options, args);
    String xmlFileName = cmdLine.getOptionValue("f");

    ResourceXmlValidator validator = new ResourceXmlValidator();
    validator.validateResourcesXml(xmlFileName);
  }

  private static Options declareOptions() {
    Options options = new Options();
    CliUtil.addOption(options, "f", "", true);
    return options;
  }

  @Override
  protected Digester configureDigester() {
    return null;
  }

}
