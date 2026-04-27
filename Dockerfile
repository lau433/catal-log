# ─────────────────────────────────────────────────────────────────────────────
# Dockerfile — Catal-Log / EC06
#
# Image Nginx Alpine servant un site web statique.
# Pas de multi-stage ici : aucun code à compiler, on copie directement les
# fichiers statiques dans le répertoire servi par Nginx.
#
# Pourquoi nginx:alpine ?
#   → Image officielle, maintenue, légère (~8 Mo vs ~180 Mo pour nginx:latest).
#   → Réduit la surface d'attaque (moins de paquets = moins de CVE potentielles).
# ─────────────────────────────────────────────────────────────────────────────

FROM nginx:alpine

# Métadonnées OCI standard — valeurs injectées par le workflow GitHub Actions
# via --build-arg. Permettent de tracer l'image dans GHCR (qui l'a buildé,
# quand, quel commit).
ARG BUILD_DATE
ARG VERSION
ARG GIT_COMMIT

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.title="catal-log" \
      org.opencontainers.image.description="Site statique Catal-Log – EC06 ASRC" \
      org.opencontainers.image.source="https://github.com/VOTRE_USERNAME/catal-log"

# Copie du contenu du site dans le répertoire servi par Nginx par défaut.
# /usr/share/nginx/html est le DocumentRoot de la configuration Nginx Alpine.
COPY site/ /usr/share/nginx/html/

# Port d'écoute de Nginx (documentation seulement — ne crée pas de règle réseau,
# c'est le -p du docker run / ports: du compose.yml qui fait la liaison).
EXPOSE 80

# Nginx démarre en foreground (daemon off) pour que Docker puisse suivre le
# processus principal et détecter les arrêts/crashs. C'est le comportement
# attendu dans un conteneur.
CMD ["nginx", "-g", "daemon off;"]
