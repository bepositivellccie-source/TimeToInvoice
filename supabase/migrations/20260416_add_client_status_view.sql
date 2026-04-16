-- Vue client_status : statut de facturation agrege par client + tous les champs clients
-- 'overdue' : au moins une facture non-paid avec due_at < now
-- 'pending' : au moins une facture sent non en retard
-- 'clear'   : au moins une facture, toutes payees / annulees
-- 'new'     : aucune facture

DROP VIEW IF EXISTS public.client_status;

CREATE VIEW public.client_status AS
SELECT
  c.*,
  count(i.id) AS total_invoices,
  count(CASE WHEN i.status <> 'paid' AND i.due_at < now() THEN 1 END) AS overdue_count,
  count(CASE WHEN i.status = 'sent' AND (i.due_at IS NULL OR i.due_at >= now()) THEN 1 END) AS pending_count,
  count(CASE WHEN i.status = 'paid' THEN 1 END) AS paid_count,
  CASE
    WHEN count(CASE WHEN i.status <> 'paid' AND i.due_at < now() THEN 1 END) > 0 THEN 'overdue'
    WHEN count(CASE WHEN i.status = 'sent' AND (i.due_at IS NULL OR i.due_at >= now()) THEN 1 END) > 0 THEN 'pending'
    WHEN count(i.id) > 0 THEN 'clear'
    ELSE 'new'
  END AS billing_status
FROM public.clients c
LEFT JOIN public.invoices i ON i.client_id = c.id
GROUP BY c.id;

-- La vue herite des policies RLS de clients (PG 15+)
ALTER VIEW public.client_status SET (security_invoker = true);
