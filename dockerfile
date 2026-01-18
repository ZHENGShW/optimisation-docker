FROM node:25.3.0-slim

WORKDIR /app

ENV NODE_ENV=production

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY . /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 3000

RUN npm run build

USER node

CMD ["node", "server.js"]
