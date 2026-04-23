# TEST_PLAN — Refonte ChronoFacture v2 (S23 Ultra)

9 chantiers livrés en local (refonte design + flows + mode test + vocab).
Plan de validation : **22 vérifications, ~30 min** sur device.

**Pré-requis** : `flutter run --release` sur S23 Ultra USB.
**Compte** : utilise un projet réel avec ≥2 sessions non facturées.

---

## Chantier 1 — Navbar 4 onglets (1 min)

- [ ] 1. Bottom nav affiche **Accueil / Chrono / Factures / Menu** (4 items, pas 5)
- [ ] 2. État sélectionné cohérent (icône remplie + label primary, autres muted)
- [ ] 3. Tap sur chaque onglet préserve le scroll des autres (StatefulShellRoute)

---

## Chantier 2 — Chrono refondu (3 min)

- [ ] 4. **État repos** sans projet : sélecteur dashed "Choisir un projet", `00:00:00` JetBrainsMono, bouton play 88px (CF.accentB) avec halo
- [ ] 5. Sélectionne un projet → bouton play passe actif → tap → **état actif** : point pulsant rouge + label "Session en cours" + boutons Pause/Stop bordeaux
- [ ] 6. Footer actif : total + montant en temps réel ; footer repos : carrousel projets récents

---

## Chantier 3 — Accueil refondu (2 min)

- [ ] 7. Hero KPI semaine en haut (heures + montant, JetBrainsMono tabular)
- [ ] 8. Section **À faire** : cards actionnables (factures à envoyer / encaisser / relancer) — tap → écran cible
- [ ] 9. Section **Récent** : 3 dernières sessions, tap → projet

---

## Chantier 4 — Menu + Paramètres (2 min)

- [ ] 10. Onglet Menu : profil + listes groupées (Activité / Paramètres / Aide), pas de leftover Material 2
- [ ] 11. Paramètres → toggle **Mode test** persiste (kill app + relance, état conservé)

---

## Chantier 5 — Choisir un projet (1 min)

- [ ] 12. Picker projet (depuis Chrono) : recherche live + cards client/projet, tap → sélection + retour

---

## Chantier 6 — Flow facturation 3 étapes (5 min)

- [ ] 13. Card projet → "Facturer" → **Étape 1/3** avec progress bar + counter
- [ ] 14. Étape 1 : décocher 1 session → total recalculé → CTA "Suivant"
- [ ] 15. Étape 2 : segmented 15/30/60j + date picker → "Échéance le …" mise à jour → "Suivant"
- [ ] 16. Étape 3 : récap (client / total / dates) + thumb PDF → CTA "Générer la facture" (CF.accentB)
- [ ] 17. Tap Générer → facture créée, PDF s'ouvre

---

## Chantier 7 — Liste + Détail + PDF refaits (4 min)

- [ ] 18. Onglet Factures : header maison (pas d'AppBar), search + chips Toutes/À encaisser/En retard/Payées, liste groupée par mois
- [ ] 19. Tap row → **InvoiceDetailScreen plein écran** : hero client + AmountCard (gradient vert si payée), bouton retour + corbeille en header
- [ ] 20. Tap "Voir le PDF" → viewer plein écran, header + status pill + bottom bar Envoyer/Encaisser

---

## Chantier 8 — Mode Test visuel (3 min)

- [ ] 21. Active Mode test (Paramètres) → bandeau vert apparaît sur **Chrono** ET **Factures** (tap bandeau → ouvre Menu)
- [ ] 22. Crée facture en mode test :
  - PDF généré avec **filigrane "TEST" diagonal ambre** sur chaque page
  - Liste affiche **badge TEST vert** sous le numéro
  - Détail affiche le badge à côté du numéro en header
  - **Quota mensuel inchangé** (compteur exclut `is_test=true`)

---

## Chantier 9 — Vocabulaire humanisé (1 min)

- [ ] 23. Aucune occurrence visible de :
  - "Marquer comme payée" / "Marquer payée" → doit être **"Encaisser"**
  - "Partager" sur facture → doit être **"Envoyer"** (icône `send`)
  - Snack après action → "Facture **encaissée**", "Facture **envoyée**"

  Le PDF garde "Total HT / TVA / TTC" (mentions légales — normal).

---

## Résultat

Si les 23 cases passent → `git push origin master` (10 commits).
Si une coince → noter le n° + capture, remonter à Claude pour fix ciblé avant push.

---

## Commits couverts (local, non pushés)

| # | Hash | Chantier |
|---|------|----------|
| 1 | `625a2a2` | refactor(nav): 4 onglets |
| 2 | `f95f69e` | refactor(chrono): idle/active states |
| 3 | `9372ba6` | feat(home): KPI semaine + À faire + Récent |
| 4 | `d0760e4` | feat(menu,settings): refonte MD3 |
| 5 | `3e19326` | refactor(project-select): picker v2 |
| 6 | `aa97eb3` | feat(invoice): flow 3 étapes |
| 7 | `21dd602` | refactor(invoices): liste + détail + PDF |
| 8 | `7ee0c86` | feat(test-mode): bandeau + filigrane + quota |
| 9 | `41b36f6` | refactor(ui): vocabulaire (Encaisser/Envoyer) |

`flutter analyze` : **0 issue** sur tous les commits.
