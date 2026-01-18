FROM node:latest

WORKDIR /app

ENV NODE_ENV=production

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY . /app

RUN apt-get update && apt-get install -y build-essential ca-certificates locales \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

EXPOSE 3000 4000 5000

RUN npm run build

USER root

CMD ["node", "server.js"]
