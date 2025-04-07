DO $$
DECLARE
    app_username TEXT := 'db_svc_user';
    db_name TEXT := 'jirametrics';
    schema_name TEXT := 'public';
    table_name TEXT := 'weather_data';
    sequence_name TEXT := 'weather_data_id_seq';
    placeholder_password TEXT := 'pwd_here';
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = app_username) THEN
        EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L', app_username, placeholder_password);
    ELSE
        PERFORM 1;
    END IF;

    EXECUTE format('GRANT CONNECT ON DATABASE %I TO %I', db_name, app_username);
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO %I', schema_name, app_username);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON TABLE %I.%I TO %I', schema_name, table_name, app_username);
    EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %I.%I TO %I', schema_name, sequence_name, app_username);

END;
$$;