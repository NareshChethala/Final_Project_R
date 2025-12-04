#!/bin/bash
rm -f data/sec_data.sqlite
R -e "shiny::runApp('app.R', launch.browser=TRUE)"
