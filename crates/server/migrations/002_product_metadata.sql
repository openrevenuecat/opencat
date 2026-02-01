-- Add display metadata columns to products table
ALTER TABLE products ADD COLUMN display_name TEXT;
ALTER TABLE products ADD COLUMN description TEXT;
ALTER TABLE products ADD COLUMN price_micros INTEGER;
ALTER TABLE products ADD COLUMN currency TEXT;
ALTER TABLE products ADD COLUMN subscription_period TEXT;
ALTER TABLE products ADD COLUMN trial_period TEXT;
ALTER TABLE products ADD COLUMN last_synced_at TEXT;
