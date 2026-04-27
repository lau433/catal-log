# Compte Rendu Final — EC06 / Catal-Log

**Auteur :** Laurent Vidot
**Module :** EC06 – Mise en place d'un système d'automatisation CI/CD
**Formation :** ASRC – RNCP39611BC02
**Date :** Avril 2026

---

## 1. Résumé de ce qui a été mis en place

J'ai mis en place une chaîne CI/CD complète pour le site statique de Catal-Log, en utilisant GitHub Actions, Docker (Nginx Alpine) et GitHub Container Registry (GHCR).

Le pipeline complet couvre :
- **Intégration Continue** : lint du Dockerfile (Hadolint), build automatique, tests HTTP (HTTP 200 + vérification du contenu)
- **Publication** : construction de l'image avec tags semver et digest SHA256, publication dans GHCR
- **Promotion manuelle** : retag de l'artefact validé en recette vers production-simulee, sans rebuild, avec vérification de l'identité du digest

L'orchestration légère est assurée par Docker Compose avec deux services (`web` et `whoami`) sur un réseau dédié.

---

## 2. Choix techniques personnels et justifications

**Nginx Alpine plutôt que nginx:latest**
Un site statique n'a pas besoin d'un moteur d'exécution. `nginx:alpine` fait le travail en ~8 Mo. Moins de surface d'attaque, build plus rapide, image plus facile à inspecter.

**Séparation en 3 workflows distincts**
J'ai volontairement séparé CI, publication et promotion en trois fichiers. Ça rend chaque workflow lisible indépendamment, et ça empêche un push accidentel de déclencher une publication en production. La séparation des déclencheurs (`push`, `tag v*`, `workflow_dispatch`) reflète trois niveaux de décision différents.

**crane pour la promotion sans rebuild**
J'aurais pu faire `docker pull / docker tag / docker push`. Mais ça aurait re-téléchargé et re-uploadé l'image entière. `crane tag` copie uniquement le manifest (quelques Ko) et conserve le même digest SHA256 — c'est la preuve que l'artefact en production est exactement celui qui a passé les tests.

**whoami comme second service dans compose.yml**
Plutôt qu'un service artificiel sans utilité, `traefik/whoami` a une valeur démonstrative réelle : quand on scale le service web, il permet de voir concrètement les différents hostnames des réplicas.

---

## 3. Difficultés rencontrées et solutions

| Difficulté | Solution adoptée |
|------------|-----------------|
| Port hôte déjà occupé pour le test CI | Test sur le port 8080, nettoyage systématique avec `if: always()` |
| Digest non disponible avant le push | Utilisation de `docker/build-push-action@v5` qui expose `outputs.digest` |
| Scaling impossible avec port fixe | Documentation de la désactivation des `ports` pour `--scale` |

---

## 4. Limites honnêtes de l'approche

Cette chaîne CI/CD est pédagogique et simulée. Les limites principales sont :

- **Pas de déploiement réel** : les "environnements" GitHub sont des labels, pas des serveurs
- **Pas de scan de vulnérabilités** : Trivy ou Snyk n'ont pas été intégrés (hors périmètre EC06)
- **Pas de rollback automatique** : en cas d'échec du smoke test, le pipeline s'arrête mais ne rollback pas automatiquement le précédent tag prod
- **Docker Compose sur un seul hôte** : pas de distribution multi-nœuds possible
- **Pas de monitoring** : aucune alerte si le conteneur devient unhealthy en "production"

---

## 5. Ce que j'ai appris

**Technique**
- La différence concrète entre un tag (mutable) et un digest (immuable) — et pourquoi ça compte en production
- Pourquoi on ne rebuild jamais en promotion : la reproductibilité n'est pas garantie même avec le même Dockerfile
- Comment `GITHUB_TOKEN` fonctionne : éphémère, scopé, automatique — aucune raison de stocker des credentials manuellement pour pousser dans GHCR
- La valeur des healthchecks : Docker Compose et GitHub Actions les utilisent pour savoir si un service est vraiment prêt

**Conceptuel**
- Docker Compose est un outil de développement/staging, pas de production
- Kubernetes résout les problèmes que Compose ne peut pas résoudre : scheduling multi-nœuds, auto-scaling, rolling updates, self-healing
- La traçabilité (labels OCI, digests, logs d'Actions) n'est pas accessoire — c'est ce qui permet de répondre à "qu'est-ce qui tourne en prod en ce moment, et depuis quand ?"

---

## 6. Preuves à consulter dans le dépôt

| Preuve | Où la trouver |
|--------|---------------|
| Build CI réussi | GitHub Actions > 01 – CI > dernier run |
| Test HTTP 200 | Dans les logs du step "Test HTTP – page d'accueil" |
| Image GHCR + digest | GitHub > Packages > catal-log |
| Promotion sans rebuild | GitHub Actions > 03 – Promote > vérification digest |
| compose.yml + second service | Fichier `compose.yml` à la racine |
| Analyse secrets/rollback/sauvegarde | `docs/04-production-reelle.md` |
| Fiche sécurité | `docs/02-securite.md` |
