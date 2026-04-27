# Architecture CI/CD — Catal-Log / EC06

## Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DÉVELOPPEUR                                   │
│  git commit + git push / git tag v*                                 │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         GITHUB                                       │
│                                                                     │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────┐  │
│  │  01-ci.yml       │    │  02-publish.yml  │    │ 03-promote   │  │
│  │                  │    │                  │    │  .yml        │  │
│  │  • Hadolint      │    │  • Build image   │    │              │  │
│  │  • docker build  │    │  • Tags semver   │    │ workflow_    │  │
│  │  • Test HTTP 200 │    │  • Push GHCR     │    │ dispatch     │  │
│  │  • Test contenu  │    │  • Digest SHA256 │    │ (manuel)     │  │
│  └──────────────────┘    └────────┬─────────┘    └──────┬───────┘  │
│  Déclenché sur :         Déclenché sur :          Déclenché par :   │
│  push main/develop       git tag v*               clic humain       │
│  pull_request                                                        │
└────────────────────────────────────────────────────────────────────┬┘
                                   │                         │
                                   ▼                         ▼
                    ┌──────────────────────┐   ┌────────────────────────┐
                    │  GHCR                │   │  ENVIRONNEMENTS GITHUB │
                    │                      │   │                        │
                    │  ghcr.io/user/       │   │  • recette             │
                    │  catal-log:          │   │  • production-simulee  │
                    │  • v1.0.0            │   │                        │
                    │  • sha-a1b2c3d       │   │  (simulation locale    │
                    │  • latest            │   │   via compose.yml)     │
                    │  • production-simulee│   │                        │
                    └──────────────────────┘   └────────────────────────┘
```

## Flux complet d'un déploiement

| Étape | Action | Outil | Preuve |
|-------|--------|-------|--------|
| 1 | Commit du code | Git | `git log` |
| 2 | Lint + build + test | GitHub Actions (01-ci.yml) | Run Actions ✅ |
| 3 | Tag git `v1.0.0` | Git | Tag visible sur GitHub |
| 4 | Build + push GHCR | GitHub Actions (02-publish.yml) | Image GHCR + digest |
| 5 | Validation recette | GitHub Actions (03-promote.yml) | Env "recette" ✅ |
| 6 | Promotion manuelle | workflow_dispatch | Env "production-simulee" ✅ |

## Composants techniques

| Composant | Version / Type | Rôle |
|-----------|---------------|------|
| GitHub Actions | Cloud (ubuntu-latest) | Exécution des workflows CI/CD |
| Docker | Buildkit | Construction des images |
| Nginx | Alpine (~8 Mo) | Serveur web pour les fichiers statiques |
| GHCR | ghcr.io | Registre d'images Docker |
| crane | v0.19.1 | Retag sans rebuild (promotion) |
| Docker Compose | v2 | Orchestration locale multi-services |

## Choix techniques et justifications

**Pourquoi nginx:alpine et pas nginx:latest ?**
L'image Alpine est ~22× plus légère (8 Mo vs 180 Mo). Moins de paquets = moins de surface d'attaque. Pour un site statique, toutes les fonctionnalités nécessaires sont présentes.

**Pourquoi séparer CI (01) et Publish (02) ?**
Séparation des responsabilités. Le CI valide à chaque push (rapide, fréquent). La publication ne se déclenche que sur un tag explicite (acte délibéré). Évite de polluer GHCR avec des images non validées.

**Pourquoi crane pour la promotion ?**
`docker pull + docker tag + docker push` télécharge et re-uploade l'image entière (~8 Mo). `crane tag` copie uniquement le manifest JSON (quelques Ko). Plus rapide, et surtout : **le digest SHA256 reste identique**, garantissant l'immutabilité de l'artefact.

## Schéma enrichi — comparaison avec une vraie production

```
APPROCHE PÉDAGOGIQUE (ce projet)      PRODUCTION RÉELLE
─────────────────────────────────     ─────────────────────────────────
GitHub Environments simulés       →   Serveurs réels (VM, K8s, cloud)
workflow_dispatch = "déploiement" →   kubectl apply / Helm upgrade
compose.yml local                 →   Kubernetes manifests / Helm charts
Pas de load balancer              →   Ingress Controller (Nginx/Traefik)
Scaling simulé (--scale)          →   HPA (Horizontal Pod Autoscaler)
GHCR comme registre               →   ECR / GCR / registre privé maîtrisé
```
