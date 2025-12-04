# Downloading multiple 10-K filings
def download_multiple_10k_filings(df, user_agent_email):
    """
    Show how many 10-Ks are available, let the user choose how many to download,
    and return a DataFrame with filing metadata and text.
    """
    tenk_df = df[df['Form Type'].str.upper() == '10-K'].reset_index(drop=True)
    total = len(tenk_df)

    if total == 0:
        print("No 10-K filings found in the dataset.")
        return pd.DataFrame()

    print(f"Found {total} 10-K filings in the dataset.")
    
    while True:
        try:
            limit = int(input(f"Enter the number of 10-K filings to download (1 to {total}): "))
            if 1 <= limit <= total:
                break
            else:
                print(f"Please enter a number between 1 and {total}.")
        except ValueError:
            print("Please enter a valid integer.")

    results = []
    for idx, row in tenk_df.head(limit).iterrows():
        url, html_text = extract_filing_html_directly(row, user_agent_email)
        if html_text:
            cleaned_text = clean_filing_html(html_text)
            results.append({
                "Company Name": row['Company Name'],
                "CIK": row['CIK'],
                "Date Filed": row['Date Filed'],
                "Filing URL": url,
                "Filing Text": html_text,
                "Cleaned Text": cleaned_text
            })

    return pd.DataFrame(results)