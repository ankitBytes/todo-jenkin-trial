FROM node:20-alpine
WORKDIR /app
COPY backend/package*.json ./backend/
RUN cd backend && npm ci --omit=dev
RUN apk add --no-cache curl
COPY backend/ ./backend/
COPY frontend/ ./frontend/
EXPOSE 3000
CMD ["node", "backend/src/app.js"]
