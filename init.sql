-- Initialize development database
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create a development user (optional)
-- CREATE USER sertantai_dev WITH PASSWORD 'dev_password';
-- GRANT ALL PRIVILEGES ON DATABASE sertantai_dev TO sertantai_dev;

-- Set up basic permissions
\c sertantai_dev;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";