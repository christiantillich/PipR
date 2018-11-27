#' pipe
#' 
#' The master function for PipR. Reads a yaml file and interprets it as 
#' instructions for transforming a series of data sets, creating snapshots of
#' those changes, and then applying checks to those snapshots for QA. 
#'
#' @param path character. The path to your PipR pipeline
#' @param only integer. A vector representing which steps of the pipeline to run.
#' @param run_pipe logical. Controls whether to run the pipeline. Set to FALSE
#' to run checks only.
#' @param run_checks logical. Controls whether to run checks. Set to FALSE to
#' just run the pipeline without checking the output (not recommended).
#' 
#' @return When \code{run_checks == TRUE}, \code{pipe} returns an s3 path 
#' where the check log is stored. When \code{run_checks == FALSE}, \code{pipe}
#' simply returns the list of files output by the model. Don't run with both
#' as \code{FALSE} what are you even doing?
#' 
#' @export
pipe <- function(path, only = NA, run_pipe = TRUE, run_checks = TRUE){
  
  if(!any(run_pipe, run_checks)){stop("Oh we found the funny guy.")}
  pipeline <- parse_pipe(path)
  if(is.na(only)){only <- 1:length(pipeline$steps)}
  execution_variables <- list(run_pipe = run_pipe, run_checks = run_checks)
  
  out <- pipeline$steps %>%
    lapply(function(x) {x$checks <- list_merge(x$checks, pipeline$checks);x}) %>%
    lapply(function(x) list_merge(x, execution_variables)) %>%
    .[only] %>%
    lapply(function(x) do.call(run_step, x))
  
  if(run_checks == TRUE){
    out %<>% 
      lapply(function(x){x$step <- which(sapply(out, function(y) identical(x,y))); x}) %>%
      bind_rows %>% 
      {.[,union(c('step','description','path'), colnames(.))]} %>%
      .PipR_Env$writer(paste0(nice_dir(get_configs()$s3_dir), '/log'))
  }
  
  remove_env()
  return(out)
}


#' run_step
#' 
#' Processes a single step in the pipeline. Runs the step, if applicable. Runs
#' checks, if applicable. 
#'
#' @param transform list. A named list of characters. The first element should
#' be the function name. All other elements optional parameters into the function.
#' @param type character. The type of transformation done for this step. Can
#' be one of five values: 
#' '0f1' - For functions with no input sets, creating one output set. 
#' '0fM' - For functions with no input sets, creating multiple output sets. Sets
#' must be returned in the same order that they're named in the pipeline.
#' '1f1' - For functions with one input set and one output set. 
#' '1fM' - For functions with one input set and multiple output sets. Sets must
#' be returned in the same order that they're named in the pipeline.
#' 'Mf1' - For functions requiring multiple input sets, but producing only one 
#' output set. Sets must be input in the order that they will be passed into the
#' transformation function.
#' 'MfM' - For functions with multiple inputs and multiple outputs. Input and 
#' output sets must be the same length. Element one of the input set produces
#' element one of the output set. 
#' @param inpaths character. A vector of one or more of the set names used as
#' inputs to this step.
#' @param outpaths character. A vector of one or more of the set names created
#' by this step. 
#' @param ... list. A list of optional parameters to be set as local configs for
#' that particular step. Any config not specified in the step gets set to the
#' global values for that config. 
#'
#' @return If \code{run_checks == FALSE}, the output is a list of the storage
#' paths created by the pipeline. If \code{run_checks == TRUE}, the output is
#' a dataframe listing each step, set created, and value for all check functions.
run_step <- function(transform, type, inpaths = "", outpaths = "", ...){
  
  lcl <- list_merge(list(...), as.list(get_configs()))
  
  inpaths <- create_full_paths(inpaths, lcl$s3_dir)
  outpaths <- create_full_paths(outpaths, lcl$s3_dir)
  
  
  #' Only run if run_pipe = TRUE
  func <- get_transforms()[[transform[[1]]]]
  if(length(transform) > 1){
    func <- hijack(func, transform[-1])
  }
  
  if(lcl$run_pipe){
    message(paste0("Running Step - ", lcl$description, "\n"))
    switch(
       type
      ,'0f1' = map_0f1(func, outpaths, lcl$writer)
      ,'0fM' = map_0fM(func, outpaths, lcl$writer)
      ,'1f1' = map_1f1(inpaths, outpaths, func, lcl$reader, lcl$writer)
      ,'1fM' = map_1fM(inpaths, outpaths, func, lcl$reader, lcl$writer)
      ,'Mf1' = map_Mf1(inpaths, outpaths, func, lcl$reader, lcl$writer)
      ,'MfM' = map_MfM(inpaths, outpaths, func, lcl$reader, lcl$writer)
      ,stop("Step type must be specified as one of type 0f1, 0fM, 1f1, 1fM, Mf1, or MfM")
    )
  }
  
  if(lcl$run_checks){
    message(paste0("Checking Step - ", lcl$description, "\n"))
    run_all_checks(outpaths, lcl$checks, lcl[setdiff(names(lcl),'checks')])
  }
  #' Only run if run_checks = TRUE
    #' Function run_all_checks will take in list of outpaths and list of checks
}


### Mapping functions

#' map_0f1
#'
#' @param transform function. The transformation function to be applied.
#' @param outpath character. A character string representing a single path. The
#' transformed data set is written out to this path. 
#' @param writer. The function used to write the data set to the target location.
#' @return Returns the outpath. 
map_0f1 <- function(transform, outpath, writer){
  df <- transform()
  writer(df, outpath)
  return(outpath)
}

#' map_0fM
#'
#' @param transform function. The transformation function to be applied.
#' @param outpaths character. A character vector representing multiple output
#' paths, which each output set will be written to. 
#' @param writer. The function used to write the data set to the target location.
#' @return Returns the outpaths
map_0fM <- function(transform, outpaths, writer){
  dfs <- transform()
  check_multiple_outs(dfs, outpaths)
  mapply(writer, dfs, outpaths)
  return(outpaths)
}

#' map_1f1
#'
#' @param transform function. The transformation function to be applied.
#' @param inpath character. A character string representing a single path. The
#' raw data set is read in from this path.
#' @param outpath character. A character string representing a single path. The
#' transformed data set is written out to this path. 
#' @param writer. The function used to write the data set to the target location.
#' @return Returns the outpath
map_1f1 <- function(inpath, outpath, transform, reader, writer){
  df <- reader(inpath) %T>% check_if_data
  writer(transform(df), outpath)
  return(outpath)
}

#' map_1fM
#'
#' @param transform function. The transformation function to be applied.
#' @param inpath character. A character string representing a single path. The
#' raw data set is read in from this path.
#' @param outpaths character. A character vector representing multiple output
#' paths, which each output set will be written to. 
#' @param writer. The function used to write the data set to the target location.
#' @return Returns the outpaths
map_1fM <- function(inpath, outpaths, transform, reader, writer){
  df <- reader(inpath) %T>% check_if_data
  out <- transform(df)
  check_multiple_outs(out, outpaths)
  mapply(writer, out, outpaths)
  return(outpaths)
}

#' map_Mf1
#' 
#' @param transform function. The transformation function to be applied.
#' @param inpaths character. A character string representing multiple input
#' paths. The raw data is read in from each path and stored as a list.
#' @param outpath character. A character string representing a single path. The
#' transformed data set is written out to this path. 
#' @param writer. The function used to write the data set to the target location.
#' @return Returns the outpath
map_Mf1 <- function(inpaths, outpath, transform, reader, writer){
  dfs <- lapply(inpaths, reader) %T>% lapply(check_if_data)
  writer(do.call(transform, dfs), outpath)
  return(outpath)
}

#' map_MfM
#' @details MfM is simply a linear mapping between the input and output. MfM 
#' is simply using `lapply` the transform against the input dataframes. 
#' @param transform function. The transformation function to be applied.
#' @param inpaths character. A character string representing multiple input
#' paths. The raw data is read in from each path and stored as a list.
#' @param outpaths character. A character vector representing multiple output
#' paths, which each output set will be written to.
#' @param writer. The function used to write the data set to the target location.
#' @return Returns the outpaths
map_MfM <- function(inpaths, outpaths, transform, reader, writer){
  dfs <- lapply(inpaths, reader) %T>% lapply(check_if_data)
  out <- lapply(dfs, transform)
  mapply(writer, out, outpaths)
  return(outpaths)
}


#' map_MbM
#' @details MbM (the "b" stands for blend) assumes the inputs will be combined
#' in an arbitrary fashion by the transform. The input sets are fed to the 
#' transform via `do.call`, and the user should ensure that the output sets
#' are named in the order that the transform returns them. 
#' @param inpaths character. A character string representing multiple input
#' paths. The raw data is read in from each path and stored as a list.
#' @param outpaths character. A character vector representing multiple output
#' paths, which each output set will be written to.
#' @param transform function. The transformation function to be applied.
#' @param reader function. The function used to read the data set to the target location.
#' @param writer function. The function used to write the data set to the target location.
#' @return
map_MbM <- function(inpaths, outpaths, transform, reader, writer){
  dfs <- lapply(inpaths, reader) %T>% lapply(check_if_data)
  out <- do.call(transform, dfs)
  mapply(writer, out, outpaths)
  return(outpaths)
}

#Sanity Checks

#' check_multiple_outs
#'
#' @param data_sets list. A list of data.frame objects. 
#' @param paths list. A list of paths. 
#' @return Returns NULL. Will error if \code{length(data_sets) != length(paths)}
check_multiple_outs <- function(data_sets, paths){
  if(length(data_sets) != length(paths)){ 
    stop("Count mismatch between data sets and ouput paths")
  }
}

#' check_if_data
#'
#' @param df any. But will error if not of type data.frame
#' @return Returns NULL. Will error if \code{df} is not class \code{data.frame}
check_if_data <- function(df){
  if(!('data.frame' %in% class(df))){
    stop("Error. The s3 path you requested did not return a data frame.")
  }
}