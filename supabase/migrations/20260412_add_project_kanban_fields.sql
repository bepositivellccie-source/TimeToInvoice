-- Migration : Kanban projets — ajout status + sort_order
-- Date : 2026-04-12
-- Exécutée sur Supabase (projet sttcfljbnmtfwfdztkbp)

ALTER TABLE projects
  ADD COLUMN status text NOT NULL DEFAULT 'en_cours',
  ADD COLUMN sort_order integer NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_projects_kanban
  ON projects (client_id, status, sort_order);
