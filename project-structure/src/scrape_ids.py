"""Stage 1: collect listing IDs.

For every (deal type x property type) search:
    open the search pages until they run out
    save (listing_id, url, source_category) into raw_pages
    with parse_status = 'pending'  (ON CONFLICT DO NOTHING)
    wait REQUEST_DELAY_SECONDS between requests
"""


def main():
    # TODO
    pass


if __name__ == "__main__":
    main()
