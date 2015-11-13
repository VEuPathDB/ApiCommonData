package org.apidb.dataload;

import java.io.IOException;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.Options;
import org.gusdb.fgputil.CliUtil;
import org.gusdb.fgputil.runtime.GusHome;
import org.gusdb.fgputil.xml.XmlParser;
import org.gusdb.fgputil.xml.XmlValidator;
import org.xml.sax.SAXException;

public class ResourceXmlValidator extends XmlParser {

  private final XmlValidator _validator;
  
  public ResourceXmlValidator() throws SAXException, IOException {
    _validator = new XmlValidator(GusHome.getGusHome() + "/lib/rng/resources.rng");
  }

  public void validateResourcesXml(String xmlFileName) throws Exception {
    if (!_validator.validate(GusHome.getGusHome() + "/" + xmlFileName)) {
      throw new Exception("validation failed.");
    }
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
}
