-- Ajout champs identite separes sur profiles :
-- first_name (prenom, optionnel), company (raison sociale, optionnel)
-- display_name reste le nom de famille / libelle principal.

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS first_name text,
  ADD COLUMN IF NOT EXISTS company text;
