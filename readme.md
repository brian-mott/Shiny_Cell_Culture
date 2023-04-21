# Shiny App for Complex Tracking of Tissue Culture

https://bmott.shinyapps.io/cell_culture_schedule/

This is a Shiny App made for tracking specific reagent, media, and media change requirements for complex cell culutre experiments. The files contained here will create and populate an initial database with values for reagents and daily change schedules. Then use your favorite database management GUI to add entries for new start dates and number of plates. Maybe in the future I will add some very basic functions to add and update the plate inventory. Or if I'm really feeling ambitious, build out more of the gui for editing the data instead relying on database editing.

## Basic Functionality

The Shiny app will load data from a sqlite database and then based on start dates, batch numbers, and number of plates in a batch, will calculate out reagents needed for a given day. You can find this under the default 'Daily Cell Culture' tab.

The 'Cell Culture' tab will give more options for picking container size and number of wells to calculate out reagents needed for a given media change or cell passage.

The various tables within the database determine reagent volume and key days for a given experiement.

The initial db is loaded with data from a JSON file. This contains sample data for several batches of experiments along with some sample data for culture requirements.

## Setup

Running the create_db.py file will create the sqlite database and load it with the initial JSON data. Without modification, the database will be created in the local directory; modify the instantiation of the Database() class to change the name and location of the db file.

Before running the R file and Shiny app, make sure the db.file variable is set to the same name and path as the database just created with create_db.py. The Shiny app will then run by running the R file.

## DB Schema

Here is the schema to edit to your own rules. There are no foreign key constraints and might be more elegant ways to take care of some of these.

culturecontainers = table that contains information on different containers to use for culture
- id = int, primary id
- vessel = string, name of vessel
- perplate = int, number of wells per container
- surfaceareacm2 = int, surface area of plate in cm2
- vitronectinml = decimal, ml of vitronectin to use per well
- dbpsml = decimal, ml of dPBS to use per well
- edtaml = decimal, ml of EDTA to use per well
- completemediaml = decimal, ml of complete media to add per well
- seedingdensity = int, cells per ml for seeding
- cellsatconfluency = int, approx number of cells at confluency

culturestartdates = table that contains start dates and number of plates per batch. Each row should be for data for each new batch. Most functions will calculate experimental day off of day0 (or startdateday0 in plateinventory table)
- id = int, primary key
- batch = int, batch number
- day-2 = date, date for 2 days prior to start date, if applicable
- day-1 = date, date for 1 day prior to start date, if applicable
- day0 = date, start date or day 0 of experiment
- plates = int, number of plates in batch

keydaystable = table that notes key days of experiment. The accompanying note with display on the noted day to remind of important things to do on that experimental day.
- id = int, primary key
- keyday = int, experimental day
- notes = string, note to be displayed on key day

mediachange = table that notes if media should be changed on a given experimental day. 
- id = int, primary key
- day = int, experimental day
- change = string, yes or no if media should be changed on that day

mediareagents = table with properties of reagents to determine how much to use and on which day
- id = int, primary key
- component = string, reagent name
- stock = int, stock concentration. 1 = 1x, 500 = 500x, etc.
- unit = string, typical volume unit used for reagent
- daystart = signed int, experimental day when to start using reagent. Can be negative for situations where media is required for prep before true day 0.
- dayend signed int, last experimental day when reagent is used. For this example, values less than -2 are used for calculation of media change or passage on the 'Cell Culture' tab
- mediasubtract = int, 0 or 1. If 1, there will be further precision to account for added reagents taking up volume instead of just calculating the proportion from vinal volume

mediavolume = table with ideal media volumes per plate based on experimental day
- id = int, primary key
- volume = int, volume in ml
- daystart = int, experimental day to start
- dayend = int, experimental day to end

plateinventory = table with data on each individual plate. There are times with multiple plates per batch and plates can be dropped or added. This table allows for individual plates to be added or dropped from daily volume calculations. It is also possible to note what happened to each plate and if plates had any special media circumstances
- id = int, primary key
- batch = int, batch number
- plate = int, plate number
- startdateday0 = date, day 0 of experimental start
- enddate = date, day when plate was stopped
- notes = string, space to add special notes for a plate
- medianotes = string, space to add special notes about media