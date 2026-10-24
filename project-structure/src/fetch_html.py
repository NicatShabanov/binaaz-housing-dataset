"""Stage 2: download the HTML of every listing.

For every raw_pages row where html is empty:
    download the page
    save html, http_status, content_hash, fetched_at
    retry a few times on errors, then record the failure
    wait REQUEST_DELAY_SECONDS between requests
No parsing here. Only raw data is stored.
"""


def main():
    # TODO
    pass


if __name__ == "__main__":
    main()
