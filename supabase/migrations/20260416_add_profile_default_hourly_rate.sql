-- Add default hourly rate to profiles for pre-filling new project creation
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS default_hourly_rate numeric;
