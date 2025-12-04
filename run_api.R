library(plumber)

# Load the API definition
r <- plumb("api.R")

# Run the API on port 8000
r$run(port = 8000)
