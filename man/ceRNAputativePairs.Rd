% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ceRNAputativePairs.R
\name{ceRNAputativePairs}
\alias{ceRNAputativePairs}
\title{Extraction of putative mRNA-miRNA pairs}
\usage{
ceRNAputativePairs(
  path_prefix = NULL,
  project_name = "demo",
  disease_name = "DLBC",
  filtering = NULL
)
}
\arguments{
\item{path_prefix}{user's working directory}

\item{project_name}{the project name that users can assign}

\item{disease_name}{the abbreviation of disease that users are interested in}

\item{filtering}{three different filtering criteria, including "less",
"moderate" and "more". If the value is null, then a demo case will be applied. (Default: NULL)}
}
\value{
none
}
\description{
A function to obtain putative mRNA-miRNA pairs from several databases
}
\examples{
\donttest{ceRNAputativePairs(
path_prefix = NULL,
project_name ='demo',
disease_name = 'DLBC',
filtering = NULL
)}


}
