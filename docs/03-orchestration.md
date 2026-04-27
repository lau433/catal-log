# Orchestration et Scaling — Catal-Log / EC06

## 1. Rôle de Docker Compose comme orchestrateur léger

Docker Compose est un outil de définition et d'exécution d'applications **multi-conteneurs** sur un **hôte unique**. Il répond à la question : "Comment décrire et démarrer un ensemble de services qui fonctionnent ensemble ?"

### Ce qu'il fait bien

- Décrire l'architecture d'une application en un fichier déclaratif (`compose.yml`)
- Gérer les dépendances entre services (`depends_on`)
- Créer des réseaux isolés entre conteneurs
- Simplifier le développement local (un `docker compose up` lance tout)
- Documenter les variables d'environnement nécessaires

### Ce qu'il ne fait pas

- Distribuer les conteneurs sur plusieurs machines
- Gérer la haute disponibilité automatiquement
- Faire du rolling update sans interruption
- Auto-scaler selon la charge CPU/mémoire

## 2. Notre architecture multi-services

```yaml
services:
  web:    # Site statique Catal-Log (Nginx)
  whoami: # Service de diagnostic (traefik/whoami)
```

**Pourquoi un second service ?**
Le service `whoami` illustre la coordination multi-conteneurs. Il répond aux requêtes HTTP en retournant le hostname et l'IP du conteneur qui a traité la requête. Cela devient particulièrement utile pour la simulation de scaling.

**Communication inter-services :**
Les deux services partagent le réseau `catal-log-net`. Depuis le conteneur `web`, on peut joindre `whoami` via son nom DNS interne : `http://whoami:80`.

## 3. Simulation de scaling

### Prérequis
Commenter la directive `ports` du service `web` dans `compose.yml` (deux conteneurs ne peuvent pas se lier au même port hôte).

### Commande

```bash
# Lancer 2 instances du service web
docker compose up -d --scale web=2

# Vérifier les conteneurs en cours
docker compose ps

# Résultat attendu :
# NAME                    IMAGE               STATUS
# projetcicd-web-1        catal-log:latest    Up
# projetcicd-web-2        catal-log:latest    Up
# catal-log-whoami        traefik/whoami      Up
```

### Observation avec whoami

```bash
# Chaque appel retourne un hostname différent → les 2 réplicas sont actifs
curl http://localhost:8081
# Hostname: projetcicd-web-1
# IP: 172.18.0.2

curl http://localhost:8081
# Hostname: projetcicd-web-2
# IP: 172.18.0.3
```

### Ce que cette simulation montre

- Deux instances du même service tournent simultanément
- Elles partagent le même réseau interne
- Le hostname diffère → elles sont bien indépendantes

### Ce que cette simulation NE montre PAS

- Pas de répartition automatique des requêtes entre les deux instances (pas de load balancer)
- Si `web-1` tombe, les clients pointant dessus ne basculent pas sur `web-2`
- Le scaling est manuel (pas d'auto-scaling selon la charge)

## 4. Limites de Docker Compose vs production réelle

| Critère | Docker Compose (ce projet) | Kubernetes (production) |
|---------|---------------------------|------------------------|
| Hôtes | 1 seul | Multi-nœuds distribués |
| Scaling | Manuel (`--scale N`) | Automatique (HPA) |
| Rolling update | Arrêt + redémarrage | Zero-downtime par défaut |
| Load balancing | Aucun intégré | Service + Ingress |
| Auto-healing | Redémarrage simple | Rescheduling sur autre nœud |
| Stockage partagé | Volumes locaux | PersistentVolumes (NFS, cloud) |
| Secrets | Variables d'env / fichiers | Kubernetes Secrets + Vault |
| Réseau | Bridge local | Overlay multi-hôtes (CNI) |

## 5. Lien avec la chaîne CI/CD

Docker Compose renforce la **reproductibilité** de la chaîne CI/CD :

- Le même `compose.yml` peut être utilisé en développement local, en recette et (avec adaptations) en staging
- La promotion d'un artefact identifié (digest SHA256) garantit que l'image testée en CI est exactement celle déployée
- La traçabilité (labels OCI, tags, digests) permet de savoir quelle version tourne dans quel environnement à tout moment
