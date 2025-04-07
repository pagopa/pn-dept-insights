CREATE TABLE IF NOT EXISTS weather_data (
    id SERIAL PRIMARY KEY,
    city VARCHAR(255) NOT NULL,
    temperature FLOAT NOT NULL,
    humidity INTEGER NOT NULL,
    pressure INTEGER NOT NULL,
    wind_speed FLOAT NOT NULL,
    description VARCHAR(255) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_weather_data_city ON weather_data(city);
CREATE INDEX IF NOT EXISTS idx_weather_data_timestamp ON weather_data(timestamp);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'weather_data_city_timestamp_unique' AND conrelid = 'weather_data'::regclass
    ) THEN
        ALTER TABLE weather_data
        ADD CONSTRAINT weather_data_city_timestamp_unique UNIQUE (city, timestamp);
    END IF;
END;
$$;

GRANT SELECT, INSERT, UPDATE ON weather_data TO dbadmin;
GRANT USAGE, SELECT ON SEQUENCE weather_data_id_seq TO dbadmin;
