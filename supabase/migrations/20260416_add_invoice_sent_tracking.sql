-- Historique d'envoi des factures
ALTER TABLE invoices
  ADD COLUMN IF NOT EXISTS sent_at timestamptz,
  ADD COLUMN IF NOT EXISTS sent_via text,
  ADD COLUMN IF NOT EXISTS sent_to text;
