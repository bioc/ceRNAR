#'
#' @name ceRNAIntergate
#' @title Integration of the possible ceRNA pairs among published tools
#' @description A function to integrate the possible ceRNA pairs that are found
#' by ceRNAR algorithm with those from other tools, such as SPONGE (List et al.,
#' 2019) and RJAMI (Hornakova et al.,2018)
#'
#' @import foreach
#' @import future
#' @import utils
#' @import GDCRNATools
#' @importFrom gRbase combn_prim
#' @importFrom dplyr select
#' @importFrom cvms font
#' @importFrom randomForest margin
#' @importFrom randomForest combine
#' @importFrom rlang exprs
#' @rawNamespace import(ggpubr, except=font)
#'
#' @param path_prefix user's working directory
#' @param project_name the project name that users can assign
#' @param disease_name the abbreviation of disease that users are interested in
#'
#' @return a dataframe object
#' @export
#'
#' @examples
#' library(SPONGE)
#' ceRNAIntegrate(
#' path_prefix = NULL,
#' project_name = 'demo',
#' disease_name = 'DLBC'
#' )
#'

ceRNAIntegrate <- function(path_prefix = NULL,
                           project_name = 'demo',
                           disease_name = 'DLBC'){

  if (is.null(path_prefix)){
    path_prefix <- fs::path_home()
  }else{
    path_prefix <- path_prefix
  }

  if (!stringr::str_detect(path_prefix, '/$')){
    path_prefix <- paste0(path_prefix, '/')
  }

  time1 <- Sys.time()
  #setwd(paste0(project_name,'-',disease_name))

  if(!dir.exists(paste0(path_prefix, project_name,'-',disease_name,'/04_downstreamAnalyses/'))){
    dir.create(paste0(path_prefix, project_name,'-',disease_name,'/04_downstreamAnalyses/'))
  }

  if(!dir.exists(paste0(path_prefix, project_name,'-',disease_name,'/04_downstreamAnalyses/integration/'))){
    dir.create(paste0(path_prefix, project_name,'-',disease_name,'/04_downstreamAnalyses/integration/'))
  }

  message('\u25CF Step 5: Dowstream Analyses - Integration')

  dict <- readRDS(paste0(path_prefix, project_name,'-',disease_name,'/02_potentialPairs/',project_name,'-',disease_name,'_MirnaTarget_dictionary.rds'))
  mirna <- data.frame(data.table::fread(paste0(path_prefix, project_name,'-',disease_name,'/01_rawdata/',project_name,'-',disease_name,'_mirna.csv')),row.names = 1)
  mrna <- data.frame(data.table::fread(paste0(path_prefix, project_name,'-',disease_name,'/01_rawdata/',project_name,'-',disease_name,'_mrna.csv')),row.names = 1)
  d <- as.data.frame(matrix(0,nrow = dim(mrna)[1], ncol = dim(mirna)[1]))
  names(d) <- row.names(mirna)
  row.names(d) <- row.names(mrna)
  for (i in 1:dim(dict)[1]){
    #i=1
    gene_pair <- dict[i,][[2]]
    d[gene_pair,i] <- 1
  }

  chk <- Sys.getenv("_R_CHECK_LIMIT_CORES_", "")

  if ((nzchar(chk)) && (chk == "TRUE")) {
    # use 2 cores in CRAN/Travis/AppVeyor
    num_workers <- 2L
    # use 1 cores in CRAN/Travis/AppVeyor
    num_workers <- 1L
  } else {
    # use all cores in devtools::test()
    num_workers <- availableCores()-2
  }

  doParallel::registerDoParallel(num_workers)

  mir_expr <- t(mirna)
  gene_expr <- t(mrna)
  genes_miRNA_candidates <- SPONGE::sponge_gene_miRNA_interaction_filter(
    gene_expr = gene_expr,
    mir_expr = mir_expr,
    mir_predicted_targets = as.matrix(d))

  ceRNA_interactions <- SPONGE::sponge(gene_expr = gene_expr,
                               mir_expr = mir_expr,
                               mir_interactions = genes_miRNA_candidates)
  precomputed_cov_matrices <- SPONGE::precomputed_cov_matrices
  mscor_null_model <- SPONGE::sponge_build_null_model(number_of_datasets = 100,
                                              number_of_samples = dim(gene_expr)[1])
  sponge_result <- SPONGE::sponge_compute_p_values(sponge_result = ceRNA_interactions,
                                                   null_model = mscor_null_model)
  sponge_result_sig <- sponge_result[sponge_result$p.adj<=0.05,]
  if(dim(sponge_result_sig)[1]!=0){
    sponge_result_sig$genepairs_1 <- paste0(sponge_result_sig$geneA, '|', sponge_result_sig$geneB)
    sponge_result_sig$genepairs_2 <- paste0(sponge_result_sig$geneB, '|', sponge_result_sig$geneA)

  }


  # JAMI (not on CRAN or Bioconductor)
  # mir_exp <- mirna
  # gene_exp <- mrna
  # df_lst <- list()
  # for (i in 1:dim(dict)[1]){
  #   #i=1
  #   gene_pair <- dict[i,][[2]]
  #   tmp <- as.data.frame(t(utils::combn(gene_pair,2)))
  #   tmp$V3<- dict[i,][[1]]
  #   df_lst[[i]] <- tmp
  # }
  # gene_mir_interactions_triplets <- Reduce(rbind, df_lst)
  # names(gene_mir_interactions_triplets) <- c('geneA','geneB','mirnas')
  # RJAMI::test_jvm()
  # RJAMI::jami_settings(pvalueCutOff = 0.05)
  # RJAMI::jami_settings(tripleFormat = FALSE)
  # result <- RJAMI::jami(gene_miRNA_interactions = gene_mir_interactions_triplets,
  #                       gene_expr = gene_exp,
  #                       mir_expr = mir_exp)
  # rjami_result <- result$result[,1:5]
  # rjami_result_sig <- rjami_result[rjami_result$p.value <=0.05,]
  # rjami_result_sig$triplets <- paste0(rjami_result_sig$miRNA,'|',rjami_result_sig$Source, '|', rjami_result_sig$Target)
  # utils::write.csv(sponge_result_sig, paste0(path_prefix, project_name,'-',disease_name,'/04_downstreamAnalyses/integration/',project_name,'-',disease_name,'_jami.csv'), row.names = FALSE)

  # GDCRNATools
  mir_exp <- mirna
  gene_exp <- mrna
  tmp <- list()
  for (i in 1:dim(dict)[1]){
    #i=1

    gene_pair <- dict[i,][[2]]
    tmp1 <- as.list(rep(dict[i,][[1]],times=length(gene_pair)))
    names(tmp1) <- gene_pair
    tmp <- append(tmp, tmp1)
  }

  gene_target_lst <- tmp
  ceOutput_list <- list()
  for (k in 1:dim(gene_exp)[1]){
    #k = 10
    ceOutput_tmp = tryCatch({
      GDCRNATools::gdcCEAnalysis(lnc = row.names(gene_exp)[k],
                                 pc= row.names(gene_exp)[-k],
                                 lnc.targets = gene_target_lst,
                                 pc.targets = gene_target_lst,
                                 rna.expr = gene_exp,
                                 mir.expr = mir_exp)%>%
        suppressMessages()
    }, error = function(e) {})
    ceOutput_list[[k]] <- ceOutput_tmp
  }

  ceOutput <- Reduce(rbind,ceOutput_list)
  ceOutput_sig <- ceOutput[ceOutput$hyperPValue<=0.05,]
  if(dim(ceOutput_sig)[1]!=0){
    ceOutput_sig$genepairs_1 <- paste0(ceOutput_sig$lncRNAs, '|', ceOutput_sig$Genes)
    ceOutput_sig$genepairs_2 <- paste0(ceOutput_sig$Genes, '|', ceOutput_sig$lncRNAs)
  }

  # our results
  our_result <- as.data.frame(utils::read.csv(paste0(path_prefix, project_name,'-',disease_name,'/',project_name,'-',disease_name,'_finalpairs.csv')))
  cand_pair <- Reduce(rbind,stringr::str_split(our_result$cand.ceRNA,' '))
  our_result <- cbind(our_result[,1:2],cand_pair)
  our_result <- our_result[,-2]
  names(our_result)[2:3] <- c("geneA","geneB")
  our_result$triplets <- paste0(our_result$miRNA,'|', our_result$geneA, '|', our_result$geneB)
  our_result$genepairs <- paste0(our_result$geneA, '|', our_result$geneB)

  # integrate
  if(dim(sponge_result_sig)[1]!=0){
    sponge_integrate <- c(intersect(our_result$genepairs,sponge_result_sig$genepairs_1),intersect(our_result$genepairs,sponge_result_sig$genepairs_2))
    our_result$sponge <- '-'
    our_result$sponge[our_result$genepairs%in%sponge_integrate] <- 'yes'
  }else{
    our_result$sponge <- '-'
  }

  # rjami_integrate <- intersect(our_result$triplets,rjami_result_sig$triplets)
  # our_result$rjami <- '-'
  # our_result$rjami[our_result$triplets%in%rjami_integrate] <- 'yes'

  if(dim(ceOutput_sig)[1]!=0){
    GDCRNATools_integrate <- c(intersect(our_result$genepairs,ceOutput_sig$genepairs_1),intersect(our_result$genepairs,ceOutput_sig$genepairs_2))
    our_result$GDCRNATools <- '-'
    our_result$GDCRNATools[our_result$genepairs%in%GDCRNATools_integrate] <- 'yes'
  }else{
    our_result$GDCRNATools <- '-'
  }

  utils::write.csv(our_result, paste0(path_prefix, project_name,'-',disease_name,'/04_downstreamAnalyses/integration/',project_name,'-',disease_name,'_integrate.csv'), row.names = FALSE)
  time2 <- Sys.time()
  diftime <- difftime(time2, time1, units = 'min')
  message(paste0('\u2605 Consuming time: ',round(as.numeric(diftime)), ' min.'))
  message('\u2605\u2605\u2605 All analyses has completed! \u2605\u2605\u2605')

  return(our_result)
}

