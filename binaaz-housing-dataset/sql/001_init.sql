-- 001_init.sql — bina.az layihəsi, başlanğıc sxem (PostgreSQL 14+)
--
-- Qatlar:
--   1) raw_pages            : yüklənmiş HTML (dəyişməz mənbə)
--   2) cities, districts,
--      metro_stations,
--      landmarks            : yer lookup cədvəlləri
--   3) listings             : hər elanda olan ortaq sahələr
--   4) sale_details,
--      rent_details         : əməliyyat növünə məxsus sahələr (listing_id ilə 1:1)
--   5) apartments, houses,
--      offices,
--      commercial_properties: əmlak növünə məxsus sahələr (listing_id ilə 1:1)
--   6) price_history        : qiymətin zamanla dəyişməsi
--
-- Qeyd: qaraj və torpaq üçün ayrıca cədvəl yoxdur, çünki onların bütün
-- sahələri (qiymət, sahə, yer) artıq listings-dədir.

BEGIN;

-- 1. RAW QAT ----------------------------------------------------------
CREATE TABLE raw_pages (
    listing_id    BIGINT      PRIMARY KEY,              -- bina.az "Elan nömrəsi"
    url           TEXT        NOT NULL,
    html          TEXT,
    http_status   SMALLINT,
    content_hash  TEXT,                                 -- dəyişməyibsə təkrar parse etməmək üçün
    fetched_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    parse_status  TEXT        NOT NULL DEFAULT 'pending'
                  CHECK (parse_status IN ('pending', 'ok', 'failed'))
);

-- 2. YER LOOKUP CƏDVƏLLƏRİ -------------------------------------------
CREATE TABLE cities (
    city_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name     TEXT NOT NULL UNIQUE
);

-- Rayon seçimi yalnız bəzi şəhərlərdə var (Bakı, Xaçmaz, Astara, Naxçıvan, Ağdam, Gədəbəy)
CREATE TABLE districts (
    district_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_id     INTEGER NOT NULL REFERENCES cities (city_id),
    name        TEXT    NOT NULL,
    UNIQUE (city_id, name)
);

-- Metro və nişangah seçimi yalnız Bakıda var
CREATE TABLE metro_stations (
    metro_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name     TEXT NOT NULL UNIQUE
);

CREATE TABLE landmarks (
    landmark_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE
);

-- 3. ÜMUMİ QAT --------------------------------------------------------
CREATE TABLE listings (
    listing_id    BIGINT PRIMARY KEY REFERENCES raw_pages (listing_id),
    deal_type     TEXT NOT NULL CHECK (deal_type IN ('sale', 'rent')),
    property_type TEXT NOT NULL CHECK (property_type IN
                      ('apartment', 'house', 'office', 'garage', 'land', 'commercial')),
    -- Kirayədə qiymət rent_details.rent_term-ə görə günlük və ya aylıqdır
    price         NUMERIC(14, 2) CHECK (price >= 0),
    currency      TEXT NOT NULL DEFAULT 'AZN',
    -- Bütün əmlak növlərində var. Torpaqda sot m²-ə çevrilir (1 sot = 100 m²).
    area_m2       NUMERIC(12, 2) CHECK (area_m2 > 0),
    city_id       INTEGER REFERENCES cities (city_id),
    district_id   INTEGER REFERENCES districts (district_id),
    metro_id      INTEGER REFERENCES metro_stations (metro_id),
    landmark_id   INTEGER REFERENCES landmarks (landmark_id),
    latitude      DOUBLE PRECISION CHECK (latitude  BETWEEN -90  AND 90),
    longitude     DOUBLE PRECISION CHECK (longitude BETWEEN -180 AND 180),
    description   TEXT,
    posted_at     TIMESTAMPTZ,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
    -- Aşağıdakı iki UNIQUE əlavə cədvəllərin birləşmiş FK-si üçün lazımdır
    UNIQUE (listing_id, deal_type),
    UNIQUE (listing_id, property_type)
);

CREATE INDEX idx_listings_types    ON listings (property_type, deal_type);
CREATE INDEX idx_listings_district ON listings (district_id);

-- 4. ƏMƏLİYYAT NÖVÜNƏ MƏXSUS CƏDVƏLLƏR -------------------------------
CREATE TABLE sale_details (
    listing_id          BIGINT PRIMARY KEY,
    deal_type           TEXT NOT NULL DEFAULT 'sale' CHECK (deal_type = 'sale'),
    has_title_extract   BOOLEAN,   -- çıxarış var
    has_mortgage        BOOLEAN,   -- ipoteka var
    has_internal_credit BOOLEAN,   -- daxili kredit
    FOREIGN KEY (listing_id, deal_type) REFERENCES listings (listing_id, deal_type)
);

CREATE TABLE rent_details (
    listing_id BIGINT PRIMARY KEY,
    deal_type  TEXT NOT NULL DEFAULT 'rent' CHECK (deal_type = 'rent'),
    rent_term  TEXT NOT NULL CHECK (rent_term IN ('daily', 'long_term')),
    FOREIGN KEY (listing_id, deal_type) REFERENCES listings (listing_id, deal_type)
);

-- 5. ƏMLAK NÖVÜNƏ MƏXSUS CƏDVƏLLƏR ------------------------------------
CREATE TABLE apartments (
    listing_id    BIGINT PRIMARY KEY,
    property_type TEXT NOT NULL DEFAULT 'apartment' CHECK (property_type = 'apartment'),
    building_type TEXT CHECK (building_type IN ('new', 'old')),
    rooms         SMALLINT CHECK (rooms > 0),
    renovated     BOOLEAN,                -- təmirli / təmirsiz
    floor         SMALLINT,
    floor_total   SMALLINT,               -- elan səhifəsində yoxlanmalıdır
    CHECK (floor <= floor_total),
    FOREIGN KEY (listing_id, property_type) REFERENCES listings (listing_id, property_type)
);

-- Həyət evi / bağ evi. area_m2 (listings-də) tikilinin sahəsidir.
CREATE TABLE houses (
    listing_id      BIGINT PRIMARY KEY,
    property_type   TEXT NOT NULL DEFAULT 'house' CHECK (property_type = 'house'),
    rooms           SMALLINT CHECK (rooms > 0),
    renovated       BOOLEAN,
    land_area_sot   NUMERIC(10, 2) CHECK (land_area_sot > 0),
    FOREIGN KEY (listing_id, property_type) REFERENCES listings (listing_id, property_type)
);

CREATE TABLE offices (
    listing_id    BIGINT PRIMARY KEY,
    property_type TEXT NOT NULL DEFAULT 'office' CHECK (property_type = 'office'),
    building_type TEXT CHECK (building_type IN ('business_center', 'apartment_house', 'villa')),
    rooms         SMALLINT CHECK (rooms > 0),
    renovated     BOOLEAN,
    FOREIGN KEY (listing_id, property_type) REFERENCES listings (listing_id, property_type)
);

-- "Obyekt"
CREATE TABLE commercial_properties (
    listing_id    BIGINT PRIMARY KEY,
    property_type TEXT NOT NULL DEFAULT 'commercial' CHECK (property_type = 'commercial'),
    renovated     BOOLEAN,
    FOREIGN KEY (listing_id, property_type) REFERENCES listings (listing_id, property_type)
);

-- 6. QİYMƏT TARİXÇƏSİ -------------------------------------------------
CREATE TABLE price_history (
    history_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id  BIGINT NOT NULL REFERENCES listings (listing_id),
    price       NUMERIC(14, 2) NOT NULL CHECK (price >= 0),
    currency    TEXT NOT NULL DEFAULT 'AZN',
    observed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_price_history_listing ON price_history (listing_id, observed_at);

-- 7. NÜMUNƏ VIEW: analiz və ML üçün düz (flat) görünüş -----------------
CREATE VIEW v_apartments AS
SELECT
    l.listing_id,
    l.deal_type,
    l.price,
    l.area_m2,
    a.rooms,
    a.floor,
    a.floor_total,
    a.building_type,
    a.renovated,
    c.name  AS city,
    d.name  AS district,
    m.name  AS metro,
    l.latitude,
    l.longitude,
    r.rent_term,
    s.has_title_extract,
    s.has_mortgage,
    s.has_internal_credit
FROM listings l
JOIN apartments a            ON a.listing_id = l.listing_id
LEFT JOIN cities c           ON c.city_id = l.city_id
LEFT JOIN districts d        ON d.district_id = l.district_id
LEFT JOIN metro_stations m   ON m.metro_id = l.metro_id
LEFT JOIN rent_details r     ON r.listing_id = l.listing_id
LEFT JOIN sale_details s     ON s.listing_id = l.listing_id;

COMMIT;
