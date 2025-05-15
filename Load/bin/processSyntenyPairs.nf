#!/usr/bin/env nextflow

nextflow.enable.dsl=2

process runPlugins {
  input:
  path(pair_dir)
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
  echo ga GUS::Supported::Plugin::InsertExternalDatabase --name '$databaseName' --gusConfigFile $gusConfigFile --commit
  echo ga GUS::Supported::Plugin::InsertExternalDatabaseRls --databaseName '$databaseName' --databaseVersion '$databaseVersion' --commit
  echo ga ApiCommonData::Load::Plugin::InsertSyntenySpans --writeSqlldrFiles \\
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


workflow {
  filterPairsDir(params.mercatorPairsDir, params.gusConfigFile)

  pairs_ch = filterPairsDir.out
    .splitText() {v -> params.mercatorPairsDir + "/" + v }

  runPlugins(pairs_ch, params.gusConfigFile)
  
  


  
  
}
