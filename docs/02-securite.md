# Fiche Sécurité — Catal-Log / EC06

## 1. Gestion des secrets

### Principe fondamental
**Aucun secret ne doit jamais apparaître dans le code source, les fichiers de configuration ou les logs.**

Un secret dans un dépôt Git est compromis définitivement — même après suppression, l'historique Git conserve la trace. Des outils automatisés (GitGuardian, TruffleHog) scannent GitHub en continu.

### GITHUB_TOKEN — secret automatique

GitHub Actions génère automatiquement un `GITHUB_TOKEN` pour chaque exécution de workflow. Il est :
- **Temporaire** : expire à la fin du workflow
- **Scopé** : permissions définies dans le fichier YAML (`permissions:`)
- **Jamais stocké** : injecté en mémoire uniquement pendant le run
- **Non exportable** : ne peut pas être exfiltré via les logs (masqué automatiquement)

```yaml
# ✅ Bonne pratique : permissions minimales déclarées explicitement
permissions:
  contents: read   # lire le code
  packages: write  # pousser dans GHCR uniquement

# Usage dans le workflow
password: ${{ secrets.GITHUB_TOKEN }}
```

### Ce qui irait dans GitHub Secrets en production

| Secret | Valeur exemple | Pourquoi pas dans le code |
|--------|---------------|--------------------------|
| `REGISTRY_TOKEN` | Token d'un registre privé | Accès en écriture au registre |
| `DEPLOY_SSH_KEY` | Clé SSH privée | Accès aux serveurs de déploiement |
| `SLACK_WEBHOOK` | URL de webhook | Accès aux notifications |
| `SONAR_TOKEN` | Token SonarCloud | Accès à l'analyse de code |

### Ce qui irait dans un coffre de secrets en vraie production

En production réelle, on utiliserait **HashiCorp Vault**, **AWS Secrets Manager** ou **Azure Key Vault** plutôt que GitHub Secrets, car :
- Rotation automatique des secrets
- Audit trail (qui a accédé à quoi, quand)
- Révocation instantanée
- Intégration avec les systèmes d'identité d'entreprise

## 2. Sécurité de l'image Docker

### Choix de l'image de base

```dockerfile
# ✅ Utilisation d'une image officielle, maintenue, légère
FROM nginx:alpine
# vs nginx:latest → ~22× plus lourde, plus de CVE potentielles
```

**Labels OCI** : traçabilité complète de l'image (qui l'a buildée, quand, quel commit).

```dockerfile
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"
```

### Lint avec Hadolint

Hadolint analyse le Dockerfile avant le build et signale les anti-patterns :
- Instructions non optimales (couches inutiles)
- Packages sans version fixée
- Commandes dangereuses

Intégré dans `01-ci.yml` — le build échoue si Hadolint détecte des erreurs critiques.

### Digest SHA256 comme garantie d'intégrité

Le digest est l'empreinte cryptographique du contenu exact de l'image :

```
ghcr.io/user/catal-log@sha256:a1b2c3d4e5f6...
```

Contrairement à un tag (mutable), le digest est **immuable**. Référencer une image par son digest garantit qu'on déploie exactement ce qui a été validé.

## 3. Analyse des risques résiduels

| Risque | Niveau | Mitigation en place | Mitigation prod réelle |
|--------|--------|---------------------|----------------------|
| Image de base vulnérable | Moyen | nginx:alpine (surface réduite) | Scan Trivy/Snyk en CI |
| Fuite de secrets dans les logs | Faible | GITHUB_TOKEN masqué auto | Audit régulier des logs |
| Tag mutable (`latest`) | Moyen | Digest utilisé en promotion | Toujours référencer par digest |
| Pas d'utilisateur non-root | Faible | Nginx alpine tourne en root | Ajouter `USER nginx` si possible |
| Pas de scan de vulnérabilités | Moyen | Hors périmètre EC06 | Trivy dans le pipeline CI |

## 4. Ce que nous n'avons PAS mis en place (limites honnêtes)

- **Scan de vulnérabilités** (Trivy, Snyk) : non requis par EC06 mais indispensable en prod
- **Signature d'image** (Cosign/Sigstore) : garantit l'authenticité de l'image
- **SBOM** (Software Bill of Materials) : inventaire des dépendances de l'image
- **Politique de rotation des secrets** : non applicable avec GITHUB_TOKEN (éphémère par nature)
- **Réseau privé pour GHCR** : l'accès est public (dépôt public) — en prod, registre privé
