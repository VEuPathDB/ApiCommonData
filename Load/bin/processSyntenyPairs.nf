#!/usr/bin/env nextflow

nextflow.enable.dsl=2


workflow {
  filterPairsDir(params.mercatorPairsDir, params.gusConfigFile)

  pairs_ch = filterPairsDir.out
    .splitText() {v -> params.mercatorPairsDir + "/" + v }

  runPlugins(pairs_ch, params.gusConfigFile)
}


process filterPairsDir {
  input:
  path inputDir
  path gusConfigFile

  output:
  path("pairs.txt")

  shell:
  """
  filterSyntenyPairsDirectory.pl --pairDir $inputDir --gusConfigFile $gusConfigFile --outputFile pairs.txt
  """
}

process runPlugins {
  maxForks 20

  input:
  path(pair_dir)
  path gusConfigFile
  
  script:
  def pairName = pair_dir.baseName
  def databaseName = pairName + "_Mercator_synteny"
  def databaseVersion = "dontcare"
  """
  ga GUS::Supported::Plugin::InsertExternalDatabase --name '$databaseName' --gusConfigFile $gusConfigFile --commit
  ga GUS::Supported::Plugin::InsertExternalDatabaseRls --databaseName '$databaseName' --databaseVersion '$databaseVersion' --commit
  ga ApiCommonData::Load::Plugin::InsertSyntenySpans --loadWithPsql \\
                                                     --inputDirectory $pair_dir \\
                                                     --outputSyntenyDatFile synteny.dat \\
                                                     --outputSyntenicGeneDatFile syntenic_gene.dat \\
                                                     --syntenyDbRlsSpec '$databaseName|dontcare' \\
                                                     --gusConfigFile $gusConfigFile \\
                                                     --commit
  """
}
