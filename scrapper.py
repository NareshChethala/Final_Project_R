import requests
from bs4 import BeautifulSoup

def extract_filing_html_directly(row, user_agent_email):
    """
    Extract the actual 10-K/8-K filing HTML from the master .idx row.

    Args:
        row (dict or pandas.Series): Must contain a 'Filename' field.
        user_agent_email (str): Email for SEC-compliant User-Agent header.

    Returns:
        (filing_url, html_content)
        filing_url: The final URL attempted (or None)
        html_content: Raw HTML string of the filing (or None)
    """

    try:
        # ---------------------------------------------------------
        # 1. Parse filename path: "edgar/data/<CIK>/<ACCESSION>/..."
        # ---------------------------------------------------------
        filename = str(row["Filename"]).strip().replace(" ", "")
        path_parts = filename.split("/")

        if len(path_parts) < 4:
            print(f"Invalid path in Filename: {filename}")
            return None, None

        cik = path_parts[2]
        accession_with_dashes = path_parts[3]
        accession_nodashes = accession_with_dashes.replace("-", "")
        index_filename = accession_with_dashes + "-index.htm"

        # ---------------------------------------------------------
        # 2. Build the SEC index page URL
        # ---------------------------------------------------------
        index_url = (
            f"https://www.sec.gov/Archives/edgar/data/"
            f"{cik}/{accession_nodashes}/{index_filename}"
        )

        headers = {"User-Agent": user_agent_email}

        response = requests.get(index_url, headers=headers, timeout=10)
        if response.status_code != 200:
            print(f"Failed to load index page: {index_url}")
            return None, None

        # Parse the index page
        soup = BeautifulSoup(response.text, "html.parser")

        # SEC uses <table class="tableFile"> for document table
        doc_table = soup.find("table", class_="tableFile")
        if doc_table is None:
            print(f"Could not find document table at: {index_url}")
            return None, None

        # ---------------------------------------------------------
        # 3. Find the first filing .htm file (NOT -index.htm)
        # ---------------------------------------------------------
        doc_link_tag = doc_table.find(
            "a",
            href=lambda href: href 
            and href.endswith(".htm") 
            and not href.endswith("-index.htm")
        )

        if doc_link_tag is None:
            print(f"No .htm filing document found: {index_url}")
            return None, None

        # Remove leading slash
        primary_doc = doc_link_tag["href"].lstrip("/")

        # FIX — final filing URL must NOT repeat Archives
        filing_url = f"https://www.sec.gov/{primary_doc}"

        # ---------------------------------------------------------
        # 4. Download the main filing HTML
        # ---------------------------------------------------------
        filing_response = requests.get(filing_url, headers=headers, timeout=15)

        if filing_response.status_code == 200:
            print(f"Downloaded: {filing_url}")
            return filing_url, filing_response.text
        else:
            print(f"Failed to download filing from: {filing_url}")
            return filing_url, None

    except Exception as e:
        print(f"Exception occurred: {str(e)}")
        return None, None