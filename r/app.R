library(tidyverse)
library(RSQLite)
library(lubridate)
library(shiny)
library(shinythemes)
library(plotly)

# set this file equal to db file created from create_db.py
db.file <- 'data.db'

#Conneciton to sqlite database and initial queries to build dataframes for further reference
conn <- dbConnect(
  SQLite(),
  db.file
  )

culturestartdates <- dbGetQuery(conn, "SELECT * FROM culturestartdates")
keydaysdf <- dbGetQuery(conn, "SELECT keyday, notes FROM keydaystable")
mediachange <- dbGetQuery(conn, "SELECT day, change FROM mediachange")
mediareagents <- dbGetQuery(conn, "SELECT * FROM mediareagents")
plateinventory <- dbGetQuery(conn, "SELECT * FROM plateinventory")
culturecontainers <- dbGetQuery(conn, "SELECT * FROM culturecontainers")
mediavolumedf <- dbGetQuery(conn, "SELECT * FROM mediavolume")

dbDisconnect(conn)

#Functions to calculate and build later tables

# Function that will build df with plate totals and start date given an input date.  
# Uses plate inventory to get accurate plate count as plates are added or dropped
plateinventoryfunc <- function(testdate) {
  plateinventory %>% 
    filter(startdateday0 <= testdate & (is.na(enddate) | enddate >= testdate)) %>% 
    group_by(batch, startdateday0) %>% 
    summarise(totalplates = n())
}

#Function that calculates reagent volumes based on experimental day and final desired volume
mediacalculate <- function(day, finalvolume) {
  mediareagents %>% 
    filter(daystart <= day & dayend >= day) %>% 
    arrange(stock) %>% 
    mutate(volume = finalvolume/stock) %>% 
    mutate(volume =if_else(mediasubtract == 1, finalvolume + (finalvolume - sum(volume)), volume, volume)) %>% 
    mutate(volume = if_else(stock >= 50, volume * 1000, volume)) %>%
    select(component, stock, volume, unit)
  
}

#Function for media volume on any given day
mediavolume <- function(day) {
  df <- mediavolumedf %>%
    filter(daystart <= day & dayend >= day)
  df[["volume"]]
}

#Function for batches on a specific day
batchesperday <- function(date) {
  df <- plateinventory %>% 
    filter(startdateday0 <= date & (is.na(enddate) | enddate >= date)) %>% 
    group_by(batch) %>% 
    summarise(totalplates = n())
  df[["batch"]]
}

# Function to get plates per day based on batch
batchplatesperday <- function(date, batchvar) {
  df <- plateinventory %>% 
    filter(startdateday0 <= date & (is.na(enddate) | enddate >= date)) %>% 
    group_by(batch) %>% 
    summarise(totalplates = n())
  df
  #df[[batchvar, 2]]
}

# Working function to generate table for weekly aliquots of media to be made
weeklysummaryfunc <- function(startdate, enddate) {
  dates <- seq(as.Date(startdate), as.Date(enddate), by = 1)
  batches <- batchesperday(startdate)
  startdatedf <- culturestartdates %>%
    select(batch, day0)
  startdateplates <- batchplatesperday(startdate)
  df <- expand_grid(dates, batches)
  df %>%
    inner_join(startdatedf, by = c("batch" = "batch")) %>%
    inner_join(startdateplates, by = c("batch" = "batch")) %>%
    mutate(day0 = ymd(day0)) %>%
    mutate(expday = dates - day0) %>%
    mutate(expdayint = as.integer(expday)) %>%
    mutate(media = if_else(expdayint < 0, "Essential Base", if_else(expdayint > 5, "Media B", "Another Basal"))) %>%
    mutate(mediavolumemL = totalplates * mediavolume(expdayint)) %>%
    group_by(dates, batch, media) %>%
    summarise(dailymedia = sum(mediavolumemL)) %>%
    select(dates, batch, dailymedia, media)
}

# Function for pasting media type plus volume together
mediatypeplusvolume <- function(batch, date) {
  expday <- as.Date(date) - as.Date(culturestartdates[batch, "day0"])
  volume <- mediavolume(expday) * batchplatesperday(date, batch)[batch,"totalplates"]
  type <- if_else(expday < 0, "Essential Base", if_else(expday > 5, "Media B", "Another Basal"))
  paste(type, volume, "mL", sep = " ")
}

# # Reworking weekly media aliquot function to just give output for week, no flexibility for other date ranges
weeklymediafunc <- function() {
  startdate <- floor_date(today(), unit = "weeks", week_start = 1)
  enddate <- ceiling_date(today(), unit = "weeks", week_start = 7)
  dates <- seq(startdate, enddate, by = 1)
  allbatches <- unique(plateinventory$batch)
  allbatches <- as_tibble(allbatches, column_name = "batch") %>%
    mutate(
      Mon = mediatypeplusvolume(value, dates[1]),
      Tues = mediatypeplusvolume(value, dates[2]),
      Wed = mediatypeplusvolume(value, dates[3]),
      Thurs = mediatypeplusvolume(value, dates[4]),
      Fri = mediatypeplusvolume(value, dates[5]),
      Sat = mediatypeplusvolume(value, dates[6]),
      Sun = mediatypeplusvolume(value, dates[7])
    )
  allbatches
}

#Function for if a particular batch exists on a given date
batchondate <- function(batch, date) {
  b <- batchesperday(date)
  if_else(batch %in% b, "Yes", "No")
}

#Check with df if expday is media change day
changekmediafunc <- function(expday) {
  mediachange[expday,2]
}

#Shiny App coding
ui <- fluidPage(
  # alter tag to allow padding for rest of page to render below navbar
  tags$style(type="text/css", "body {padding-top: 70px;}"),
  theme = shinytheme("cerulean"),
  # fixed-top allows bar to span whole screen with no padding
  navbarPage("Cell Culture Schedule and Media Planning", position = "fixed-top"),
  tabsetPanel(type = "tabs",
    tabPanel("Daily Cell Culture",
      fluidRow(
        column(12,
          dateInput(
            "pickday", 
            "Select Day",
            value = today(),
            width = "100px"
          )
        )
      ),
      fluidRow(
        column(12,
          h3("Media Summary for Batches"),
          tableOutput("daysummarychecktable")
        )
      ),
      fluidRow(
        column(6, 
          h3("Sum of Media Volumes"),
          tableOutput("mediasumtable")),
        column(6, 
          h3("Media Reagents Recipe"),
          selectInput(
            "batchselect",
            label = "Select Batch",
            choices = "",
            width = "100px"
          ),
          tableOutput("mediareagentstbl")
        )
      )
    ),
    tabPanel("Cell Culture",
      sidebarPanel(
        selectInput(
          "containertype",
          label = "Pick Container",
          choices = culturecontainers$vessel,
          selected = culturecontainers$vessel[1]
        ),
        numericInput(
          "containernumber",
          label = "Number of Wells or Plates",
          value = 6,
          min = 1,
          step = 1
        ),
        selectInput(
          "activity",
          label = "Pick Actions:",
          c("Media Change" = -3, "Passage" = -4),
          selected = c("media Change" = -3)
        )
      ),
      mainPanel(tableOutput("celllinetbl"))
    )
  )
)

server <- function(input, output, session) {
  
  tabledata <- reactive(plateinventoryfunc(input$pickday))
  
  cultcantainreactive <- reactive(culturecontainers %>% filter(vessel == input$containertype))
  
  observe({
    updateSelectInput(
      session,
      "batchselect",
      label = "Select Batch",
      choices = tabledata()$batch,
      selected = tabledata()$batch[1]
    )
  })
  
  #Top table that displays summary info for each batch
  output$daysummarychecktable <- renderTable({
    tabledata() %>% 
      mutate(startdateday0 = ymd(startdateday0)) %>% 
      mutate(`Today's Experiment Day` = input$pickday - startdateday0) %>%
      mutate(keydayint = as.integer(`Today's Experiment Day`)) %>%
      mutate(`Today's media` = if_else(`Today's Experiment Day` < 0, "Essential Base", if_else(`Today's Experiment Day` > 5, "Media B", "Another Base"))) %>%
      mutate(`media volume (mL)` = totalplates * mediavolume(keydayint)) %>%
      mutate(`Key Date` = if_else(`Today's Experiment Day` %in% keydaysdf$keyday, "YES", "")) %>%
      left_join(keydaysdf, by = c("keydayint" = "keyday")) %>%
      left_join(mediachange, by = c("keydayint" = "day")) %>% 
      select(batch:`Today's Experiment Day`, change, `Today's media`:notes) %>%
      mutate(startdateday0 = as.character(startdateday0)) %>%
      mutate(`Today's Experiment Day` = paste0("D", as.integer(`Today's Experiment Day`), sep = ""))
    
  })
  
  #Bottom left table that summarizes down to media type and sums total media needed for the day
  output$mediasumtable <- renderTable({
    tabledata() %>% 
      mutate(startdateday0 = ymd(startdateday0)) %>% 
      mutate(`Today's Experiment Day` = input$pickday - startdateday0) %>%
      mutate(keydayint = as.integer(`Today's Experiment Day`)) %>%
      mutate(`Today's media` = if_else(`Today's Experiment Day` < 0, "Essential Base", if_else(`Today's Experiment Day` > 5, "Media B", "Another Base"))) %>%
      mutate(`media volume (mL)` = totalplates * mediavolume(keydayint)) %>%
      mutate(`Key Date` = if_else(`Today's Experiment Day` %in% keydaysdf$keyday, "YES", "")) %>%
      left_join(keydaysdf, by = c("keydayint" = "keyday")) %>%
      select(batch:`Today's Experiment Day`, `Today's media`:notes) %>%
      mutate(startdateday0 = as.character(startdateday0)) %>%
      mutate(`Today's Experiment Day` = paste0("D", as.integer(`Today's Experiment Day`), sep = "")) %>% 
      group_by(`Today's media`) %>% 
      summarise(`Total volume to Prep (mL)` = sum(`media volume (mL)`))
  })
  
  #Bottom right table that lists reagents needed for each media prep. Might later change to include option to      pick volume and to select size if using 6-wells or bigger plates
  output$mediareagentstbl <-  renderTable({
    tempdf <- tabledata() %>%
      filter(batch == input$batchselect) %>%
      mutate(startdateday0 = ymd(startdateday0)) %>%
      mutate(expday = input$pickday - startdateday0) %>%
      mutate(expday = as.integer(expday)) %>% 
      mutate(volume = totalplates * mediavolume(expday))
    mediacalculate(tempdf$expday, tempdf$volume)

  })
  
  #Table for E8 passaging
  output$celllinetbl <- renderTable({
    df <- cultcantainreactive() %>% 
      mutate(completemediaml = completemediaml * input$containernumber)
    mediacalculate(as.numeric(input$activity), df$completemediaml)
  })
  
  
}

shinyApp(ui, server)
