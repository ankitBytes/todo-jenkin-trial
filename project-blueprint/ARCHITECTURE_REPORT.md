# PROJECT ARCHITECTURE REPORT

Generated on: Wed May  6 13:12:33 UTC 2026

## PROJECT STRUCTURE
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
├── project-blueprint
│   └── ARCHITECTURE_REPORT.md
├── secret.yaml
└── service.yaml

7 directories, 21 files

## ROOT FILES
./deployment.yaml
./secret.yaml
./configmap.yaml
./Dockerfile
./deploy.sh
./.gitignore
./Jenkinsfile
./ingress.yaml
./full-project-analysis.md
./docker-compose.yaml
./service.yaml

## PACKAGE.JSON FILES

### ./backend/package.json
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

## DOCKER FILES

### ./Dockerfile
FROM node:20-alpine

WORKDIR /app

COPY backend/package*.json ./backend/
RUN cd backend && npm ci --omit=dev

RUN npm install -g serve

COPY backend/  ./backend/
COPY frontend/ ./frontend/

EXPOSE 3000

# No CMD — Kubernetes command: field overrides this per deployment

### ./docker-compose.yaml
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

## KUBERNETES YAML FILES

### ./deployment.yaml
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
        image: 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial:v20260506-122123
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
        image: 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial:v20260506-122123
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

### ./secret.yaml
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

### ./configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: todo-config
data:
  PORT: "3000"
  DB_NAME: "todo_db"
  ALLOWED_ORIGIN: "http://k8s-default-todoingr-096e8f96c2-1251263405.us-east-1.elb.amazonaws.com/"

### ./ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: todo-ingress
  namespace: default
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
spec:
  ingressClassName: alb
  rules:
  - http:
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

### ./docker-compose.yaml
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

### ./service.yaml
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

## JENKINS PIPELINES

### ./Jenkinsfile
pipeline {
    agent any

    environment {
        AWS_REGION      = 'us-east-1'
        ECR_REPO        = '668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial'
        ECS_CLUSTER     = 'todo-cluster'
        ECS_SERVICE     = 'todo-task-service-zp9225mz'
        IMAGE_TAG       = "v${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                sh """
                    docker build -t ${ECR_REPO}:${IMAGE_TAG} .
                    docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REPO}:latest
                """
            }
        }

        stage('Push to ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin ${ECR_REPO}
                    
                    docker push ${ECR_REPO}:${IMAGE_TAG}
                    docker push ${ECR_REPO}:latest
                """
            }
        }

        stage('Deploy to ECS') {
            steps {
                sh """
                    # Get current task definition
                    TASK_DEF=\$(aws ecs describe-services \
                        --cluster ${ECS_CLUSTER} \
                        --services ${ECS_SERVICE} \
                        --region ${AWS_REGION} \
                        --query 'services[0].taskDefinition' \
                        --output text)

                    # Get full task definition JSON, strip unneeded fields
                    TASK_DEF_JSON=\$(aws ecs describe-task-definition \
                        --task-definition \$TASK_DEF \
                        --region ${AWS_REGION} \
                        --query 'taskDefinition' \
                        --output json | \
                        jq 'del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')

                    # Update image in task definition
                    NEW_TASK_DEF=\$(echo \$TASK_DEF_JSON | \
                        jq --arg IMAGE "${ECR_REPO}:${IMAGE_TAG}" \
                        '.containerDefinitions[0].image = \$IMAGE')

                    # Register new task definition revision
                    NEW_TASK_ARN=\$(aws ecs register-task-definition \
                        --region ${AWS_REGION} \
                        --cli-input-json "\$NEW_TASK_DEF" \
                        --query 'taskDefinition.taskDefinitionArn' \
                        --output text)

                    # Update service with new task definition
                    aws ecs update-service \
                        --cluster ${ECS_CLUSTER} \
                        --service ${ECS_SERVICE} \
                        --task-definition \$NEW_TASK_ARN \
                        --region ${AWS_REGION}

                    echo "Deployed \$NEW_TASK_ARN"
                """
            }
        }

        stage('Cleanup') {
            steps {
                sh """
                    docker rmi ${ECR_REPO}:${IMAGE_TAG} || true
                    docker rmi ${ECR_REPO}:latest || true
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline completed. Image ${IMAGE_TAG} deployed to ECS."
        }
        failure {
            echo "Pipeline failed at stage. Check logs above."
        }
    }
}

## API ROUTES DETECTED
./full-project-analysis.md:57:./backend/src/app.js:22:  app.get('/health', (req, res) => {
./full-project-analysis.md:58:./backend/src/routes/todo.routes.js:5:router.get('/', controller.getTodos);
./full-project-analysis.md:59:./backend/src/routes/todo.routes.js:6:router.post('/', controller.createTodo);
./full-project-analysis.md:252:./backend/src/routes/todo.routes.js:5:router.get('/', controller.getTodos);
./full-project-analysis.md:253:./backend/src/routes/todo.routes.js:6:router.post('/', controller.createTodo);
./backend/src/app.js:32:  app.get('/health', (req, res) => {
./backend/src/routes/todo.routes.js:5:router.get('/', controller.getTodos);
./backend/src/routes/todo.routes.js:6:router.post('/', controller.createTodo);
