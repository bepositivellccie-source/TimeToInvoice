-- Régime TVA sur profiles :
-- 'franchise' (défaut) : auto-entrepreneur art. 293 B, pas de TVA
-- 'assujetti' : TVA collectée au taux défini dans tva_rate (20 par défaut)

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS tva_regime text NOT NULL DEFAULT 'franchise'
    CHECK (tva_regime IN ('franchise', 'assujetti')),
  ADD COLUMN IF NOT EXISTS tva_rate numeric(5,2) DEFAULT 20.00;
