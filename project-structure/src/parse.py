"""Stage 3: turn raw HTML into the structured tables.

For every raw_pages row where parse_status = 'pending' (one transaction each):
    1. read common fields -> listings
    2. resolve location -> cities / districts / metro_stations / landmarks
    3. sale_details or rent_details (from deal type)
    4. apartments / houses / offices / commercial_properties (from property type)
    5. first price -> price_history
    success -> parse_status = 'ok'
    error   -> roll back, parse_status = 'failed'
"""


def main():
    # TODO
    pass


if __name__ == "__main__":
    main()
