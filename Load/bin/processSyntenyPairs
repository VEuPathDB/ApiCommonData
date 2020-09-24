#!/usr/bin/env nextflow

Channel.fromPath(params.mercatorPairsDir + '/**', type: 'dir', maxDepth: 0).set{ directory_pairs_ch }

process processPairs {
  errorStrategy 'terminate'
  maxErrors 1
  input:
  file pair_dir from directory_pairs_ch

  output:
  file 'synteny.dat' into synteny_dat_ch
  file 'synteny.dat.ctrl' into synteny_ctrl_ch
  file 'syntenic_gene.dat' into syntenic_gene_dat_ch
  file 'syntenic_gene.dat.ctrl' into syntenic_gene_ctrl_ch

  shell:
  '''
  echo Running processSynteny --pair_dir !{params.mercatorPairsDir}/!{pair_dir}
  processSynteny --pair_dir !{params.mercatorPairsDir}/!{pair_dir}
  '''
}
process loader {
  errorStrategy 'terminate'
  maxErrors 1
  input:
  file synteny_dat_ch
  file synteny_ctrl_ch
  file syntenic_gene_dat_ch
  file syntenic_gene_ctrl_ch

  shell:
  '''
  runSqlldr --ctrlFile !{synteny_ctrl_ch} --silent ALL
  runSqlldr --ctrlFile !{syntenic_gene_ctrl_ch} --silent ALL
  '''
}
