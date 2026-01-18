FROM node:latest

WORKDIR /app

# 1) Copier uniquement les manifestes npm pour maximiser le cache Docker
COPY package.json package-lock.json* ./

# 2) Installer les dépendances (toujours en mode initial, optimisation à venir)
RUN npm install

# 3) Copier le reste du code source
COPY . /app

# 4) Garder les commandes existantes (elles seront optimisées plus tard)
RUN apt-get update && apt-get install -y build-essential ca-certificates locales \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

EXPOSE 3000 4000 5000

ENV NODE_ENV=development

RUN npm run build

USER root

CMD ["node", "server.js"]
