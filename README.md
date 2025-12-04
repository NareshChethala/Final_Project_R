# SEC Data Viewer

A Shiny application and JSON API for exploring SEC filings, visualizing financial data, and performing sentiment analysis on 10-K reports.

## Features

-   **Search**: Find companies by CIK or Name.
-   **Financials**: Visualize key metrics (e.g., Net Income, Assets) over the last 5 years.
-   **10-K Reader**: View filings with **Raw** or **Cleaned** text options.
    -   *Cleaned Text* removes tables, XBRL, and the Table of Contents for a better reading experience.
-   **Sentiment Analysis**: Analyze the tone of filings using the Loughran-McDonald dictionary.

## Quick Start

1.  **Configure**: Create `config.json` with your email (required by SEC):
    ```json
    {
      "user_agent": "your.email@example.com",
      "db_path": "data/sec_data.sqlite"
    }
    ```

2.  **Run App**:
    ```bash
    ./run_app.sh
    ```

3.  **Run API**:
    ```bash
    ./run_api.sh
    ```

## Documentation

For a detailed technical guide on the project structure, components, and logic, please see [IMPLEMENTATION.md](IMPLEMENTATION.md).

## Requirements

-   R (with packages: `shiny`, `plumber`, `httr`, `jsonlite`, `dplyr`, `DBI`, `RSQLite`, `rvest`, `ggplot2`, `DT`, `tidytext`, `stringr`, `xml2`, `readr`, `tidyr`)
