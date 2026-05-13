# FULL PROJECT ANALYSIS REPORT

Generated on: Thu May  7 10:21:22 UTC 2026

## 1. PROJECT STRUCTURE
.
├── Dockerfile
├── Jenkinsfile
├── backend
│   ├── package-lock.json
│   ├── package.json
│   └── src
│       ├── app.js
│       ├── controllers
│       │   └── todo.controller.js
│       ├── db.js
│       ├── redis.js
│       └── routes
│           └── todo.routes.js
├── configmap.yaml
├── deploy.sh
├── deployment.yaml
├── docker-compose.yaml
├── frontend
│   ├── app.js
│   ├── index.html
│   └── style.css
├── full-project-analysis.md
├── ingress.yaml
├── project-analysis
│   └── FULL_PROJECT_ANALYSIS.md
├── project-blueprint
│   └── ARCHITECTURE_REPORT.md
├── secret.yaml
└── service.yaml

8 directories, 22 files

## 2. ROOT FILES
./.gitignore
./Dockerfile
./Jenkinsfile
./configmap.yaml
./deploy.sh
./deployment.yaml
./docker-compose.yaml
./full-project-analysis.md
./ingress.yaml
./secret.yaml
./service.yaml

## 3. PACKAGE.JSON FILES

### FILE: ./backend/package.json
{
  "name": "todo-docker-app",
  "version": "1.0.0",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js"
  },
  "dependencies": {
    "cors": "^2.8.6",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "ioredis": "^5.3.2",
    "mysql2": "^3.6.0"
  }
}

## 4. DOCKER FILES

### FILE: ./Dockerfile
FROM node:20-alpine

WORKDIR /app

COPY backend/package*.json ./backend/
RUN cd backend && npm ci --omit=dev

RUN npm install -g serve

COPY backend/  ./backend/
COPY frontend/ ./frontend/

EXPOSE 3000

# No CMD — Kubernetes command: field overrides this per deployment


### FILE: ./docker-compose.yaml
# =============================================================================
# Docker Compose — local development only
# Mirrors the Kubernetes architecture: frontend and backend are separate
# services using the same image, with command: overriding the entrypoint.
#
# NOT for production. Production runs on Kubernetes via the Jenkinsfile.
# =============================================================================

version: "3.9"

services:

  # ── Frontend ────────────────────────────────────────────────────────────────
  # Serves static files using `serve`, same command as the K8s frontend deployment.
  frontend:
    build:
      context: .
      dockerfile: Dockerfile
    command: serve -s frontend -l 3000
    ports:
      - "3000:3000"          # http://localhost:3000
    depends_on:
      - backend
    networks:
      - todo-network
    restart: on-failure

  # ── Backend ─────────────────────────────────────────────────────────────────
  # Express API, same command as the K8s backend deployment.
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    command: node backend/src/app.js
    ports:
      - "5000:3000"          # http://localhost:5000 → container:3000
    environment:
      PORT:         "3000"
      DB_NAME:      "todos"
      DB_HOST:      mysql
      DB_USER:      todo_user
      DB_PASSWORD:  todo_pass
      REDIS_HOST:   redis
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - todo-network
    restart: on-failure

  # ── MySQL ────────────────────────────────────────────────────────────────────
  # Local stand-in for RDS. Data is persisted in a named volume.
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE:      todos
      MYSQL_USER:          todo_user
      MYSQL_PASSWORD:      todo_pass
    ports:
      - "3306:3306"
    volumes:
      - todo-mysql-data:/var/lib/mysql
    networks:
      - todo-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-utodo_user", "-ptodo_pass"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # ── Redis ────────────────────────────────────────────────────────────────────
  # Local stand-in for ElastiCache.
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    networks:
      - todo-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
    restart: unless-stopped

# ── Shared network ─────────────────────────────────────────────────────────────
networks:
  todo-network:
    driver: bridge

# ── Persistent volumes ─────────────────────────────────────────────────────────
volumes:
  todo-mysql-data:

## 5. KUBERNETES YAML FILES

### FILE: ./deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: todo-app-frontend
  template:
    metadata:
      labels:
        app: todo-app-frontend
    spec:
      containers:
      - name: todo-frontend
        image: 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial:v20260507-084813
        command: ["serve", "-s", "frontend", "-l", "3000"]
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 3
          periodSeconds: 5

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: todo-app-backend
  template:
    metadata:
      labels:
        app: todo-app-backend
    spec:
      containers:
      - name: todo-backend
        image: 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial:v20260507-084813
        command: ["node", "backend/src/app.js"]
        ports:
        - containerPort: 3000
        env:
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: todo-config
              key: PORT
        - name: DB_NAME
          valueFrom:
            configMapKeyRef:
              name: todo-config
              key: DB_NAME
        - name: ALLOWED_ORIGIN
          valueFrom:
            configMapKeyRef:
              name: todo-config
              key: ALLOWED_ORIGIN
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: todo-secret
              key: DB_HOST
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: todo-secret
              key: DB_USER
        - name: REDIS_HOST
          valueFrom:
            secretKeyRef:
              name: todo-secret
              key: REDIS_HOST
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: todo-secret
              key: DB_PASSWORD
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5


### FILE: ./secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: todo-secret
type: Opaque
data:
  DB_HOST: dG9kby1kYi5jMjNxYzZlODBicDUudXMtZWFzdC0xLnJkcy5hbWF6b25hd3MuY29t
  DB_PASSWORD: cm9vdHBhc3M=
  DB_USER: cm9vdA==
  REDIS_HOST: dG9kby1yZWRpcy44dG9nZHcuMDAwMS51c2UxLmNhY2hlLmFtYXpvbmF3cy5jb20=


### FILE: ./configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: todo-config
data:
  PORT: "3000"
  DB_NAME: "todo_db"
  ALLOWED_ORIGIN: "http://k8s-default-todoingr-096e8f96c2-1251263405.us-east-1.elb.amazonaws.com/"


### FILE: ./ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: todo-ingress
  namespace: default
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:668076964228:certificate/e4a2f397-c129-4501-b3bd-b4ab9d6f22d7
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  ingressClassName: alb
  rules:
  - host: www.ankit.services
    http:
      paths:
      - path: /todos
        pathType: Prefix
        backend:
          service:
            name: todo-backend-svc
            port:
              number: 80
      - path: /health
        pathType: Prefix
        backend:
          service:
            name: todo-backend-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: todo-frontend-svc
            port:
              number: 80


### FILE: ./docker-compose.yaml
# =============================================================================
# Docker Compose — local development only
# Mirrors the Kubernetes architecture: frontend and backend are separate
# services using the same image, with command: overriding the entrypoint.
#
# NOT for production. Production runs on Kubernetes via the Jenkinsfile.
# =============================================================================

version: "3.9"

services:

  # ── Frontend ────────────────────────────────────────────────────────────────
  # Serves static files using `serve`, same command as the K8s frontend deployment.
  frontend:
    build:
      context: .
      dockerfile: Dockerfile
    command: serve -s frontend -l 3000
    ports:
      - "3000:3000"          # http://localhost:3000
    depends_on:
      - backend
    networks:
      - todo-network
    restart: on-failure

  # ── Backend ─────────────────────────────────────────────────────────────────
  # Express API, same command as the K8s backend deployment.
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    command: node backend/src/app.js
    ports:
      - "5000:3000"          # http://localhost:5000 → container:3000
    environment:
      PORT:         "3000"
      DB_NAME:      "todos"
      DB_HOST:      mysql
      DB_USER:      todo_user
      DB_PASSWORD:  todo_pass
      REDIS_HOST:   redis
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - todo-network
    restart: on-failure

  # ── MySQL ────────────────────────────────────────────────────────────────────
  # Local stand-in for RDS. Data is persisted in a named volume.
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE:      todos
      MYSQL_USER:          todo_user
      MYSQL_PASSWORD:      todo_pass
    ports:
      - "3306:3306"
    volumes:
      - todo-mysql-data:/var/lib/mysql
    networks:
      - todo-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-utodo_user", "-ptodo_pass"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # ── Redis ────────────────────────────────────────────────────────────────────
  # Local stand-in for ElastiCache.
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    networks:
      - todo-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
    restart: unless-stopped

# ── Shared network ─────────────────────────────────────────────────────────────
networks:
  todo-network:
    driver: bridge

# ── Persistent volumes ─────────────────────────────────────────────────────────
volumes:
  todo-mysql-data:


### FILE: ./service.yaml
apiVersion: v1
kind: Service
metadata:
  name: todo-frontend-svc
spec:
  type: ClusterIP
  selector:
    app: todo-app-frontend
  ports:
  - port: 80
    targetPort: 3000

---
apiVersion: v1
kind: Service
metadata:
  name: todo-backend-svc
spec:
  type: ClusterIP
  selector:
    app: todo-app-backend
  ports:
  - port: 80
    targetPort: 3000

## 6. ENVIRONMENT VARIABLE USAGE
./full-project-analysis.md:48:./backend/src/db.js:8:        host: process.env.DB_HOST,
./full-project-analysis.md:49:./backend/src/db.js:9:        user: process.env.DB_USER,
./full-project-analysis.md:50:./backend/src/db.js:10:        password: process.env.DB_PASSWORD,
./full-project-analysis.md:51:./backend/src/db.js:11:        database: process.env.DB_NAME,
./full-project-analysis.md:52:./backend/src/app.js:26:  app.listen(process.env.PORT, '0.0.0.0', () => {
./full-project-analysis.md:53:./backend/src/app.js:27:    console.log(`Server running on port ${process.env.PORT}`);
./full-project-analysis.md:54:./backend/src/redis.js:5:    host: process.env.REDIS_HOST,
./backend/src/db.js:8:        host: process.env.DB_HOST,
./backend/src/db.js:9:        user: process.env.DB_USER,
./backend/src/db.js:10:        password: process.env.DB_PASSWORD,
./backend/src/db.js:11:        database: process.env.DB_NAME,
./backend/src/app.js:10:const allowedOrigin = process.env.ALLOWED_ORIGIN || '*';
./backend/src/app.js:36:  app.listen(process.env.PORT, '0.0.0.0', () => {
./backend/src/app.js:37:    console.log(`Server running on port ${process.env.PORT}`);
./backend/src/redis.js:5:    host: process.env.REDIS_HOST,

## 7. API ROUTES
./project-blueprint/ARCHITECTURE_REPORT.md:598:./full-project-analysis.md:57:./backend/src/app.js:22:  app.get('/health', (req, res) => {
./project-blueprint/ARCHITECTURE_REPORT.md:599:./full-project-analysis.md:58:./backend/src/routes/todo.routes.js:5:router.get('/', controller.getTodos);
./project-blueprint/ARCHITECTURE_REPORT.md:600:./full-project-analysis.md:59:./backend/src/routes/todo.routes.js:6:router.post('/', controller.createTodo);
./project-blueprint/ARCHITECTURE_REPORT.md:601:./full-project-analysis.md:252:./backend/src/routes/todo.routes.js:5:router.get('/', controller.getTodos);
./project-blueprint/ARCHITECTURE_REPORT.md:602:./full-project-analysis.md:253:./backend/src/routes/todo.routes.js:6:router.post('/', controller.createTodo);
./project-blueprint/ARCHITECTURE_REPORT.md:603:./backend/src/app.js:32:  app.get('/health', (req, res) => {
./project-blueprint/ARCHITECTURE_REPORT.md:604:./backend/src/routes/todo.routes.js:5:router.get('/', controller.getTodos);
./project-blueprint/ARCHITECTURE_REPORT.md:605:./backend/src/routes/todo.routes.js:6:router.post('/', controller.createTodo);
./full-project-analysis.md:57:./backend/src/app.js:22:  app.get('/health', (req, res) => {
./full-project-analysis.md:58:./backend/src/routes/todo.routes.js:5:router.get('/', controller.getTodos);
./full-project-analysis.md:59:./backend/src/routes/todo.routes.js:6:router.post('/', controller.createTodo);
./full-project-analysis.md:60:./backend/src/routes/todo.routes.js:7:router.put('/:id', controller.updateTodo);
./full-project-analysis.md:61:./backend/src/routes/todo.routes.js:8:router.delete('/:id', controller.deleteTodo);
./full-project-analysis.md:252:./backend/src/routes/todo.routes.js:5:router.get('/', controller.getTodos);
./full-project-analysis.md:253:./backend/src/routes/todo.routes.js:6:router.post('/', controller.createTodo);
./full-project-analysis.md:254:./backend/src/routes/todo.routes.js:7:router.put('/:id', controller.updateTodo);
./full-project-analysis.md:255:./backend/src/routes/todo.routes.js:8:router.delete('/:id', controller.deleteTodo);
./backend/src/app.js:32:  app.get('/health', (req, res) => {
./backend/src/routes/todo.routes.js:5:router.get('/', controller.getTodos);
./backend/src/routes/todo.routes.js:6:router.post('/', controller.createTodo);
./backend/src/routes/todo.routes.js:7:router.put('/:id', controller.updateTodo);
./backend/src/routes/todo.routes.js:8:router.delete('/:id', controller.deleteTodo);

## 8. DATABASE + REDIS CONNECTIONS
./deployment.yaml:29:          httpGet:
./deployment.yaml:35:          httpGet:
./deployment.yaml:88:        - name: REDIS_HOST
./deployment.yaml:92:              key: REDIS_HOST
./deployment.yaml:106:          httpGet:
./deployment.yaml:112:          httpGet:
./secret.yaml:10:  REDIS_HOST: dG9kby1yZWRpcy44dG9nZHcuMDAwMS51c2UxLmNhY2hlLmFtYXpvbmF3cy5jb20=
./project-blueprint/ARCHITECTURE_REPORT.md:17:│       ├── redis.js
./project-blueprint/ARCHITECTURE_REPORT.md:64:    "ioredis": "^5.3.2",
./project-blueprint/ARCHITECTURE_REPORT.md:65:    "mysql2": "^3.6.0"
./project-blueprint/ARCHITECTURE_REPORT.md:128:      DB_HOST:      mysql
./project-blueprint/ARCHITECTURE_REPORT.md:131:      REDIS_HOST:   redis
./project-blueprint/ARCHITECTURE_REPORT.md:133:      mysql:
./project-blueprint/ARCHITECTURE_REPORT.md:135:      redis:
./project-blueprint/ARCHITECTURE_REPORT.md:141:  # ── MySQL ────────────────────────────────────────────────────────────────────
./project-blueprint/ARCHITECTURE_REPORT.md:143:  mysql:
./project-blueprint/ARCHITECTURE_REPORT.md:144:    image: mysql:8.0
./project-blueprint/ARCHITECTURE_REPORT.md:146:      MYSQL_ROOT_PASSWORD: rootpass
./project-blueprint/ARCHITECTURE_REPORT.md:147:      MYSQL_DATABASE:      todos
./project-blueprint/ARCHITECTURE_REPORT.md:148:      MYSQL_USER:          todo_user
./project-blueprint/ARCHITECTURE_REPORT.md:149:      MYSQL_PASSWORD:      todo_pass
./project-blueprint/ARCHITECTURE_REPORT.md:153:      - todo-mysql-data:/var/lib/mysql
./project-blueprint/ARCHITECTURE_REPORT.md:157:      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-utodo_user", "-ptodo_pass"]
./project-blueprint/ARCHITECTURE_REPORT.md:163:  # ── Redis ────────────────────────────────────────────────────────────────────
./project-blueprint/ARCHITECTURE_REPORT.md:165:  redis:
./project-blueprint/ARCHITECTURE_REPORT.md:166:    image: redis:7-alpine
./project-blueprint/ARCHITECTURE_REPORT.md:172:      test: ["CMD", "redis-cli", "ping"]
./project-blueprint/ARCHITECTURE_REPORT.md:185:  todo-mysql-data:
./project-blueprint/ARCHITECTURE_REPORT.md:218:          httpGet:
./project-blueprint/ARCHITECTURE_REPORT.md:224:          httpGet:
./project-blueprint/ARCHITECTURE_REPORT.md:277:        - name: REDIS_HOST
./project-blueprint/ARCHITECTURE_REPORT.md:281:              key: REDIS_HOST
./project-blueprint/ARCHITECTURE_REPORT.md:295:          httpGet:
./project-blueprint/ARCHITECTURE_REPORT.md:301:          httpGet:
./project-blueprint/ARCHITECTURE_REPORT.md:317:  REDIS_HOST: dG9kby1yZWRpcy44dG9nZHcuMDAwMS51c2UxLmNhY2hlLmFtYXpvbmF3cy5jb20=
./project-blueprint/ARCHITECTURE_REPORT.md:406:      DB_HOST:      mysql
./project-blueprint/ARCHITECTURE_REPORT.md:409:      REDIS_HOST:   redis
./project-blueprint/ARCHITECTURE_REPORT.md:411:      mysql:
./project-blueprint/ARCHITECTURE_REPORT.md:413:      redis:
./project-blueprint/ARCHITECTURE_REPORT.md:419:  # ── MySQL ────────────────────────────────────────────────────────────────────
./project-blueprint/ARCHITECTURE_REPORT.md:421:  mysql:
./project-blueprint/ARCHITECTURE_REPORT.md:422:    image: mysql:8.0
./project-blueprint/ARCHITECTURE_REPORT.md:424:      MYSQL_ROOT_PASSWORD: rootpass
./project-blueprint/ARCHITECTURE_REPORT.md:425:      MYSQL_DATABASE:      todos
./project-blueprint/ARCHITECTURE_REPORT.md:426:      MYSQL_USER:          todo_user
./project-blueprint/ARCHITECTURE_REPORT.md:427:      MYSQL_PASSWORD:      todo_pass
./project-blueprint/ARCHITECTURE_REPORT.md:431:      - todo-mysql-data:/var/lib/mysql
./project-blueprint/ARCHITECTURE_REPORT.md:435:      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-utodo_user", "-ptodo_pass"]
./project-blueprint/ARCHITECTURE_REPORT.md:441:  # ── Redis ────────────────────────────────────────────────────────────────────
./project-blueprint/ARCHITECTURE_REPORT.md:443:  redis:
./project-blueprint/ARCHITECTURE_REPORT.md:444:    image: redis:7-alpine
./project-blueprint/ARCHITECTURE_REPORT.md:450:      test: ["CMD", "redis-cli", "ping"]
./project-blueprint/ARCHITECTURE_REPORT.md:463:  todo-mysql-data:
./full-project-analysis.md:15:./backend/src/redis.js
./full-project-analysis.md:41:    "mysql2": "^3.6.0",
./full-project-analysis.md:43:    "ioredis": "^5.3.2"
./full-project-analysis.md:54:./backend/src/redis.js:5:    host: process.env.REDIS_HOST,
./full-project-analysis.md:122:./backend/src/redis.js
./full-project-analysis.md:219:./docker-compose.yaml:13:  todo-mysql-data:
./full-project-analysis.md:233:./backend/package-lock.json:541:    "node_modules/ioredis/node_modules/debug": {
./full-project-analysis.md:279:	deleted:    src/redis.js
./docker-compose.yaml:40:      DB_HOST:      mysql
./docker-compose.yaml:43:      REDIS_HOST:   redis
./docker-compose.yaml:45:      mysql:
./docker-compose.yaml:47:      redis:
./docker-compose.yaml:53:  # ── MySQL ────────────────────────────────────────────────────────────────────
./docker-compose.yaml:55:  mysql:
./docker-compose.yaml:56:    image: mysql:8.0
./docker-compose.yaml:58:      MYSQL_ROOT_PASSWORD: rootpass
./docker-compose.yaml:59:      MYSQL_DATABASE:      todos
./docker-compose.yaml:60:      MYSQL_USER:          todo_user
./docker-compose.yaml:61:      MYSQL_PASSWORD:      todo_pass
./docker-compose.yaml:65:      - todo-mysql-data:/var/lib/mysql
./docker-compose.yaml:69:      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-utodo_user", "-ptodo_pass"]
./docker-compose.yaml:75:  # ── Redis ────────────────────────────────────────────────────────────────────
./docker-compose.yaml:77:  redis:
./docker-compose.yaml:78:    image: redis:7-alpine
./docker-compose.yaml:84:      test: ["CMD", "redis-cli", "ping"]
./docker-compose.yaml:97:  todo-mysql-data:
./backend/package.json:12:    "ioredis": "^5.3.2",
./backend/package.json:13:    "mysql2": "^3.6.0"
./backend/package-lock.json:14:        "ioredis": "^5.3.2",
./backend/package-lock.json:15:        "mysql2": "^3.6.0"
./backend/package-lock.json:18:    "node_modules/@ioredis/commands": {
./backend/package-lock.json:20:      "resolved": "https://registry.npmjs.org/@ioredis/commands/-/commands-1.5.1.tgz",
./backend/package-lock.json:89:      "integrity": "sha512-6YHEFRL9mfgcAvql/XhwTvf5jKcOiiupt2FiJxHkiX1z4j7WL8J/jRHYLluORvc1XxB5rV20KoeK00gVJamspg==",
./backend/package-lock.json:203:      "integrity": "sha512-bC7ElrdJaJnPbAP+1EotYvqZsb3ecl5wi6Bfi6BJTUcNowp6cvspg0jXznRTKDjm/E7AdgFBVeAPVMNcKGsHMA==",
./backend/package-lock.json:317:      "integrity": "sha512-aIL5Fx7mawVa300al2BnEE4iNvo1qETxLrPI/o05L7z6go7fCw1J6EQmbK4FmJ2AS7kgVF/KEZWufBfdClMcPg==",
./backend/package-lock.json:426:      "integrity": "sha512-9fSjSaos/fRIVIp+xSJlE6lfwhES7LNtKaCBIamHsjr2na1BiABJPo0mOjjz8GJDURarmCPGqaiVg5mfjb98CQ==",
./backend/package-lock.json:487:      "integrity": "sha512-ej4AhfhfL2Q2zpMmLo7U1Uv9+PyhIZpgQLGT1F9miIGmiCJIoCgSmczFdrc97mWT4kVY72KA+WnnhJ5pghSvSg==",
./backend/package-lock.json:534:    "node_modules/ioredis": {
./backend/package-lock.json:536:      "resolved": "https://registry.npmjs.org/ioredis/-/ioredis-5.10.1.tgz",
./backend/package-lock.json:540:        "@ioredis/commands": "1.5.1",
./backend/package-lock.json:546:        "redis-errors": "^1.2.0",
./backend/package-lock.json:547:        "redis-parser": "^3.0.0",
./backend/package-lock.json:555:        "url": "https://opencollective.com/ioredis"
./backend/package-lock.json:558:    "node_modules/ioredis/node_modules/debug": {
./backend/package-lock.json:575:    "node_modules/ioredis/node_modules/ms": {
./backend/package-lock.json:605:      "integrity": "sha512-chi4NHZlZqZD18a0imDHnZPrDeBbTtVN7GXMwuGdRH9qotxAjYs3aVLKc7zNOG9eddR5Ksd8rvFEBc9SsggPpg==",
./backend/package-lock.json:704:    "node_modules/mysql2": {
./backend/package-lock.json:706:      "resolved": "https://registry.npmjs.org/mysql2/-/mysql2-3.22.3.tgz",
./backend/package-lock.json:726:    "node_modules/mysql2/node_modules/iconv-lite": {
./backend/package-lock.json:757:      "integrity": "sha512-+EUsqGPLsM+j/zdChZjsnX51g4XrHFOIXwfnCVPGlQk/k5giakcKsuxCObBRu6DSm9opw/O6slWbJdghQM4bBg==",
./backend/package-lock.json:862:    "node_modules/redis-errors": {
./backend/package-lock.json:864:      "resolved": "https://registry.npmjs.org/redis-errors/-/redis-errors-1.2.0.tgz",
./backend/package-lock.json:871:    "node_modules/redis-parser": {
./backend/package-lock.json:873:      "resolved": "https://registry.npmjs.org/redis-parser/-/redis-parser-3.0.0.tgz",
./backend/package-lock.json:877:        "redis-errors": "^1.0.0"
./backend/package-lock.json:998:      "integrity": "sha512-VCjCNfgMsby3tTdo02nbjtM/ewra6jPHmpThenkTYh8pG9ucZ/1P8So4u4FGBek/BjpOVsDCMoLA/iuBKIFXRA==",
./backend/package-lock.json:1044:        "url": "https://github.com/mysqljs/sql-escaper?sponsor=1"
./backend/src/db.js:1:const mysql = require('mysql2/promise');
./backend/src/db.js:7:      const pool = await mysql.createPool({
./backend/src/db.js:29:      console.log("✅ Connected to MySQL (pool)");
./backend/src/app.js:4:const connectRedis = require('./redis');
./backend/src/app.js:22:  const redis = await connectRedis();
./backend/src/app.js:26:    req.redis = redis;
./backend/src/controllers/todo.controller.js:5:  const redis = req.redis;
./backend/src/controllers/todo.controller.js:8:  const cached = await redis.get(CACHE_KEY);
./backend/src/controllers/todo.controller.js:19:  await redis.set(CACHE_KEY, JSON.stringify(rows), 'EX', CACHE_TTL);
./backend/src/controllers/todo.controller.js:30:  await req.redis.del(CACHE_KEY);
./backend/src/controllers/todo.controller.js:43:  await req.redis.del(CACHE_KEY);
./backend/src/controllers/todo.controller.js:53:  await req.redis.del(CACHE_KEY);
./backend/src/redis.js:1:const Redis = require('ioredis');
./backend/src/redis.js:3:const connectRedis = async () => {
./backend/src/redis.js:4:  const client = new Redis({
./backend/src/redis.js:5:    host: process.env.REDIS_HOST,
./backend/src/redis.js:11:  console.log('✅ Connected to Redis');
./backend/src/redis.js:15:module.exports = connectRedis;

## 9. FRONTEND API CALLS
./frontend/app.js:2:const API_BASE = '';   // ← change if your server runs elsewhere
./frontend/app.js:22:    const res = await fetch(`${API_BASE}/health`);
./frontend/app.js:34:async function apiFetch(path, options = {}) {
./frontend/app.js:35:  const res = await fetch(`${API_BASE}${path}`, {
./frontend/app.js:53:    todos = await apiFetch('/todos');
./frontend/app.js:70:    await apiFetch('/todos', {
./frontend/app.js:89:    await apiFetch(`/todos/${id}`, { method: 'PUT' });
./frontend/app.js:106:    await apiFetch(`/todos/${id}`, { method: 'DELETE' });

## 10. IMPORTANT SOURCE FILES

### FILE: ./frontend/app.js
/* ── Config ─────────────────────────────────────── */
const API_BASE = '';   // ← change if your server runs elsewhere

/* ── State ──────────────────────────────────────── */
let todos       = [];
let activeFilter = 'all';

/* ── DOM refs ───────────────────────────────────── */
const todoList    = document.getElementById('todoList');
const todoInput   = document.getElementById('todoInput');
const loadingEl   = document.getElementById('loadingState');
const emptyEl     = document.getElementById('emptyState');
const statsEl     = document.getElementById('statsText');
const healthBadge = document.getElementById('healthBadge');
const healthText  = document.getElementById('healthText');
const errorMsg    = document.getElementById('errorMsg');
const addBtn      = document.getElementById('addBtn');

/* ── Health check ───────────────────────────────── */
async function checkHealth() {
  try {
    const res = await fetch(`${API_BASE}/health`);
    if (res.ok) {
      healthBadge.className = 'health-badge ok';
      healthText.textContent = 'ONLINE';
    } else throw new Error();
  } catch {
    healthBadge.className = 'health-badge err';
    healthText.textContent = 'OFFLINE';
  }
}

/* ── API helpers ────────────────────────────────── */
async function apiFetch(path, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `HTTP ${res.status}`);
  }
  return res.json();
}

/* ── Fetch all todos ────────────────────────────── */
async function fetchTodos() {
  loadingEl.classList.remove('hidden');
  emptyEl.classList.add('hidden');
  todoList.innerHTML = '';

  try {
    todos = await apiFetch('/todos');
    renderList();
  } catch (err) {
    showError('failed to fetch todos: ' + err.message);
    loadingEl.classList.add('hidden');
  }
}

/* ── Create todo ────────────────────────────────── */
async function createTodo() {
  const title = todoInput.value.trim();
  if (!title) { showError('title is required.'); return; }

  clearError();
  addBtn.classList.add('loading');

  try {
    await apiFetch('/todos', {
      method: 'POST',
      body: JSON.stringify({ title }),
    });
    todoInput.value = '';
    await fetchTodos();
  } catch (err) {
    showError('could not add todo: ' + err.message);
  } finally {
    addBtn.classList.remove('loading');
  }
}

/* ── Update todo (toggle → completed) ──────────── */
async function updateTodo(id) {
  const item = document.querySelector(`[data-id="${id}"]`);
  if (item) item.style.opacity = '0.5';

  try {
    await apiFetch(`/todos/${id}`, { method: 'PUT' });
    await fetchTodos();
  } catch (err) {
    showError('could not update todo: ' + err.message);
    if (item) item.style.opacity = '1';
  }
}

/* ── Delete todo ────────────────────────────────── */
async function deleteTodo(id) {
  const item = document.querySelector(`[data-id="${id}"]`);
  if (item) {
    item.classList.add('removing');
    await new Promise(r => setTimeout(r, 180));
  }

  try {
    await apiFetch(`/todos/${id}`, { method: 'DELETE' });
    todos = todos.filter(t => t.id !== id);
    renderList();
  } catch (err) {
    showError('could not delete todo: ' + err.message);
    if (item) item.classList.remove('removing');
  }
}

/* ── Filter ─────────────────────────────────────── */
function setFilter(filter, btn) {
  activeFilter = filter;
  document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  renderList();
}

/* ── Render ─────────────────────────────────────── */
function renderList() {
  loadingEl.classList.add('hidden');
  todoList.innerHTML = '';

  const filtered = todos.filter(t => {
    if (activeFilter === 'pending')   return t.status === 'pending';
    if (activeFilter === 'completed') return t.status === 'completed';
    return true;
  });

  if (filtered.length === 0) {
    emptyEl.classList.remove('hidden');
  } else {
    emptyEl.classList.add('hidden');
    filtered.forEach((todo, i) => {
      const li = buildTodoItem(todo, i);
      todoList.appendChild(li);
    });
  }

  updateStats();
}

function buildTodoItem(todo, index) {
  const isDone = todo.status === 'completed';
  const li = document.createElement('li');
  li.className = `todo-item${isDone ? ' completed' : ''}`;
  li.dataset.id = todo.id;
  li.style.animationDelay = `${index * 30}ms`;

  li.innerHTML = `
    <button
      class="check-btn"
      title="${isDone ? 'already completed' : 'mark as done'}"
      onclick="${isDone ? '' : `updateTodo(${todo.id})`}"
      ${isDone ? 'disabled' : ''}
    >${isDone ? '✓' : ''}</button>

    <span class="todo-title">${escapeHtml(todo.title)}</span>

    <span class="status-badge ${todo.status}">${todo.status}</span>

    <button class="delete-btn" onclick="deleteTodo(${todo.id})" title="delete">
      <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
        <path d="M2 2l9 9M11 2l-9 9" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
    </button>
  `;

  return li;
}

/* ── Stats ───────────────────────────────────────── */
function updateStats() {
  const total     = todos.length;
  const pending   = todos.filter(t => t.status === 'pending').length;
  const completed = todos.filter(t => t.status === 'completed').length;
  statsEl.textContent = `${total} total · ${pending} pending · ${completed} done`;
}

/* ── Error helpers ───────────────────────────────── */
function showError(msg) {
  errorMsg.textContent = msg;
  errorMsg.classList.add('visible');
  setTimeout(clearError, 4000);
}

function clearError() {
  errorMsg.textContent = '';
  errorMsg.classList.remove('visible');
}

/* ── Security ────────────────────────────────────── */
function escapeHtml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/* ── Keyboard shortcut (Enter to add) ───────────── */
todoInput.addEventListener('keydown', e => {
  if (e.key === 'Enter') createTodo();
  if (e.key !== 'Enter') clearError();
});

/* ── Init ────────────────────────────────────────── */
(async () => {
  await checkHealth();
  await fetchTodos();
})();


### FILE: ./backend/src/db.js
const mysql = require('mysql2/promise');

const connectDB = async () => {
  let retries = 15;
  while (retries) {
    try {
      const pool = await mysql.createPool({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME,
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0,
      });

      // Verify connectivity before returning
      const conn = await pool.getConnection();
      await conn.execute(`
        CREATE TABLE IF NOT EXISTS todos (
          id INT AUTO_INCREMENT PRIMARY KEY,
          title VARCHAR(255) NOT NULL,
          status ENUM('pending', 'completed') DEFAULT 'pending',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      conn.release();

      console.log("✅ Connected to MySQL (pool)");
      return pool;
    } catch (err) {
      console.log("⏳ DB not ready, retrying...", err.message);
      retries--;
      await new Promise(res => setTimeout(res, 5000));
    }
  }
  throw new Error("❌ Could not connect to DB");
};

module.exports = connectDB; 


### FILE: ./backend/src/app.js
require('dotenv').config();
const express = require('express');
const connectDB = require('./db');
const connectRedis = require('./redis');
const todoRoutes = require('./routes/todo.routes');
const cors = require('cors');

const app = express();

const allowedOrigin = process.env.ALLOWED_ORIGIN || '*';

app.use(cors({
  origin: allowedOrigin,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type'],
}));

app.use(express.json());

(async () => {
  const db = await connectDB();
  const redis = await connectRedis();

  app.use((req, res, next) => {
    req.db = db;
    req.redis = redis;
    next();
  });

  app.use('/todos', todoRoutes);

  app.get('/health', (req, res) => {
    res.json({ status: "OK", version: "v4" });
  });

  app.listen(process.env.PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${process.env.PORT}`);
  });
})(); 
// pipeline test
// webhook test 2


### FILE: ./backend/src/redis.js
const Redis = require('ioredis');

const connectRedis = async () => {
  const client = new Redis({
    host: process.env.REDIS_HOST,
    port: 6379,
    lazyConnect: true,
  });

  await client.connect();
  console.log('✅ Connected to Redis');
  return client;
};

module.exports = connectRedis;

## 11. DEPLOYMENT SCRIPTS

### FILE: ./deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: todo-app-frontend
  template:
    metadata:
      labels:
        app: todo-app-frontend
    spec:
      containers:
      - name: todo-frontend
        image: 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial:v20260507-084813
        command: ["serve", "-s", "frontend", "-l", "3000"]
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 3
          periodSeconds: 5

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: todo-app-backend
  template:
    metadata:
      labels:
        app: todo-app-backend
    spec:
      containers:
      - name: todo-backend
        image: 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial:v20260507-084813
        command: ["node", "backend/src/app.js"]
        ports:
        - containerPort: 3000
        env:
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: todo-config
              key: PORT
        - name: DB_NAME
          valueFrom:
            configMapKeyRef:
              name: todo-config
              key: DB_NAME
        - name: ALLOWED_ORIGIN
          valueFrom:
            configMapKeyRef:
              name: todo-config
              key: ALLOWED_ORIGIN
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: todo-secret
              key: DB_HOST
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: todo-secret
              key: DB_USER
        - name: REDIS_HOST
          valueFrom:
            secretKeyRef:
              name: todo-secret
              key: REDIS_HOST
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: todo-secret
              key: DB_PASSWORD
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5


### FILE: ./deploy.sh
#!/bin/bash
# =============================================================================
# deploy.sh — Todo App Kubernetes Deployment Script
#
# Usage:
#   ./deploy.sh           # build, push, deploy everything
#   ./deploy.sh --skip-build   # deploy manifests only (no docker build/push)
#
# Requirements:
#   - docker, aws cli, kubectl installed and on PATH
#   - AWS credentials configured (env vars or ~/.aws/credentials)
#   - EKS cluster already exists
# =============================================================================

set -euo pipefail   # exit on error, unset var, or pipe failure

# ── Config ────────────────────────────────────────────────────────────────────
AWS_REGION="us-east-1"
ECR_REGISTRY="668076964228.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial"
IMAGE_TAG="v$(date +%Y%m%d-%H%M%S)"    # e.g. v20260506-143022
IMAGE_FULL="${ECR_REPO}:${IMAGE_TAG}"
EKS_CLUSTER="todo-eks"
KUBE_NS="default"
SKIP_BUILD=false

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # no colour

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --skip-build) SKIP_BUILD=true ;;
    *) error "Unknown argument: $arg. Usage: ./deploy.sh [--skip-build]" ;;
  esac
done

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}   Todo App — Kubernetes Deployment Script      ${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""
log "Image tag   : ${IMAGE_TAG}"
log "EKS cluster : ${EKS_CLUSTER}"
log "Namespace   : ${KUBE_NS}"
log "Skip build  : ${SKIP_BUILD}"
echo ""

# =============================================================================
# STEP 1 — Preflight checks
# =============================================================================
log "Step 1/6 — Preflight checks..."

command -v docker  &>/dev/null || error "docker is not installed or not on PATH"
command -v aws     &>/dev/null || error "aws cli is not installed or not on PATH"
command -v kubectl &>/dev/null || error "kubectl is not installed or not on PATH"

# Verify required manifest files exist
for f in deployment.yaml service.yaml ingress.yaml configmap.yaml secret.yaml; do
  [[ -f "$f" ]] || error "Missing required file: $f — run this script from the project root"
done

success "All preflight checks passed"
echo ""

# =============================================================================
# STEP 2 — Build Docker image
# =============================================================================
if [[ "$SKIP_BUILD" == "true" ]]; then
  warn "Step 2/6 — Skipping build (--skip-build flag set)"
else
  log "Step 2/6 — Building Docker image..."

  docker build \
    --tag "${IMAGE_FULL}" \
    --tag "${ECR_REPO}:latest" \
    --file Dockerfile \
    .

  success "Image built: ${IMAGE_FULL}"
fi
echo ""

# =============================================================================
# STEP 3 — Push to ECR
# =============================================================================
if [[ "$SKIP_BUILD" == "true" ]]; then
  warn "Step 3/6 — Skipping ECR push (--skip-build flag set)"
else
  log "Step 3/6 — Pushing image to ECR..."

  aws ecr get-login-password --region "${AWS_REGION}" \
    | docker login \
        --username AWS \
        --password-stdin "${ECR_REGISTRY}"

  docker push "${IMAGE_FULL}"
  docker push "${ECR_REPO}:latest"

  success "Image pushed: ${IMAGE_FULL}"
fi
echo ""

# =============================================================================
# STEP 4 — Patch image tag in deployment.yaml
# =============================================================================
log "Step 4/6 — Patching image tag in deployment.yaml..."

if [[ "$SKIP_BUILD" == "true" ]]; then
  warn "Skipping tag patch — using whatever image is already in deployment.yaml"
else
  # Replace any existing tag on both the frontend and backend image lines
  sed -i "s|image: ${ECR_REPO}:.*|image: ${IMAGE_FULL}|g" deployment.yaml

  log "Image lines after patch:"
  grep "image:" deployment.yaml | sed 's/^/         /'
fi
echo ""

# =============================================================================
# STEP 5 — Connect kubectl to EKS
# =============================================================================
log "Step 5/6 — Syncing kubeconfig for cluster: ${EKS_CLUSTER}..."

aws eks update-kubeconfig \
  --region "${AWS_REGION}" \
  --name "${EKS_CLUSTER}"

# Verify connectivity
kubectl cluster-info --request-timeout=10s &>/dev/null \
  || error "Cannot reach the Kubernetes API server. Check your AWS credentials and cluster name."

success "kubectl connected to ${EKS_CLUSTER}"
echo ""

# =============================================================================
# STEP 6 — Apply manifests
# =============================================================================
log "Step 6/6 — Applying Kubernetes manifests..."

# Apply in dependency order: config/secrets before workloads, workloads before ingress
kubectl apply -f configmap.yaml  -n "${KUBE_NS}"
kubectl apply -f secret.yaml     -n "${KUBE_NS}"
kubectl apply -f deployment.yaml -n "${KUBE_NS}"
kubectl apply -f service.yaml    -n "${KUBE_NS}"
kubectl apply -f ingress.yaml    -n "${KUBE_NS}"

success "All manifests applied"
echo ""

# =============================================================================
# STEP 7 — Wait for rollout
# =============================================================================
log "Waiting for frontend rollout..."
kubectl rollout status deployment/todo-frontend \
  -n "${KUBE_NS}" --timeout=120s \
  || error "Frontend deployment did not become ready in time. Run: kubectl describe deployment/todo-frontend"

log "Waiting for backend rollout..."
kubectl rollout status deployment/todo-backend \
  -n "${KUBE_NS}" --timeout=120s \
  || error "Backend deployment did not become ready in time. Run: kubectl describe deployment/todo-backend"

echo ""

# =============================================================================
# Summary
# =============================================================================
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}   Deployment complete!                         ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""

log "Running pods:"
kubectl get pods -n "${KUBE_NS}" -l app=todo
echo ""

log "Services:"
kubectl get svc -n "${KUBE_NS}" todo-frontend-svc todo-backend-svc
echo ""

log "Ingress (ALB hostname — may take ~60s to provision):"
kubectl get ingress todo-ingress -n "${KUBE_NS}"
echo ""

# Extract and print the ALB address if already available
ALB_HOST=$(kubectl get ingress todo-ingress -n "${KUBE_NS}" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

if [[ -n "$ALB_HOST" ]]; then
  success "App is live at: http://${ALB_HOST}"
else
  warn "ALB not provisioned yet. Re-check in ~60s with:"
  echo "       kubectl get ingress todo-ingress"
fi

echo ""

## 12. GIT INFORMATION
origin	https://github.com/ankitBytes/todo-jenkin-trial.git (fetch)
origin	https://github.com/ankitBytes/todo-jenkin-trial.git (push)

* main

420cdd0 api base url updated
ebf7ab0 API url updated in the api section
10053b0 route 53 link added

## 13. RUNNING CONTAINERS
CONTAINER ID   IMAGE                                 COMMAND                  CREATED      STATUS      PORTS                                                                                                                                  NAMES
d2ae1d9172ca   gcr.io/k8s-minikube/kicbase:v0.0.50   "/usr/local/bin/entr…"   7 days ago   Up 2 days   127.0.0.1:32768->22/tcp, 127.0.0.1:32769->2376/tcp, 127.0.0.1:32770->5000/tcp, 127.0.0.1:32771->8443/tcp, 127.0.0.1:32772->32443/tcp   minikube

## 14. KUBERNETES RESOURCES
NAME                                 READY   STATUS    RESTARTS   AGE
pod/todo-app-54bd684cc4-jfbqp        1/1     Running   0          2d2h
pod/todo-app-54bd684cc4-m656h        1/1     Running   0          2d2h
pod/todo-backend-b57bd9879-q7846     1/1     Running   0          92m
pod/todo-backend-b57bd9879-rghb5     1/1     Running   0          93m
pod/todo-frontend-775cd4dddf-2b8qh   1/1     Running   0          93m
pod/todo-frontend-775cd4dddf-rbglz   1/1     Running   0          92m

NAME                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/kubernetes          ClusterIP   10.100.0.1       <none>        443/TCP    2d3h
service/todo-app            ClusterIP   10.100.16.64     <none>        3000/TCP   2d2h
service/todo-backend-svc    ClusterIP   10.100.186.44    <none>        80/TCP     25h
service/todo-frontend-svc   ClusterIP   10.100.225.228   <none>        80/TCP     25h

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/todo-app        2/2     2            2           2d2h
deployment.apps/todo-backend    2/2     2            2           25h
deployment.apps/todo-frontend   2/2     2            2           25h

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/todo-app-54bd684cc4        2         2         2       2d2h
replicaset.apps/todo-app-78959b584d        0         0         0       2d2h
replicaset.apps/todo-app-7b4c79cd7f        0         0         0       2d2h
replicaset.apps/todo-app-7b6c97bfd4        0         0         0       2d2h
replicaset.apps/todo-backend-546985cb7f    0         0         0       22h
replicaset.apps/todo-backend-58ffc547fb    0         0         0       24h
replicaset.apps/todo-backend-5c86bf59b6    0         0         0       160m
replicaset.apps/todo-backend-6665549db7    0         0         0       25h
replicaset.apps/todo-backend-6f5674cbc5    0         0         0       24h
replicaset.apps/todo-backend-6f945bf9f5    0         0         0       22h
replicaset.apps/todo-backend-76dd467f4c    0         0         0       21h
replicaset.apps/todo-backend-7b995f9dd     0         0         0       166m
replicaset.apps/todo-backend-7c566879b4    0         0         0       24h
replicaset.apps/todo-backend-b57bd9879     2         2         2       93m
replicaset.apps/todo-frontend-5d974fb584   0         0         0       160m
replicaset.apps/todo-frontend-6486d54497   0         0         0       22h
replicaset.apps/todo-frontend-65c8d6bb45   0         0         0       21h
replicaset.apps/todo-frontend-6b4968b499   0         0         0       25h
replicaset.apps/todo-frontend-6bd6c7df4b   0         0         0       24h
replicaset.apps/todo-frontend-775cd4dddf   2         2         2       93m
replicaset.apps/todo-frontend-7b779479fc   0         0         0       22h
replicaset.apps/todo-frontend-d849687bb    0         0         0       166m
replicaset.apps/todo-frontend-d8b46bb5     0         0         0       24h

## 15. AWS CONFIG
NAME       : VALUE                    : TYPE             : LOCATION
profile    : <not set>                : None             : None
access_key : ****************GHOH     : login            : 
secret_key : ****************qY63     : login            : 
region     : us-east-1                : imds             : 

