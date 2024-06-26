% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ceRNAIntegrate.R
\name{ceRNAIntergate}
\alias{ceRNAIntergate}
\alias{ceRNAIntegrate}
\title{Integration of the possible ceRNA pairs among published tools}
\usage{
ceRNAIntegrate(
  path_prefix = NULL,
  project_name = "demo",
  disease_name = "DLBC"
)
}
\arguments{
\item{path_prefix}{user's working directory}

\item{project_name}{the project name that users can assign}

\item{disease_name}{the abbreviation of disease that users are interested in}
}
\value{
a dataframe object
}
\description{
A function to integrate the possible ceRNA pairs that are found
by ceRNAR algorithm with those from other tools, such as SPONGE (List et al.,
2019) and RJAMI (Hornakova et al.,2018)
}
\examples{
library(SPONGE)
ceRNAIntegrate(
path_prefix = NULL,
project_name = 'demo',
disease_name = 'DLBC'
)

}
