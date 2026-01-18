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
**Image** : tp-node:baseline
**Taille** (image / content size) : **436 MB**
**Build context transféré** (info build) : **13.67 MB** (valeur observée pendant le build)

#### Observations (docker history)
Les couches les plus importantes observées sur la baseline sont :
    Base image (node:latest / Debian bookworm) : plusieurs couches très lourdes héritées de l’image de base, notamment :
        - une couche d’environ **619 MB** (installation de paquets système),
        - une couche d’environ **194 MB**,
        - une couche d’environ **213 MB** (installation de Node).
        Ces couches expliquent une grande partie du poids total avant même d’ajouter l’application.

    Installation de paquets système dans le Dockerfile :
        - RUN apt-get update && apt-get install ... : **47.7 MB**

    Ajout du code et des dépendances :
        - COPY node_modules ./node_modules : **14.2 MB**
        - COPY . /app : **8.97 MB**
        - RUN npm install : **6.62 MB**

    Autres couches :
        - RUN npm run build : **36.9 kB** (impact négligeable ici)
        - EXPOSE 3000 4000 5000 / ENV NODE_ENV=development : **0 B** (pas d’impact direct sur la taille)

#### Conclusion (baseline)
Aucune optimisation n’a été appliquée à cette étape. Cette baseline servira de point de comparaison chiffré pour les étapes suivantes.

---

## Étape 1 — Nettoyage du dépôt et réduction du build context

### But
Éviter de versionner des éléments inutiles (notamment 'node_modules/') afin de garder un dépôt propre.
Réduire drastiquement le **build context** envoyé à Docker lors du 'docker build'.

### Changements réalisés
Ajout d’un '.gitignore' (exclusion de 'node_modules/', logs, fichiers d’environnement, etc.).
Suppression de 'node_modules/' du suivi Git via :
    'git rm -r --cached node_modules'
    (le dossier reste présent localement, mais n’est plus versionné)
Ajout d’un '.dockerignore' pour exclure les éléments non nécessaires au build ('.git/', fichiers d’éditeur, logs, etc.).

Remarque : le Dockerfile courant copie encore explicitement 'node_modules/' ('COPY node_modules ...').  
Donc on ne met pas encore 'node_modules/' dans '.dockerignore' à ce stade (sinon le build échouerait). Ce point sera traité lors d’une étape d’optimisation du Dockerfile.

### Résultats
**Image** : 'tp-node:etape1'
**Taille (content size)** : **433 MB** (baseline : 436 MB)
**Build context transféré** : **87.17 kB** (baseline : 13.67 MB)

### Observations (docker history)
'COPY . /app' : **73.7 kB** (baseline : 8.97 MB)  
    Le dépôt étant nettoyé (et 'node_modules/' n’étant plus inclus dans le contexte), la copie du code applicatif devient beaucoup plus légère.
'COPY node_modules ./node_modules' : **14.2 MB** (inchangé)  
        Encore présent car le Dockerfile le copie explicitement.
Les couches lourdes liées à l’image de base 'node:latest' restent inchangées.

### Conclusion
Cette étape améliore la propreté du dépôt et réduit fortement le build context.  
Les optimisations majeures de taille viendront ensuite en modifiant le Dockerfile (suppression de la copie de 'node_modules/', meilleure gestion des dépendances, etc.).

---

## Étape 2 — Suppression de la copie de 'node_modules' et amélioration du cache des dépendances

### But
Ne plus copier 'node_modules/' depuis la machine hôte (meilleure reproductibilité).
Améliorer l’utilisation du cache Docker en séparant l’installation des dépendances du reste du code.

### Changements réalisés
Suppression de 'COPY node_modules ./node_modules' dans le Dockerfile.
Copie des fichiers 'package.json' / 'package-lock.json' avant l’installation des dépendances ('npm install').
Le code applicatif est copié après l’installation des dépendances ('COPY . /app'), ce qui permet de réutiliser le cache si seules les sources changent.
(Préparation) 'node_modules/' peut désormais être ignoré côté Docker (car non requis dans le contexte).

### Mesures
**Image** : 'tp-node:etape2'
**Taille (content size)** : **435 MB** (étape 1 : 433 MB ; baseline : 436 MB)
**Build context transféré** : à renseigner depuis les logs de build (attendu en **kB**, car '.dockerignore' est actif)

### Observations (docker history)
La couche 'COPY node_modules ...' a disparu.
L’installation des dépendances via 'RUN npm install' représente désormais **24.8 MB**.
La copie du code applicatif ('COPY . /app') reste très faible (**69.6 kB**), ce qui confirme que le contexte de build est maîtrisé.

### Conclusion
Cette étape améliore surtout la reproductibilité et la structure des couches (cache).  
La réduction de taille plus importante viendra dans les étapes suivantes (dépendances de production uniquement, image de base plus légère, multi-stage, etc.).

---

## Étape 3 — Installation des dépendances de production uniquement

### But
Réduire la taille des dépendances Node.js dans l’image en excluant les 'devDependencies'.

### Changements réalisés
Passage à 'NODE_ENV=production'.
Installation npm en production uniquement : 'npm install --omit=dev'.

### Mesures
**Image** : 'tp-node:etape3'
**Taille (content size)** : **435 MB** (étape 2 : 435 MB)
**Build context transféré** : à renseigner depuis les logs de build (attendu en kB)

### Observations (docker history)
La couche d’installation des dépendances diminue :
    Étape 2 : 'npm install' = **24.8 MB**
    Étape 3 : 'npm install --omit=dev' = **21.5 MB**
La taille totale de l’image reste stable car les couches dominantes proviennent surtout de l’image de base 'node:latest' et de l’installation des paquets OS ('apt-get ...' = **47.7 MB**).

### Conclusion
Cette étape réduit bien la taille des dépendances Node.js (preuve chiffrée via 'docker history'), mais l’impact global sur la taille de l’image est masqué par le poids de l’image de base et des paquets système. Les prochaines étapes cibleront ces sources principales de taille.

---

## Étape 4 — Réduction des paquets système et nettoyage APT

### But
Réduire la taille de l’image en supprimant les paquets système inutiles et en évitant de conserver le cache APT dans les couches.

### Changements réalisés
Suppression des paquets non nécessaires au projet ('build-essential', 'locales').
Conservation de 'ca-certificates' (utile pour les connexions HTTPS/TLS).
Installation avec '--no-install-recommends'.
Nettoyage du cache APT dans la même couche : 'rm -rf /var/lib/apt/lists/*'.

### Mesures
**Image** : 'tp-node:etape4'
**Taille (content size)** : **411 MB** (étape 3 : 435 MB)
**Couche APT (docker history)** : **4.1 kB** (étape 3 : 47.7 MB)

### Observations
La réduction est nette car :
moins de paquets installés,
pas de cache APT conservé dans l’image (listes supprimées dans la même couche).

### Conclusion
Cette étape apporte un gain immédiat de taille et rend l’image plus propre. Les prochaines optimisations viseront surtout l’image de base (remplacer 'node:latest' par une version figée et plus légère).

---

## Étape 5 — Image de base plus légère et version figée (slim)

### But
Rendre le build **reproductible** (éviter 'latest').
Réduire fortement la taille globale en utilisant une variante **slim** de l’image officielle Node.js.

### Changements réalisés
Remplacement de 'FROM node:latest' par 'FROM node:25.3.0-slim'.

### Mesures
**Image** : 'tp-node:etape5'
**Taille (content size)** : **86.1 MB** (étape 4 : 411 MB)

### Observations (docker history)
La baisse provient majoritairement des couches héritées de l’image de base (variante 'slim' beaucoup plus légère).
Les couches applicatives restent du même ordre de grandeur :
    'npm install --omit=dev' : **21.5 MB**
    couche APT : **10.4 MB**
    'COPY . /app' : **69.6 kB**

### Conclusion
Le changement d’image de base est le facteur le plus impactant sur la taille totale. Le fait de versionner l’image ('25.3.0-slim') stabilise également les résultats du build.

---

## Étape 6 — Runtime plus sûr (port minimal et utilisateur non-root)

### But
Améliorer les bonnes pratiques de sécurité au runtime :
exposer uniquement le port nécessaire,
exécuter le processus Node avec un utilisateur non-root.

### Changements réalisés
'EXPOSE 3000' uniquement (suppression de 4000/5000).
Exécution avec l’utilisateur 'node' fourni par l’image officielle (au lieu de 'root').

### Mesures
**Image** : 'tp-node:etape6'
**Taille (content size)** : **86.1 MB** (étape 5 : 86.1 MB)

### Vérification de fonctionnement
Démarrage du conteneur : 'docker run --rm -p 3000:3000 tp-node:etape6'
Résultat : le serveur démarre et répond sur 'http://localhost:3000/' (logs 'GET /' observés).

### Conclusion
Cette étape vise surtout la sécurité et la conformité aux bonnes pratiques. L’impact sur la taille est faible, mais le runtime est moins permissif et donc plus sûr.

