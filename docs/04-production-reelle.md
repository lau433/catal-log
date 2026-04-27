# Passage vers une production réelle — Analyse EC06

## Introduction

Ce projet simule une chaîne CI/CD complète dans GitHub. Il ne met pas en œuvre une vraie production. Cette section analyse ce qu'il faudrait ajouter ou modifier pour transformer cette simulation en système de production réel et fiable.

---

## Point 1 — Gestion des secrets

### Situation actuelle
Le seul "secret" utilisé est le `GITHUB_TOKEN`, généré automatiquement par GitHub Actions. Il est éphémère, scopé et ne nécessite aucune configuration manuelle.

### Ce qu'il faudrait en production

**Règle absolue :** aucun secret dans le code, les fichiers de config, les variables d'environnement non chiffrées, ou les logs.

**Architecture de gestion des secrets en production :**

```
┌─────────────────────────────────────────────────────────┐
│                    Pipeline CI/CD                       │
│                                                         │
│  GitHub Actions ──→ HashiCorp Vault / AWS Secrets Mgr  │
│                     ↓ (token court durée, audit log)    │
│                  Secret injecté en mémoire             │
│                  (jamais écrit sur disque)             │
└─────────────────────────────────────────────────────────┘
```

**Ce qui irait dans un coffre de secrets :**

| Secret | Usage | Rotation recommandée |
|--------|-------|---------------------|
| Clé SSH de déploiement | Accès aux serveurs cibles | Tous les 90 jours |
| Token registre d'images | Push/pull GHCR ou registre privé | Tous les 30 jours |
| Certificats TLS | HTTPS | Automatique (Let's Encrypt) |
| Credentials base de données | Accès aux données (si applicable) | Tous les 30 jours |
| Clés API monitoring | Datadog, New Relic, etc. | Tous les 90 jours |

**Bonnes pratiques :**
- Principe du moindre privilège : chaque composant n'a accès qu'aux secrets dont il a besoin
- Rotation automatique des secrets (Vault fait ça nativement)
- Audit trail : qui a accédé à quel secret, quand
- Révocation instantanée en cas de compromission

---

## Point 2 — Rollback

### Situation actuelle
Notre pipeline construit des images identifiées par tag semver (`v1.0.0`) et digest SHA256. Ces deux identifiants sont conservés dans GHCR et permettent un rollback.

### Comment revenir en arrière en production

**Méthode 1 — Rollback par tag (rapide, manuel)**

```bash
# En production, on déploie la version précédente
# via le workflow 03-promote.yml en spécifiant l'ancien tag
# → Aller dans GitHub Actions > 03-promote > Run workflow
# → Saisir le tag : v0.9.0 (version précédente)
```

**Méthode 2 — Rollback par digest (garanti, immutable)**

```bash
# Référencer l'image exacte par son digest — immunisé contre tout retag
docker pull ghcr.io/user/catal-log@sha256:a1b2c3d4e5f6...

# En Kubernetes :
kubectl set image deployment/catal-log \
  web=ghcr.io/user/catal-log@sha256:a1b2c3d4e5f6...
```

**Méthode 3 — Rollback Kubernetes natif**

```bash
# Kubernetes garde l'historique des déploiements
kubectl rollout undo deployment/catal-log
kubectl rollout undo deployment/catal-log --to-revision=3
```

### Conditions nécessaires à un rollback fiable

1. **GHCR avec rétention d'images** : ne jamais supprimer les images taguées en production
2. **Historique des digests** : conserver un registre des digests déployés par environnement
3. **Runbook documenté** : procédure de rollback écrite et testée *avant* un incident
4. **Test du rollback** : vérifier régulièrement qu'un rollback fonctionne (chaos engineering)

---

## Point 3 — Sauvegarde et restauration

### Ce qu'il faudrait sauvegarder

| Élément | Méthode | Fréquence |
|---------|---------|-----------|
| **Dépôt GitHub** | `git clone --mirror` vers stockage externe | Quotidien |
| **Workflows** (.github/workflows/) | Inclus dans le dépôt → sauvegarde automatique | — |
| **Images GHCR** | Politique de rétention + export vers registre secondaire | Sur chaque tag prod |
| **Documentation** (docs/) | Inclus dans le dépôt | — |
| **Environnements GitHub** | Export de la configuration via API GitHub | Hebdomadaire |
| **Preuves d'exécution** | Archivage des logs GitHub Actions (90j max natif) | Continu |

### Scénario de restauration complète

```
Perte totale du dépôt GitHub
        ↓
1. Recréer le dépôt depuis le mirror git
   git clone --mirror backup/catal-log.git → nouveau dépôt GitHub

2. Reconfigurer les Environments GitHub
   (recette, production-simulee)

3. Vérifier que les images GHCR sont intactes
   → Si GHCR perdu : re-tagger depuis le registre secondaire

4. Valider le pipeline sur une branche de test
   → Push → CI vert → Tag → Publish → Promote

5. Documenter l'incident dans le compte rendu
```

---

## Éléments complémentaires pour une production réelle

Au-delà des trois points obligatoires, voici deux éléments indispensables en production :

### Répartition de charge (Load Balancing)

En production, plusieurs instances du service web tournent derrière un load balancer (Nginx Ingress, HAProxy, AWS ALB). Les requêtes sont distribuées entre les instances, ce qui garantit disponibilité et performance. Notre `docker compose --scale web=2` simule l'existence de plusieurs instances mais sans aucun load balancer devant elles.

### Contrôle des vulnérabilités (CVE scanning)

En production, chaque image Docker est scannée automatiquement dans le pipeline CI avant publication :
- **Trivy** (open source, intégrable dans GitHub Actions) : scan de l'image et du filesystem
- **Snyk** : scan avec recommandations de correction
- **Dependabot** : alertes sur les dépendances vulnérables dans GHCR

Le build serait bloqué si des vulnérabilités de sévérité CRITICAL ou HIGH sont détectées.
