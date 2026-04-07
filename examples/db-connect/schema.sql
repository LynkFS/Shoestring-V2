-- =============================================================================
-- Scenario 4 — demo_db books table
-- Run against the target MySQL instance (native or Docker).
-- =============================================================================

CREATE DATABASE IF NOT EXISTS demo_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Create a dedicated user with access limited to demo_db.
-- Run as root / admin.
CREATE USER IF NOT EXISTS 'app_user'@'%' IDENTIFIED BY 'changeme';
GRANT SELECT, INSERT, UPDATE, DELETE ON demo_db.* TO 'app_user'@'%';
FLUSH PRIVILEGES;

USE demo_db;

CREATE TABLE IF NOT EXISTS books (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  title      VARCHAR(255)   NOT NULL,
  author     VARCHAR(255)   NOT NULL,
  price      DECIMAL(10,2)  NOT NULL DEFAULT 0,
  stock      INT            NOT NULL DEFAULT 0,
  created_at TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO books (title, author, price, stock) VALUES
  ('The Pragmatic Programmer', 'David Thomas',       49.99, 12),
  ('Clean Code',               'Robert C. Martin',   44.99,  8),
  ('Design Patterns',          'Gang of Four',       54.99,  5),
  ('You Don''t Know JS',       'Kyle Simpson',       39.99, 20),
  ('The Clean Coder',          'Robert C. Martin',   42.99,  7);
