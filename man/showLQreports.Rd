% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/FinancialModel.R
\name{showLQreports}
\alias{showLQreports}
\title{showLQreports("FinancialModel")}
\usage{
showLQreports(fm)
}
\arguments{
\item{Financial}{Model with accountLiquidityreports() available}
}
\value{
data frame suitable for displaying results
}
\description{
This function returns a dataframe showing expected liquidity change per 
period with reports at each period end date for the accounts in the financial
model with cashflows generated using the risk environment of the 
currentScenarioAnalysis in the financial model. There is a row in the data 
frame for each account in the financial model Accounts tree. The structure of
the accounts tree is displayed in the first column of the data frame.
}
