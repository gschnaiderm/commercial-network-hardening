-- 1. Create the page_visits table
CREATE TABLE IF NOT EXISTS page_visits (
    id SERIAL PRIMARY KEY,
    visit_count INT NOT NULL DEFAULT 0
);

-- 2. Insert initial row
INSERT INTO page_visits (id, visit_count)
VALUES (1, 0)
ON CONFLICT (id) DO NOTHING;

-- 3. Implement Least Privilege Security
-- Create a highly restricted user specifically for the web application
CREATE ROLE web_client WITH LOGIN PASSWORD 'web_client_secret';

-- Revoke default public access (Best Practice)
REVOKE ALL ON DATABASE webapp_db FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- Grant only what is strictly necessary to the web_client
GRANT CONNECT ON DATABASE webapp_db TO web_client;
GRANT USAGE ON SCHEMA public TO web_client;

-- The web server only needs to read and increment the visit_count column
GRANT SELECT, UPDATE ON TABLE page_visits TO web_client;
