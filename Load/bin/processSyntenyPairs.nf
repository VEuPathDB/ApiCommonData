#!/usr/bin/env nextflow

nextflow.enable.dsl=2

process preprocessPair {
  input:
  path pair_dir
  path gusConfigFile

  output:
  tuple path(pair_dir), path("readyToLoad"), optional: true 
  
  shell:
  """
  processSynteny --pairDir $pair_dir --gusConfigFile $gusConfigFile --outputFile readyToLoad 
  """
}

process runPlugins {
  input:
  tuple path(pair_dir), path("readyToLoad")
  path gusConfigFile
  
  output:
  path 'synteny.dat'
  path 'synteny.dat.ctrl'
  path 'syntenic_gene.dat'
  path 'syntenic_gene.dat.ctrl'

  script:
  def pairName = pair_dir.baseName
  def databaseName = pairName + "_Mercator_synteny"
  def databaseVersion = "dontcare"
  """
  ga GUS::Supported::Plugin::InsertExternalDatabase --name '$databaseName' --gusConfigFile $gusConfigFile --commit
  ga GUS::Supported::Plugin::InsertExternalDatabaseRls --databaseName '$databaseName' --databaseVersion '$databaseVersion' --commit
  ga ApiCommonData::Load::Plugin::InsertSyntenySpans --writeSqlldrFiles \\
                                                          --inputDirectory $pair_dir \\
                                                          --outputSyntenyDatFile synteny.dat \\
                                                          --outputSyntenyCtrlFile synteny.dat.ctrl \\
                                                          --outputSyntenicGeneDatFile syntenic_gene.dat \\
                                                          --outputSyntenicGeneCtrlFile syntenic_gene.dat.ctrl \\
                                                          --syntenyDbRlsSpec '$databaseName|dontcare'
  """
}
// process loader {
//   input:
//   file synteny_dat_ch
//   file synteny_ctrl_ch
//   file syntenic_gene_dat_ch
//   file syntenic_gene_ctrl_ch

//   shell:
//   '''
//   runSqlldr --ctrlFile !{synteny_ctrl_ch} --silent ALL --errors 0
//   runSqlldr --ctrlFile !{syntenic_gene_ctrl_ch} --silent ALL --errors 0
//   '''
// }


workflow {
  mercatorPairDirectories = Channel.fromPath(params.mercatorPairsDir + '/**', type: 'dir', maxDepth: 0)

  preprocessPair(mercatorPairDirectories, params.gusConfigFile)

  runPlugins(preprocessPair.out, params.gusConfigFile)


  
  
}
