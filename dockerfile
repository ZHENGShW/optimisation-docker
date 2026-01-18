# ---- deps stage: install production dependencies only ----
FROM node:25.3.0-slim AS deps

WORKDIR /app
ENV NODE_ENV=production

# Copy only dependency manifests to leverage Docker cache
COPY package.json package-lock.json* ./

# Install production dependencies
RUN npm install --omit=dev


# ---- runtime stage: minimal runtime image ----
FROM node:25.3.0-slim AS runtime

WORKDIR /app
ENV NODE_ENV=production

# Copy production node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy only what is required to run the app
COPY server.js ./server.js
COPY package.json ./package.json

EXPOSE 3000
USER node

CMD ["node", "server.js"]
