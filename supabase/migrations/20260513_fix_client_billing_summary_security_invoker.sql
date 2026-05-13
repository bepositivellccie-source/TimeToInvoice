-- Same fix as project_billing_status. The view client_billing_summary
-- bypassed RLS because it ran with the owner's privileges (postgres).
-- Although the Flutter app does not currently read this view, it is
-- exposed via PostgREST and could leak every user's billing aggregates.
ALTER VIEW public.client_billing_summary SET (security_invoker = true);
