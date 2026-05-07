FROM node:20-alpine

WORKDIR /app

COPY backend/package*.json ./backend/
RUN cd backend && npm ci --omit=dev

RUN npm install -g serve

COPY backend/  ./backend/
COPY frontend/ ./frontend/

EXPOSE 3000

# No CMD — Kubernetes command: field overrides this per deployment
