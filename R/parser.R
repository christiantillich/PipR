#' read_pipe
#' 
#' Internal function just to read in the raw yaml.
#' 
#' @param path character. path to the pipeline file.
#' @return Output is a list structured in the same way as the pipeline file.
read_pipe <- function(path){yaml::yaml.load_file(path)}

#' parse_pipe
#' 
#' Input path to PipR pipeline, creates a config environment that PipR steps use
#' by default, and outputs the list of PipR steps with neat names.
#'
#' @param path 
#' @return Output is divided into two parts. Part one creates the environment 
#' \code{.PipR_Env} filled with the entries specified by config. Part two
#' returns a list object with two sections - \code{.$steps} and \code{.$checks}.
#' \code{parse_pipe()} also assigns the correct names to sections so \code{pipe()}
#' can read it properly.
parse_pipe <- function(path){
  pipeline <- read_pipe(path)
  
  make_env()
  list2env(as.list(pipeline$configs), envir = .PipR_Env)
  .PipR_Env$reader <- get(pipeline$configs$reader, envir = .GlobalEnv)
  .PipR_Env$writer <- get(pipeline$configs$writer, envir = .GlobalEnv)
  attach(.PipR_Env)
  
  nice_dir(get_configs()$local_dir) %>% 
    paste0(., '/', get_configs()$transform_files) %>%
    lapply(., function(x) source(x, local = get_configs()$transforms))
  
  nice_dir(get_configs()$local_dir) %>% 
    paste0(., '/', get_configs()$check_files) %>%
    lapply(., function(x) source(x, local = get_configs()$checks))
  
  names(pipeline$steps) <- lapply(pipeline$steps, function(x) x$description)
  names(pipeline$checks) <- lapply(pipeline$checks, function(x) x$func[[1]])
  pipeline$steps %<>% lapply(function(x) {
    try(names(x$checks) <- lapply(x$checks, function(y) y[[1]][[1]]), silent=T)
    x
  })
  
  pipeline %<>% {.[setdiff(names(.),'configs')]}
  pipeline
}



#' make_env
#' 
#' Internal function to set up the environments properly
#' 
#' @return Creates the \code{.PipR_Env} environment and child environments
make_env <- function(){
  remove_env()
  assign('.PipR_Env', new.env(), .GlobalEnv)
  assign('transforms', new.env(), .PipR_Env)
  assign('checks', new.env(), .PipR_Env)
}

#' remove_env
#'
#' Clears any environments created when using PipR
#' 
#' @return Simply removes \code{.PipR_Env} from the search path and deletes
#' it from memory.
remove_env <- function(){
  if (".PipR_Env" %in% search()) detach(".PipR_Env")
  if (exists(".PipR_Env")){
    base::rm(list = ls(.PipR_Env), envir = .PipR_Env)
    base::rm(.PipR_Env)
  }
}

#' get_configs
#'
#' Helper to access \code{.PipR_Env}
#' 
#' @return the \code{.PipR_Env} environment
get_configs <- function() .PipR_Env

#' get_tranforms
#'
#' Helper to pull a list of transforms from \code{.PipR_Env}
#' 
#' @return a list of transforms
get_transforms <- function() get_configs()$transforms

#' get_checks
#'
#' Helper to pull a list of checks from \code{.PipR_Env}
#' 
#' @return a list of checks
get_checks <- function() get_configs()$checks