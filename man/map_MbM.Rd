% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/pipe.R
\name{map_MbM}
\alias{map_MbM}
\title{map_MbM}
\usage{
map_MbM(inpaths, outpaths, transform, reader, writer)
}
\arguments{
\item{inpaths}{character. A character string representing multiple input
paths. The raw data is read in from each path and stored as a list.}

\item{outpaths}{character. A character vector representing multiple output
paths, which each output set will be written to.}

\item{transform}{function. The transformation function to be applied.}

\item{reader}{function. The function used to read the data set to the target location.}

\item{writer}{function. The function used to write the data set to the target location.}
}
\value{
Returns the outpaths
}
\description{
map_MbM
}
\details{
MbM (the "b" stands for blend) assumes the inputs will be combined
in an arbitrary fashion by the transform. The input sets are fed to the 
transform via `do.call`, and the user should ensure that the output sets
are named in the order that the transform returns them.
}
