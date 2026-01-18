# TP – Optimisation Docker (Node.js)

## Objectif
Optimiser progressivement une image Docker d’une application Node.js

---

## Étape 0 — Baseline (sans optimisation)

### But
Établir une référence chiffrée avant toute optimisation : taille de l’image et couches les plus coûteuses.

### Commandes utilisées
Le fichier Docker s’appelle actuellement 'dockerfile', donc on le spécifie avec '-f'.
Construire l’image baseline : docker build -f dockerfile -t tp-node:baseline .
Mesurer la taille : docker image ls tp-node
Analyser les couches : docker history tp-node:baseline

### Résultats
Image : tp-node:baseline
Taille (image / content size) : 436 MB
Build context transféré (info build) : 13.67 MB (valeur observée pendant le build)

#### Observations (docker history)
Les couches les plus importantes observées sur la baseline sont :
    Base image (node:latest / Debian bookworm) : plusieurs couches très lourdes héritées de l’image de base, notamment :
        - une couche d’environ 619 MB (installation de paquets système),
        - une couche d’environ 194 MB,
        - une couche d’environ 213 MB (installation de Node).
        Ces couches expliquent une grande partie du poids total avant même d’ajouter l’application.

    Installation de paquets système dans le Dockerfile :
        - RUN apt-get update && apt-get install ... : 47.7 MB

    Ajout du code et des dépendances :
        - COPY node_modules ./node_modules : 14.2 MB
        - COPY . /app : 8.97 MB
        - RUN npm install : 6.62 MB

    Autres couches :
        - RUN npm run build : 36.9 kB (impact négligeable ici)
        - EXPOSE 3000 4000 5000 / ENV NODE_ENV=development : 0 B (pas d’impact direct sur la taille)

#### Conclusion (baseline)
Aucune optimisation n’a été appliquée à cette étape. Cette baseline servira de point de comparaison chiffré pour les étapes suivantes.