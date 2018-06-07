#' nice_dir
#' 
#' A little function to help deal with that fucking '/'
#' 
#' @param x character. A character string representing a directory location.
#' @param sep character. What separates the directory from the file name. Defaults
#' to '/'
#' @return 
nice_dir <- function(x, sep="/") paste0(dirname(x), sep, basename(x))

#' create_full_paths
#' 
#' A helper to create consistent full file paths when given a base directory and
#' some file paths.
#' 
#' @param paths character. A character string representing a directory location.
#' @param root character. What separates the directory from the file name. Defaults
#' to '/'
#' @return 
create_full_paths <- function(paths, root) nice_dir(root) %>% paste0("/",paths)


#' hijack
#' 
#' Inspired from: https://www.r-bloggers.com/hijacking-r-functions-changing-default-arguments/
#' Helps reset the default arguments for functions
#' 
#' @param fun function. A function you wish to stub out default options on. 
#' @param ... character. A named vector where the names correspond to function
#' arguments and the value corresponds to the default value you wish to insert.
#'
#' @return Returns a copy of the input, but with the new default values specified
#' by the \code{...} 
hijack <- function (fun, ...) {
  #
  .fun <- fun
  args <- c(...) %>% {.[intersect(names(.), names(formals(fun)))]}
  invisible(lapply(
     seq_along(args)
    ,function(i) {formals(.fun)[[names(args)[i]]] <<- args[[i]]}
  ))
  .fun
}

#' list_merge
#'
#' A tool to combine two lists. 
#' 
#' @param list1 named list.
#' @param list2 named list.
#'
#' @return A list with all values from \code{list1} and any values from 
#' \code{list2} not specified by \code{list1}
list_merge <- function(list1, list2){
  list1 %>%
    append(list2[setdiff(names(list2),names(list1))])
}