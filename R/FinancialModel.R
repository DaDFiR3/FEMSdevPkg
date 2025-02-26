# ******************
# FinancialModel.R  FEMS dev code by Francis Parr Feb 2024
# included in FEMSdevPkg; Licensing and Copyright notices from there
# Defines class FinancialAnalysis 
# Aggregated analysis of projected income, liquidity, and valuations under 
# different risk scenarios for account lines in tree structured projected 
# balance sheets for the enterprise. Holdings of the enterprise are modelled
# either as ACTUS contracts for which future cashflows can be simulated or 
# as directContracts providing formulae or data for future report values 
# **************************************************
# 7 Feb 2024 - start no YieldCurve Attribute, NominalValues only 
#            - will create Analysis from contractsAnalysis - refactored 
# ****************
# defines: class FinancialModel, FinancialModel() constructor,
# defines and exports:
#    Account ..
# library(data.tree)    
# *********************************************************************
# class FinancialModel
# *************************************
#' @include YieldCurve.R
#' @include Portfolio.R
#' @include Timeline.R
#' @include ScenarioAnalysis.R
#' @include Accounts.R
#  #' @import data.tree
#' 
# setOldClass("Node")   # Allows data.tree::Node to be used in S4 object slots 
setRefClass("FinancialModel",
            fields = list(
              financialModelID = "character",
              financialModelDescription = "character",
              enterpriseID = "character",
              accountsTree = "AccountsTree",       
              portfolio = "Portfolio",
              currency = "character",   # all analysis reports same currency 
              timeline = "Timeline",    # all analysis reports same timeline 
              serverURL = "character",  # URL contract simulation ACTUS server 
              scenarioAnalysisList = "list",  # < ScenarioAnalysis> keyed scnID
              currentScenarioAnalysis = "ScenarioAnalysis"
                        )
           )
# **************************************
# constructor FinancialModel(...) for enterprise balance sheet projections
# *************************************
#  **** Generic FinancialModel(<>) ********
# Defines generic S4 constructor method for class FinancialModel 
# include parameters for 
setGeneric("FinancialModel",
           function(fmID, fmDescr, entprID, accntStr, ptf, curr, timeline, 
                    serverURL
                   ) { standardGeneric("FinancialModel") }
          )
#  ***** No parameters FinancialModel( )
# FinancialModel( )  - no parameters instance of FinancialModel()  
#   no parameters method for internal use only 
# Creates an empty FinancialModel instance with no attributes initialized. 
# return  S4 reference with class=FinancialModel no attributes initialized.
setMethod("FinancialModel", c(), 
          function(){ return( new("FinancialModel")) }
)
# ******* Pre Analysis FinancialModel() constructor 
# Allows: (fmID,fmDesc,entprID, accounts, ptf,curr,timeline,serverURL)
# ************************************************************************
#' FinancialModel( < > ) constructor to create a financial model and set 
#' its pre-analysis attributes
#' FinancialModel(fmID, fmDescr, entprID, accounts, ptf, curr, timeline, 
#'                serverURL) 
#'
#' @param fmID   character: a unique ID for this financial model 
#' @param fmDescr character: a short text describing the financial model 
#' @param entprID character: a unique ID for the enterprise being modelled 
#' @param accntsTree AccountsTree - enterprise accounts structure and CIDs
#' @param ptf Portfolio: list of enterprise holdings - ACTUS contracts 
#' @param curr character: currency for all analysis amounts e.g. CHF, EUR, USD  
#' @param timeline Timeline - sets timing of projected balance sheet reports
#' @param serverURL character URL of ACTUS contract simulation server 
#' @return  FinancialModel S4 object: ready for analyses to be added 
#' @export
#' @examples {
#'   fmID       <- "fm001"
#'   fmDescr    <- "test Financial Model logic with example"
#'   entprID    <- "modelBank01"
#'   currency   <- "USD"
#'   serverURL  <- "https://demo.actusfrf.org:8080/" 
#'   yamlstring <- paste0("\nname:  a Model Bank\nAssets:\n  Current:\n     actusCIDs:\n",
#'    "        - pam001\n        - pam002\n        - ann003\n  ShortTerm:\n",
#'    "     actusCIDs:\n        - pam004\n        - ann005\n  LongTerm:\n",
#'    "     functionIDs:\n        - edf006\nLiabilities:\n  Debt:\n     actusCIDs:\n",
#'    "        - pam007\n  Equity:\nOperations:\n  Cashflows:\n     functionIDs:\n",
#'    "        - ocf008\n")
#'   accountsTree <- AccountsTree(yamlstring)
#'   mydatadir <- "~/mydata"
#'   installSampleData(mydatadir)
#'   cdfn  <- "~/mydata/TestPortfolio.csv"
#'   ptf   <-  samplePortfolio(cdfn)
#'   tl <- Timeline(statusDate = "2023-01-01", monthsPerPeriod = 6, 
#'                  reportCount=3, periodCount = 6)  
#'   fm <- initFinancialModel(fmID=fmID, fmDescr= fmDescr, entprID = entprID,
#'                   accntsTree = accountsTree, ptf = ptf, curr = currency,
#'                   timeline = tl, serverURL = serverURL) 
#' }
#'
initFinancialModel <- function( 
    fmID = " ", fmDescr = " ", entprID = " ",
    accntsTree = AccountsTree(), ptf = Portfolio(), curr = " ",
    timeline = Timeline(), serverURL = " "
    ) {
  fm <- FinancialModel()
  fm$financialModelID           <- fmID
  fm$financialModelDescription  <- fmDescr
  fm$enterpriseID               <- entprID
  fm$accountsTree               <- accntsTree
  fm$portfolio                  <- ptf
  fm$currency                   <- curr
  fm$timeline                   <- timeline
  fm$serverURL                  <- serverURL
  fm$scenarioAnalysisList       <- list()
  return (fm)
}
# ********
#  addScenarioAnalysis(fm,scnID,rfxs,yc)
# *yc)********
#' addScenarioAnalysis() starts a risk Scenario Analysis for a Financial Model
#'  This function creates a new ScenarioAnalysis and adds it to the list of 
#'  analyses in the Financial Model. Input parameters are: (1) the financial
#'  model ( providing portfolio, timeline and serverURL specifiations), (2)
#'  the scenarioID for the new scenario (3) a list of projected future values of 
#'  market indexes needed to compute cashflows for (variable rate) contracts in
#'  the financial Model portfolio, and (4) optionally a YieldCurve to be used 
#'  in discounting cashflows for valuation. The newScenarioAnalysis is set as 
#'  the currentScenarioAnalysis attribute of the Financial Model and used by 
#'  default in all analysis requests to the Financial Model until an alternate
#'  ScenarioAnalyis is introduced with a further addScenarioAnalysis request
#'  or an explicit setCurrentScenarioAnlysis() request is made. The method
#'  returns a log message indicating success or failure   
#'    
#' @param  fm      S4 FinancialModel object to receive the new ScenarioAnalysis
#' @param  scnID   character string uniquely identifying this new risk scenario
#' @param  rfxs    list of Reference Indexes projected future market data values
#' @param  yc      optional YieldCurve to be used for discounting cashflows
#' @return        character string log message reporting on success of request
#' @export
#' @examples {
#'   fmID       <- "fm001"
#'   fmDescr    <- "test Financial Model logic with example"
#'   entprID    <- "modelBank01"
#'   currency   <- "USD"
#'   serverURL  <- "https://demo.actusfrf.org:8080/" 
#'   yamlstring <- paste0("\nname:  a Model Bank\nAssets:\n  Current:\n     actusCIDs:\n",
#'    "        - pam001\n        - pam002\n        - ann003\n  ShortTerm:\n",
#'    "     actusCIDs:\n        - pam004\n        - ann005\n  LongTerm:\n",
#'    "     functionIDs:\n        - edf006\nLiabilities:\n  Debt:\n     actusCIDs:\n",
#'    "        - pam007\n  Equity:\nOperations:\n  Cashflows:\n     functionIDs:\n",
#'    "        - ocf008\n")
#'   accountsTree <- AccountsTree(yamlstring)
#'   mydatadir <- "~/mydata"
#'   installSampleData(mydatadir)
#'   cdfn  <- "~/mydata/TestPortfolio.csv"
#'   ptf   <-  samplePortfolio(cdfn)
#'   tl <- Timeline(statusDate = "2023-01-01", monthsPerPeriod = 6, 
#'                  reportCount=3, periodCount = 6)  
#'   fm <- initFinancialModel(fmID=fmID, fmDescr= fmDescr, entprID = entprID,
#'                   accntsTree = accountsTree, ptf = ptf, curr = currency,
#'                   timeline = tl, serverURL = serverURL) 
#'   rxdfp <- paste0(mydatadir,"/UST5Y_fallingRates.csv")
#'   rfx <- sampleReferenceIndex(rxdfp,"UST5Y_fallingRates", "YC_EA_AAA",100)
#'   marketData <-list(rfx)
#'   msg <- addScenarioAnalysis(fm = fm, scnID= "UST5Y_fallingRates", 
#'                              rfxs = marketData, yc = YieldCurve())                
#' }
addScenarioAnalysis <- function( fm = FinancialModel(), scnID = " ", 
                                 rfxs = list(), yc = YieldCurve()){ 
   scna <- ScenarioAnalysis(scenarioID=scnID, marketData= rfxs, yieldCurve = yc,
                            accounts = accountsTree)
   fm$scenarioAnalysisList[scnID] <- list(scna=scna)
   fm$currentScenarioAnalysis <- scna
   msg<- "new scenarioAnalysis added to Financial Model and made current"
   return(msg)
}
  
# ************************************************************************
# generateEvents(FinancialModel)
# ************************************************************************
#' generateEvents(FinancialModel)
#'
#'   The generateEvents(Financial) function takes as input an 
#'   initialized S4 FinancialModel object with at least one ScenarioAnaysis  
#'   added so that currentScenarioAnalysis is set. The method will simulate all
#'   contracts in the financialModel portfolio, with the risk environment of the
#'   currentScenarioAnalysis. The cashflow events generated are saved as data
#'   in the ScenarioAnalysis 
#'
#' @param host  FinancialModel S4 object with a currentScenarioAnalysis defined
#' @return      Log message listing which contracts were successfully simulated 
#' @export
#' @import    jsonlite
#' @import    httr
#' @examples {
#'   fmID       <- "fm001"
#'   fmDescr    <- "test Financial Model logic with example"
#'   entprID    <- "modelBank01"
#'   currency   <- "USD"
#'   serverURL  <- "https://demo.actusfrf.org:8080/" 
#'   yamlstring <- paste0("\nname:  a Model Bank\nAssets:\n  Current:\n     actusCIDs:\n",
#'    "        - pam001\n        - pam002\n        - ann003\n  ShortTerm:\n",
#'    "     actusCIDs:\n        - pam004\n        - ann005\n  LongTerm:\n",
#'    "     functionIDs:\n        - edf006\nLiabilities:\n  Debt:\n     actusCIDs:\n",
#'    "        - pam007\n  Equity:\nOperations:\n  Cashflows:\n     functionIDs:\n",
#'    "        - ocf008\n")
#'   accountsTree <- AccountsTree(yamlstring)
#'   mydatadir <- "~/mydata"
#'   installSampleData(mydatadir)
#'   cdfn  <- "~/mydata/TestPortfolio.csv"
#'   ptf   <-  samplePortfolio(cdfn)
#'   tl <- Timeline(statusDate = "2023-01-01", monthsPerPeriod = 6, 
#'                  reportCount=3, periodCount = 6)  
#'   fm <- initFinancialModel(fmID=fmID, fmDescr= fmDescr, entprID = entprID,
#'                   accntsTree = accountsTree, ptf = ptf, curr = currency,
#'                   timeline = tl, serverURL = serverURL) 
#'   rxdfp <- paste0(mydatadir,"/UST5Y_fallingRates.csv")
#'   rfx <- sampleReferenceIndex(rxdfp,"UST5Y_fallingRates", "YC_EA_AAA",100)
#'   marketData <-list(rfx)
#'   msg1 <- addScenarioAnalysis(fm = fm, scnID= "UST5Y_fallingRates", 
#'                              rfxs = marketData, yc = YieldCurve())                

#'   msg2 <- generateEvents(host= fm)
#' }
#'
setMethod (f = "generateEvents", 
           signature = c(host = "FinancialModel", ptf="missing", 
                         serverURL="missing", riskFactors="missing" ) ,
           definition = function( host ){
            # invokes generateEvents( ) on currentScenarioAnalysis passing 
            # fm$portfolio and fm$serverURL as parameters 
            logmsg <- generateEvents(host = host$currentScenarioAnalysis,
                                     ptf = host$portfolio,
                                     serverURL = host$serverURL)
            return(logmsg) 
           }
)  

# ***** events2dfByPeriod instance   signature = (FinancialModel)   
#' events2dfByPeriod(host = <FinancialModel>)
#'
#'   This method reorganizes the cashflow events in the currentScenarioAnalysis 
#'   of the FinancialModel by period using the Timeline of the FInancialModel 
#'   into a data frame with columns for: contractID, period, and for each 
#'   ACTUS cashflow event field. The input Financial Model must have: (1)
#'   a defined portfolio and timeline with status date of all comntracts in the 
#'   portfolio matching the statusDate in the timeline (2) a defined 
#'   currentScenarioAnlysis (3) generateEvents( ) must have run successfully on 
#'   the FinancialModel ( using that current Scenario Analysis ). You can check 
#'   this using: 
#'  > unlist(lapply(fm$currentScenarioAnlysis$cashflowEventsLoL,
#'                  function(x){return(x$status)})) 

#'   If these conditions are met, events2dfByPeriod() will reorganize the data
#'   in the scna$cashflowEventsLoL as a dataframe with columns: 
#'   and save that as scna$cashflowEventsByPeriod for use in subsequent analysis
#'   steps in the currentScenarioAnalysis attribute  
#'   
#'   A text message is returned reporting on any issues in this processing step.
#'   
#'   Processing steps: (0) check valid host$cashflowEventsLoL, (1) merge 
#'   eventsLOL into eventsDF, (2) add periodIndex column,  (3) sort by 
#'   (contractID, periodIndex), (4) save as host$cashFlowEventsByPeriod. 
#' @param host  FinancialModel S4 obj with currentScenarioAnalysis and Timeline
#' @return      log msg reporting success of cashflow event bucketing  
#' @export
#' @examples {
#'   fmID       <- "fm001"
#'   fmDescr    <- "test Financial Model logic with example"
#'   entprID    <- "modelBank01"
#'   currency   <- "USD"
#'   serverURL  <- "https://demo.actusfrf.org:8080/" 
#'   yamlstring <- paste0("\nname:  a Model Bank\nAssets:\n  Current:\n     actusCIDs:\n",
#'    "        - pam001\n        - pam002\n        - ann003\n  ShortTerm:\n",
#'    "     actusCIDs:\n        - pam004\n        - ann005\n  LongTerm:\n",
#'    "     functionIDs:\n        - edf006\nLiabilities:\n  Debt:\n     actusCIDs:\n",
#'    "        - pam007\n  Equity:\nOperations:\n  Cashflows:\n     functionIDs:\n",
#'    "        - ocf008\n")
#'   accountsTree <- AccountsTree(yamlstring)
#'   mydatadir <- "~/mydata"
#'   installSampleData(mydatadir)
#'   cdfn  <- "~/mydata/TestPortfolio.csv"
#'   ptf   <-  samplePortfolio(cdfn)
#'   tl <- Timeline(statusDate = "2023-01-01", monthsPerPeriod = 6, 
#'                  reportCount=3, periodCount = 6)  
#'   fm1 <- initFinancialModel(fmID=fmID, fmDescr= fmDescr, entprID = entprID,
#'                   accntsTree = accountsTree, ptf = ptf, curr = currency,
#'                   timeline = tl, serverURL = serverURL) 
#'   rxdfp <- paste0(mydatadir,"/UST5Y_fallingRates.csv")
#'   rfx <- sampleReferenceIndex(rxdfp,"UST5Y_fallingRates", "YC_EA_AAA",100)
#'   marketData <-list(rfx)
#'   msg1 <- addScenarioAnalysis(fm = fm1, scnID= "UST5Y_fallingRates", 
#'                              rfxs = marketData, yc = YieldCurve())                
#'   msg2 <- generateEvents(host= fm1)
#'   msg3 <- events2dfByPeriod(host= fm1)
#' }
#'            
setMethod (f = "events2dfByPeriod", 
           signature = c(host = "FinancialModel") ,
           definition = function(host){ 
             logmsg <- events2dfByPeriod(host = host$currentScenarioAnalysis,
                                         tl = host$timeline)
             return(logmsg)
           }
)
 
#'  *******************************
#'   nominalValues(host = FinancialModel) - exported method instance
#' *******************************
#' 
#' nominalValueReports(host= Financial Model) 
#' creates a list of NV reports using data in currentScenarioAnalysis of
#' the FinancialModel and passing in portfolio information ( needed to find
#' NominalValue of contracts at their status date) and timeline (needed to 
#' understand the dates and number of nominalValue reports for each 
#' contract.) Nominal Values following the statusDate are retrieved frome the
#' cashflowEventByPeriod data already saved in the ScenarioAnalysis
#'      
#' @param host  FinancialModel S4 object with portfolio, cashflowevents data
#' @return      Log summarizing whether processing was successful
#' @export
#' @import zoo
#' @importFrom zoo na.locf  
#' @examples {
#'    fmID       <- "fm001" 
#'    fmDescr    <- "test Financial Model logic with example"
#'    entprID    <- "modelBank01"
#'    currency   <- "USD"
#'    serverURL  <- "https://demo.actusfrf.org:8080/" 
#'    yamlstring <- paste0("\nname:  a Model Bank\nAssets:\n  Current:\n     actusCIDs:\n",
#'      "        - pam001\n        - pam002\n        - ann003\n  ShortTerm:\n",
#'      "     actusCIDs:\n        - pam004\n        - ann005\n  LongTerm:\n",
#'      "     functionIDs:\n        - edf006\nLiabilities:\n  Debt:\n     actusCIDs:\n",
#'      "        - pam007\n  Equity:\nOperations:\n  Cashflows:\n     functionIDs:\n",
#'      "        - ocf008\n") 
#'    accountsTree <- AccountsTree(yamlstring)
#'    mydatadir <- "~/mydata"
#'    installSampleData(mydatadir)
#'    cdfn  <- "~/mydata/TestPortfolio.csv"
#'    ptf   <-  samplePortfolio(cdfn)
#'    tl <- Timeline(statusDate = "2023-01-01", monthsPerPeriod = 6, 
#'                   reportCount=3, periodCount = 6)  
#'    fm1 <- initFinancialModel(fmID=fmID, fmDescr= fmDescr, entprID = entprID,
#'                              accntsTree = accountsTree, ptf = ptf, curr = currency,
#'                              timeline = tl, serverURL = serverURL) 
#'    rxdfp <- paste0(mydatadir,"/UST5Y_fallingRates.csv")
#'    rfx <- sampleReferenceIndex(rxdfp,"UST5Y_fallingRates", "YC_EA_AAA",100)
#'    marketData <-list(rfx)
#'    msg1 <- addScenarioAnalysis(fm = fm1, scnID= "UST5Y_fallingRates", 
#'                                rfxs = marketData, yc = YieldCurve())
#'    msg2 <- generateEvents(host= fm1)
#'    msg3 <- events2dfByPeriod(host= fm1)
#'    msg4 <-  nominalValueReports(host = fm1)
#' }
#' 
setMethod(f = "nominalValueReports",
          signature = c(host = "FinancialModel"),
          definition = function(host) {
            msg <- nominalValueReports(host = host$currentScenarioAnalysis,
                                       ptf =  host$portfolio,
                                       tl =   host$timeline)
            return(msg)
          })

#'  *******************************
#'   accountNMVreports(host = FinancialModel) - exported method instance
#' *******************************
#' 
#' accountNMVreports(host= Financial Model) 
#' This method computed aggregated Nominal Value report vectors for each 
#' account in the accountsTree of the input Financial model using the 
#' currentScenarioAnalysis ( i.e. risk factor environment ) of the financial
#' model. The results are saved in  $nmv fields in each node of the 
#' scenarioAccounts tree.  This method requires that nominalValueReports( ) has
#' already been run on the financial model to generate nominalValue report data 
#' for each contract in the portfolio of the financial model. The work of this 
#' method is to aggregate for each node in the accounts tree, the nominal value
#' reports of all conracts under that node   
#'      
#' @param host  FinancialModel S4 object with portfolio, cashflowevents data
#' @return      Log summarizing whether processing was successful
#' @export
#' @import data.tree
#' @examples {
#'   fmID       <- "fm001"
#'   fmDescr    <- "test Financial Model logic with example"
#'   entprID    <- "modelBank01"
#'   currency   <- "USD"
#'   serverURL  <- "https://demo.actusfrf.org:8080/" 
#'   yamlstring <- paste0("\nname:  a Model Bank\nAssets:\n  Current:\n     actusCIDs:\n",
#'   "        - pam001\n        - pam002\n        - ann003\n  ShortTerm:\n",
#'   "     actusCIDs:\n        - pam004\n        - ann005\n  LongTerm:\n",
#'   "     functionIDs:\n        - edf006\nLiabilities:\n  Debt:\n     actusCIDs:\n",
#'   "        - pam007\n  Equity:\nOperations:\n  Cashflows:\n     functionIDs:\n",
#'   "        - ocf008\n") 
#'   accountsTree <- AccountsTree(yamlstring)
#'   mydatadir <- "~/mydata"
#'   installSampleData(mydatadir) 
#'   cdfn  <- "~/mydata/TestPortfolio.csv"
#'   ptf   <-  samplePortfolio(cdfn) 
#'   tl <- Timeline(statusDate = "2023-01-01", monthsPerPeriod = 6, 
#'                  reportCount=3, periodCount = 6)  
#'   fm1 <- initFinancialModel(fmID=fmID, fmDescr= fmDescr, entprID = entprID,
#'                             accntsTree = accountsTree, ptf = ptf, curr = currency,
#'                             timeline = tl, serverURL = serverURL) 
#'   rxdfp <- paste0(mydatadir,"/UST5Y_fallingRates.csv")
#'   rfx <- sampleReferenceIndex(rxdfp,"UST5Y_fallingRates", "YC_EA_AAA",100) 
#'   marketData <-list(rfx) 
#'   scnID <- "UST5Y_fallingRates"
#'   yc<- YieldCurve() 
#'   msg1 <- addScenarioAnalysis(fm = fm1, scnID= "UST5Y_fallingRates", 
#'                               rfxs = marketData, yc = YieldCurve())
#'   msg2 <- generateEvents(host= fm1)
#'   msg3 <- events2dfByPeriod(host= fm1) 
#'   msg4 <-  nominalValueReports(host = fm1)
#'   msg5 <- accountNMVreports(host = fm1)
#' }
setMethod("accountNMVreports",
          c(host = "FinancialModel"), 
          function(host){ 
            nreps <- host$timeline$reportCount + 1
            accountNMVreports(
              host = host$currentScenarioAnalysis,
              vlen = nreps, 
              vnames = as.character(host$timeline$periodDateVector[1:nreps]), 
            )
            logMsg <- "Account NominalValue reports generated"
            return(logMsg)
          }
)
# ******* getNMVreports() 
#' getNMVreports("FinancialModel")
#' 
#' This function returns a matrix of doubles showing expected nominal value 
#' reports at different dates for the accounts in the financial model with 
#' cashflows generated using the risk environment of the currentScenarioAnalysis
#' in the financial model. There is a row in the data frame for each account in
#' the financial model Accounts tree. 
#' @param  Financial Model with accountNominalValues() available 
#' @returns matrix with account Nominal Value reports   
#' @import data.tree
#' @export
getNMVreports <- function(fm) {
  return(t(fm$currentScenarioAnalysis$scenarioAccounts$root$Get("nmv")))
}

# ******* showNMVreports() 
#' showNMVreports("FinancialModel")
#' 
#' This function returns a dataframe showing expected nominal value reports at 
#' different dates for the accounts in the financial model with cashflows 
#' generated using the risk environment of the currentScenarioAnalysis in the 
#' financial model. There is a row in the data frame for #' each account in the 
#' financial model Accounts tree. The structure of the accounts tree is 
#' displayed in the first column of the data frame 
#' @param  Financial Model with accountNominalValues() available 
#' @returns data frame suitable for displaying results  
#' @import data.tree
#' @export
showNMVreports <- function(fm ) {
  adf<- as.data.frame(fm$accountsTree$root)
  table <- t(fm$currentScenarioAnalysis$scenarioAccounts$root$Get("nmv"))
  df <- data.frame(adf["levelName"])
  for ( datestr in colnames(table)) {
       df[datestr] <- table[,datestr]
  }
  return( df)
}

# *****************
# liquidityReports(host = FinancialModel )
# *****************
#' liquidityReports(host = FinancialModel)
#' 
#' This method computes liquidityReports for the currentScenarioAnalysis of the
#' host FinancialModel and causes these liquidity reports to be saved in the
#' liquidityReports attribute of that ScenarioAnlysis. It does this by calling 
#' liquidityReports() on the currentScenarioAnalysis and passing in the
#' timeline of the Financial model as a parameter 
#' @param host FinancialModel with nominalValueReports in currentScenarioAnalysis  
#' @include ScenarioAnalysis.R
#' @export
#' @examples {
#'   fmID       <- "fm001"
#'   fmDescr    <- "test Financial Model logic with example"
#'   entprID    <- "modelBank01"
#'   currency   <- "USD"
#'   serverURL  <- "https://demo.actusfrf.org:8080/"
#'   yamlstring <- paste0("\nname:  a Model Bank\nAssets:\n  Current:\n     actusCIDs:\n",
#'   "        - pam001\n        - pam002\n        - ann003\n  ShortTerm:\n",
#'   "     actusCIDs:\n        - pam004\n        - ann005\n  LongTerm:\n",
#'   "     functionIDs:\n        - edf006\nLiabilities:\n  Debt:\n     actusCIDs:\n",
#'   "        - pam007\n  Equity:\nOperations:\n  Cashflows:\n     functionIDs:\n",
#'   "        - ocf008\n")
#'   accountsTree <- AccountsTree(yamlstring)
#'   mydatadir <- "~/mydata"
#'   installSampleData(mydatadir)
#'   cdfn  <- "~/mydata/TestPortfolio.csv"
#'   ptf   <-  samplePortfolio(cdfn)
#'   tl <- Timeline(statusDate = "2023-01-01", monthsPerPeriod = 6, 
#'                  reportCount=3, periodCount = 6)  
#'                  fm1 <- initFinancialModel(
#'                    fmID=fmID, fmDescr= fmDescr, entprID = entprID,
#'                    accntsTree = accountsTree, ptf = ptf, curr = currency,
#'                    timeline = tl, serverURL = serverURL)
#'   rxdfp <- paste0(mydatadir,"/UST5Y_fallingRates.csv") 
#'   rfx <- sampleReferenceIndex(rxdfp,"UST5Y_fallingRates", "YC_EA_AAA",100)
#'   marketData <- list(rfx)
#'   msg1 <- addScenarioAnalysis(fm = fm1, scnID= "UST5Y_fallingRates", 
#'                               rfxs = marketData, yc = YieldCurve()) 
#'   msg2 <- generateEvents(host= fm1)
#'   msg3 <- events2dfByPeriod(host= fm1)
#'   msg4 <-  nominalValueReports(host = fm1)
#'   msg5 <- liquidityReports(host = fm1) 
#' }
setMethod(f = "liquidityReports",
          signature = c(host = "FinancialModel"),
          definition = function(host) {
            logMsg <-  liquidityReports(host= host$currentScenarioAnalysis,
                                        tl = host$timeline)
            return(logMsg)
          }
)

#'  *******************************
#'   accountLQreports(host = FinancialModel) - exported method instance
#' *******************************
#' 
#' accountLQreports(host= Financial Model) 
#' This method computed aggregated Liquidity report vectors for each 
#' account in the accountsTree of the input Financial model using the 
#' currentScenarioAnalysis ( i.e. risk factor environment ) of the financial
#' model. The results are saved in  $lq fields in each node of the 
#' scenarioAccounts tree.  This method requires that liquidityReports( ) has
#' already been run on the financial model to generate liquidity report data 
#' for each contract in the portfolio of the financial model. The work of this 
#' method is to aggregate for each node in the accounts tree, the nominal value
#' reports of all conracts under that node  
#' 
#' @param host  FinancialModel S4 object with portfolio, cashflowevents data
#' @return      Log summarizing whether processing was successful
#' @export
#' @import data.tree
#' @examples {
#'   fmID       <- "fm001"
#'   fmDescr    <- "test Financial Model logic with example"
#'   entprID    <- "modelBank01"
#'   currency   <- "USD"
#'   serverURL  <- "https://demo.actusfrf.org:8080/" 
#'   yamlstring <- paste0("\nname:  a Model Bank\nAssets:\n  Current:\n     actusCIDs:\n",
#'   "        - pam001\n        - pam002\n        - ann003\n  ShortTerm:\n",
#'   "     actusCIDs:\n        - pam004\n        - ann005\n  LongTerm:\n",
#'   "     functionIDs:\n        - edf006\nLiabilities:\n  Debt:\n     actusCIDs:\n",
#'   "        - pam007\n  Equity:\nOperations:\n  Cashflows:\n     functionIDs:\n",
#'   "        - ocf008\n") 
#'   accountsTree <- AccountsTree(yamlstring)
#'   mydatadir <- "~/mydata"
#'   installSampleData(mydatadir) 
#'   cdfn  <- "~/mydata/TestPortfolio.csv"
#'   ptf   <-  samplePortfolio(cdfn) 
#'   tl <- Timeline(statusDate = "2023-01-01", monthsPerPeriod = 6, 
#'                  reportCount=3, periodCount = 6)  
#'   fm1 <- initFinancialModel(fmID=fmID, fmDescr= fmDescr, entprID = entprID,
#'                             accntsTree = accountsTree, ptf = ptf, curr = currency,
#'                             timeline = tl, serverURL = serverURL) 
#'   rxdfp <- paste0(mydatadir,"/UST5Y_fallingRates.csv")
#'   rfx <- sampleReferenceIndex(rxdfp,"UST5Y_fallingRates", "YC_EA_AAA",100) 
#'   marketData <-list(rfx) 
#'   scnID <- "UST5Y_fallingRates"
#'   yc<- YieldCurve() 
#'   msg1 <- addScenarioAnalysis(fm = fm1, scnID= "UST5Y_fallingRates", 
#'                               rfxs = marketData, yc = YieldCurve())
#'   msg2 <- generateEvents(host= fm1)
#'   msg3 <- events2dfByPeriod(host= fm1) 
#'   msg4 <-  liquidityReports(host = fm1)
#'   msg5 <- accountLQreports(host = fm1)
#' }

setMethod("accountLQreports",
          c(host = "FinancialModel"), 
          function(host){ 
            nreps <- host$timeline$reportCount 
            accountLQreports(
              host = host$currentScenarioAnalysis,
              vlen = nreps, 
              vnames = as.character(host$timeline$periodDateVector[1:nreps]), 
            )
            logMsg <- "Account Liquidity reports generated"
            return(logMsg)
          }
)            

# ******* getLQreports() 
#' getLQreports("FinancialModel")
#' 
#' This function returns a matrix of doubles showing expected nominal value 
#' reports on liquidity at different dates for the accounts in the financial 
#' model with #' cashflows generated using the risk environment of the 
#' currentScenarioAnalysis #' in the financial model. There is a row in the data
#' frame for each account in the financial model Accounts tree. 
#' @param  Financial Model with accountLQreports() available 
#' @returns matrix with account Liquidity reports   
#' @import data.tree
#' @export
#' 
getLQreports <- function(fm) {
  return(t(fm$currentScenarioAnalysis$scenarioAccounts$root$Get("lq")))
}

# ******* showLQreports() 
#' showLQreports("FinancialModel")
#' 
#' This function returns a dataframe showing expected liquidity change per 
#' period with reports at each period end date for the accounts in the financial
#' model with cashflows generated using the risk environment of the 
#' currentScenarioAnalysis in the financial model. There is a row in the data 
#' frame for each account in the financial model Accounts tree. The structure of
#' the accounts tree is displayed in the first column of the data frame. 
#' @param  Financial Model with accountLiquidityreports() available 
#' @returns data frame suitable for displaying results  
#' @import data.tree
#' @export
#' 
showLQreports <- function(fm ) {
  adf<- as.data.frame(fm$accountsTree$root)
  table <- t(fm$currentScenarioAnalysis$scenarioAccounts$root$Get("lq"))
  df <- data.frame(adf["levelName"])
  for ( datestr in colnames(table)) {
    df[datestr] <- table[,datestr]
  }
  return( df)
}            