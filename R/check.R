

#' run_all_checks
#' 
#' Runs all specified checks at a particular step. 
#'
#' @param outpaths character. A character vector of one or more output paths 
#' produced by the pipeline. The data sets are read in from those paths for 
#' checks.
#' @param checks list. A character list, representing checks and possible input
#' parameters for that step.
#' @param lcl list. A list of the local configs at that step. Local configs are
#' specified in \code{run_step()} and replaced with global values as necessary.
#'
#' @return
run_all_checks <- function(outpaths, checks, lcl) {
  data_sets <- lapply(outpaths, function(x) get(lcl$reader)(x)) %>% 
    `names<-`(outpaths)
  
  lapply(outpaths, function(x) lapply(checks, function(y) run_check(data_sets[[x]],y,lcl,x))) %>%
    lapply(function(x) Reduce(function(y,z) merge(y,z,by=c('description','path')), x)) %>%
    bind_rows
}

 
#' run_check
#'
#' @param data data.frame. A data set to execute the check against.
#' @param check character. A character vector with the name of the function 
#' called, along with any possible input parameters. 
#' @param lcl list. A list of local configs for that step. 
#' @param outpath character. The path where the processed data was written to.
#' @return
run_check <- function(data, check, lcl, outpath) {
  func <- get_checks()[[check$func[[1]]]]
  if(length(check$func) > 1){
    func <- hijack(func, unlist(check$func[-1]))
  }
  out <- tryCatch(
     func(data)
    ,error = function(e) {warning("One of your check functions is erroring"); return()}
  )
  out %>% as.data.frame %>% check_is_data_frame %>%
    {bind_cols(data.frame(description = lcl$description, path = outpath), .)}
}


##### Sanity checks


#' check_is_data_frame
#'
#' A simple check, and error handling, for if something is written out as a 
#' non-data-frame erroneously. 
#' 
#' @param data any. But will error if it's not a data frame.#'
#' @return Simply returns the data set if it passes, or errors if it fails.
check_is_data_frame <- function(data){
  if(!('data.frame' %in% class(data))){
    stop("Check functions must output a dataframe.")
  }
  data
}