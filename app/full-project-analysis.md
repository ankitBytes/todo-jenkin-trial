# FULL PROJECT ANALYSIS REPORT - todo

Generated on: Wed May  6 08:12:27 UTC 2026

## PROJECT STRUCTURE
./.git
./.gitignore
./Dockerfile
./Jenkinsfile
./backend/package-lock.json
./backend/package.json
./backend/src/app.js
./backend/src/controllers/todo.controller.js
./backend/src/db.js
./backend/src/redis.js
./backend/src/routes/todo.routes.js
./configmap.yaml
./deployment.yaml
./docker-compose.yaml
./frontend/app.js
./frontend/index.html
./frontend/style.css
./full-project-analysis.md
./ingress.yaml
./secret.yaml
./service.yaml

## PACKAGE.JSON FILES

### FILE: ./backend/package.json

{
  "name": "todo-docker-app",
  "version": "1.0.0",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.0",
    "dotenv": "^16.3.1",
    "ioredis": "^5.3.2"
  }
} 

## ENVIRONMENT VARIABLES USED
./backend/src/db.js:8:        host: process.env.DB_HOST,
./backend/src/db.js:9:        user: process.env.DB_USER,
./backend/src/db.js:10:        password: process.env.DB_PASSWORD,
./backend/src/db.js:11:        database: process.env.DB_NAME,
./backend/src/app.js:26:  app.listen(process.env.PORT, '0.0.0.0', () => {
./backend/src/app.js:27:    console.log(`Server running on port ${process.env.PORT}`);
./backend/src/redis.js:5:    host: process.env.REDIS_HOST,

## EXPRESS ROUTES & APIs
./backend/src/app.js:22:  app.get('/health', (req, res) => {
./backend/src/routes/todo.routes.js:5:router.get('/', controller.getTodos);
./backend/src/routes/todo.routes.js:6:router.post('/', controller.createTodo);
./backend/src/routes/todo.routes.js:7:router.put('/:id', controller.updateTodo);
./backend/src/routes/todo.routes.js:8:router.delete('/:id', controller.deleteTodo);

## REQUEST / RESPONSE STRUCTURE
./frontend/app.js:40:    const body = await res.json().catch(() => ({}));
./frontend/app.js:41:    throw new Error(body.error || `HTTP ${res.status}`);
./frontend/app.js:43:  return res.json();
./backend/src/app.js:23:    res.json({ status: "OK", version: "v4" });
./backend/src/controllers/todo.controller.js:11:    return res.json(JSON.parse(cached));
./backend/src/controllers/todo.controller.js:21:  res.json(rows);
./backend/src/controllers/todo.controller.js:25:  const { title } = req.body;
./backend/src/controllers/todo.controller.js:26:  if (!title) return res.status(400).json({ error: "Title required" });
./backend/src/controllers/todo.controller.js:32:  res.json({ message: "Todo created" });
./backend/src/controllers/todo.controller.js:36:  const { id } = req.params;
./backend/src/controllers/todo.controller.js:45:  res.json({ message: "Todo updated" });
./backend/src/controllers/todo.controller.js:49:  const { id } = req.params;
./backend/src/controllers/todo.controller.js:55:  res.json({ message: "Todo deleted" });

## DATABASE QUERIES
./Jenkinsfile:60:                    # Update image in task definition
./Jenkinsfile:72:                    # Update service with new task definition
./frontend/index.html:26:      <p class="sub">track it. ship it. delete it.</p>
./frontend/app.js:83:/* ── Update todo (toggle → completed) ──────────── */
./frontend/app.js:92:    showError('could not update todo: ' + err.message);
./frontend/app.js:97:/* ── Delete todo ────────────────────────────────── */
./frontend/app.js:110:    showError('could not delete todo: ' + err.message);
./frontend/style.css:306:/* Delete btn */
./backend/src/db.js:20:        CREATE TABLE IF NOT EXISTS todos (
./backend/src/controllers/todo.controller.js:16:  const [rows] = await req.db.execute("SELECT * FROM todos");
./backend/src/controllers/todo.controller.js:27:  await req.db.execute("INSERT INTO todos (title) VALUES (?)", [title]);
./backend/src/controllers/todo.controller.js:38:    "UPDATE todos SET status='completed' WHERE id=?",
./backend/src/controllers/todo.controller.js:50:  await req.db.execute("DELETE FROM todos WHERE id=?", [id]);

## AUTHENTICATION & SECURITY
./backend/package-lock.json:168:    "node_modules/cookie": {
./backend/package-lock.json:170:      "resolved": "https://registry.npmjs.org/cookie/-/cookie-0.7.2.tgz",
./backend/package-lock.json:177:    "node_modules/cookie-signature": {
./backend/package-lock.json:179:      "resolved": "https://registry.npmjs.org/cookie-signature/-/cookie-signature-1.0.7.tgz",
./backend/package-lock.json:317:        "cookie": "~0.7.1",
./backend/package-lock.json:318:        "cookie-signature": "~1.0.6",

## MIDDLEWARES
./backend/src/app.js:8:app.use(express.json());
./backend/src/app.js:14:  app.use((req, res, next) => {
./backend/src/app.js:20:  app.use('/todos', todoRoutes);

## DOCKER & DEVOPS FILES
./deployment.yaml
./secret.yaml
./configmap.yaml
./Dockerfile
./ingress.yaml
./docker-compose.yaml
./service.yaml

## FRONTEND RELATED FILES
./frontend/index.html
./frontend/app.js
./frontend/style.css
./backend/src/db.js
./backend/src/app.js
./backend/src/controllers/todo.controller.js
./backend/src/redis.js
./backend/src/routes/todo.routes.js

## TODO / FIXME / BUG COMMENTS
./deployment.yaml:4:  name: todo-frontend
./deployment.yaml:9:      app: todo-app-frontend
./deployment.yaml:13:        app: todo-app-frontend
./deployment.yaml:16:      - name: todo-frontend
./deployment.yaml:17:        image: 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial:v7
./deployment.yaml:45:  name: todo-backend
./deployment.yaml:50:      app: todo-app-backend
./deployment.yaml:54:        app: todo-app-backend
./deployment.yaml:57:      - name: todo-backend
./deployment.yaml:58:        image: 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial:v7
./deployment.yaml:66:              name: todo-config
./deployment.yaml:71:              name: todo-config
./deployment.yaml:76:              name: todo-secret
./deployment.yaml:81:              name: todo-secret
./deployment.yaml:86:              name: todo-secret
./deployment.yaml:91:              name: todo-secret
./secret.yaml:4:  name: todo-secret
./configmap.yaml:4:  name: todo-config
./configmap.yaml:7:  DB_NAME: "todos"
./Jenkinsfile:6:        ECR_REPO        = '668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial'
./Jenkinsfile:7:        ECS_CLUSTER     = 'todo-cluster'
./Jenkinsfile:8:        ECS_SERVICE     = 'todo-task-service-zp9225mz'
./frontend/index.html:6:  <title>TODOS</title>
./frontend/index.html:16:      <div class="logo">TODOS<span class="dot">.</span></div>
./frontend/index.html:33:          id="todoInput"
./frontend/index.html:38:        <button id="addBtn" onclick="createTodo()">
./frontend/index.html:57:        <span>fetching todos...</span>
./frontend/index.html:63:      <ul id="todoList"></ul>
./frontend/app.js:5:let todos       = [];
./frontend/app.js:9:const todoList    = document.getElementById('todoList');
./frontend/app.js:10:const todoInput   = document.getElementById('todoInput');
./frontend/app.js:46:/* ── Fetch all todos ────────────────────────────── */
./frontend/app.js:47:async function fetchTodos() {
./frontend/app.js:50:  todoList.innerHTML = '';
./frontend/app.js:53:    todos = await apiFetch('/todos');
./frontend/app.js:56:    showError('failed to fetch todos: ' + err.message);
./frontend/app.js:61:/* ── Create todo ────────────────────────────────── */
./frontend/app.js:62:async function createTodo() {
./frontend/app.js:63:  const title = todoInput.value.trim();
./frontend/app.js:70:    await apiFetch('/todos', {
./frontend/app.js:74:    todoInput.value = '';
./frontend/app.js:75:    await fetchTodos();
./frontend/app.js:77:    showError('could not add todo: ' + err.message);
./frontend/app.js:83:/* ── Update todo (toggle → completed) ──────────── */
./frontend/app.js:84:async function updateTodo(id) {
./frontend/app.js:89:    await apiFetch(`/todos/${id}`, { method: 'PUT' });
./frontend/app.js:90:    await fetchTodos();
./frontend/app.js:92:    showError('could not update todo: ' + err.message);
./frontend/app.js:97:/* ── Delete todo ────────────────────────────────── */
./frontend/app.js:98:async function deleteTodo(id) {
./frontend/app.js:106:    await apiFetch(`/todos/${id}`, { method: 'DELETE' });
./frontend/app.js:107:    todos = todos.filter(t => t.id !== id);
./frontend/app.js:110:    showError('could not delete todo: ' + err.message);
./frontend/app.js:126:  todoList.innerHTML = '';
./frontend/app.js:128:  const filtered = todos.filter(t => {
./frontend/app.js:138:    filtered.forEach((todo, i) => {
./frontend/app.js:139:      const li = buildTodoItem(todo, i);
./frontend/app.js:140:      todoList.appendChild(li);
./frontend/app.js:147:function buildTodoItem(todo, index) {
./frontend/app.js:148:  const isDone = todo.status === 'completed';
./frontend/app.js:150:  li.className = `todo-item${isDone ? ' completed' : ''}`;
./frontend/app.js:151:  li.dataset.id = todo.id;
./frontend/app.js:158:      onclick="${isDone ? '' : `updateTodo(${todo.id})`}"
./frontend/app.js:162:    <span class="todo-title">${escapeHtml(todo.title)}</span>
./frontend/app.js:164:    <span class="status-badge ${todo.status}">${todo.status}</span>
./frontend/app.js:166:    <button class="delete-btn" onclick="deleteTodo(${todo.id})" title="delete">
./frontend/app.js:178:  const total     = todos.length;
./frontend/app.js:179:  const pending   = todos.filter(t => t.status === 'pending').length;
./frontend/app.js:180:  const completed = todos.filter(t => t.status === 'completed').length;
./frontend/app.js:207:todoInput.addEventListener('keydown', e => {
./frontend/app.js:208:  if (e.key === 'Enter') createTodo();
./frontend/app.js:215:  await fetchTodos();
./frontend/style.css:144:#todoInput {
./frontend/style.css:156:#todoInput::placeholder { color: var(--muted); }
./frontend/style.css:213:/* ── Todo List ───────────────────────────────────── */
./frontend/style.css:216:#todoList {
./frontend/style.css:223:/* ── Todo Item ───────────────────────────────────── */
./frontend/style.css:224:.todo-item {
./frontend/style.css:241:.todo-item:hover { border-color: #3a3a3a; }
./frontend/style.css:243:.todo-item.completed {
./frontend/style.css:248:.todo-item.removing {
./frontend/style.css:272:.todo-item.completed .check-btn {
./frontend/style.css:279:.todo-title {
./frontend/style.css:287:.todo-item.completed .todo-title {
./frontend/style.css:321:.todo-item:hover .delete-btn { opacity: 1; }
./ingress.yaml:4:  name: todo-ingress
./ingress.yaml:12:      - path: /todos(/|$)(.*)
./ingress.yaml:16:            name: todo-backend-svc
./ingress.yaml:23:            name: todo-backend-svc
./ingress.yaml:30:            name: todo-frontend-svc
./docker-compose.yaml:2:  todo-app:
./docker-compose.yaml:9:      - todo-network
./docker-compose.yaml:11:  todo-network:
./docker-compose.yaml:13:  todo-mysql-data:
./service.yaml:4:  name: todo-frontend-svc
./service.yaml:8:    app: todo-app-frontend
./service.yaml:17:  name: todo-backend-svc
./service.yaml:21:    app: todo-app-backend
./backend/package.json:2:  "name": "todo-docker-app",
./backend/package-lock.json:2:  "name": "todo-docker-app",
./backend/package-lock.json:8:      "name": "todo-docker-app",
./backend/package-lock.json:69:        "debug": "2.6.9",
./backend/package-lock.json:183:    "node_modules/debug": {
./backend/package-lock.json:185:      "resolved": "https://registry.npmjs.org/debug/-/debug-2.6.9.tgz",
./backend/package-lock.json:319:        "debug": "2.6.9",
./backend/package-lock.json:358:        "debug": "2.6.9",
./backend/package-lock.json:525:        "debug": "^4.3.4",
./backend/package-lock.json:541:    "node_modules/ioredis/node_modules/debug": {
./backend/package-lock.json:543:      "resolved": "https://registry.npmjs.org/debug/-/debug-4.4.3.tgz",
./backend/package-lock.json:890:        "debug": "2.6.9",
./backend/src/db.js:20:        CREATE TABLE IF NOT EXISTS todos (
./backend/src/app.js:5:const todoRoutes = require('./routes/todo.routes');
./backend/src/app.js:20:  app.use('/todos', todoRoutes);
./backend/src/controllers/todo.controller.js:1:const CACHE_KEY = 'todos:all';
./backend/src/controllers/todo.controller.js:4:exports.getTodos = async (req, res) => {
./backend/src/controllers/todo.controller.js:16:  const [rows] = await req.db.execute("SELECT * FROM todos");
./backend/src/controllers/todo.controller.js:24:exports.createTodo = async (req, res) => {
./backend/src/controllers/todo.controller.js:27:  await req.db.execute("INSERT INTO todos (title) VALUES (?)", [title]);
./backend/src/controllers/todo.controller.js:32:  res.json({ message: "Todo created" });
./backend/src/controllers/todo.controller.js:35:exports.updateTodo = async (req, res) => {
./backend/src/controllers/todo.controller.js:38:    "UPDATE todos SET status='completed' WHERE id=?",
./backend/src/controllers/todo.controller.js:45:  res.json({ message: "Todo updated" });
./backend/src/controllers/todo.controller.js:48:exports.deleteTodo = async (req, res) => {
./backend/src/controllers/todo.controller.js:50:  await req.db.execute("DELETE FROM todos WHERE id=?", [id]);
./backend/src/controllers/todo.controller.js:55:  res.json({ message: "Todo deleted" });
./backend/src/routes/todo.routes.js:3:const controller = require('../controllers/todo.controller');
./backend/src/routes/todo.routes.js:5:router.get('/', controller.getTodos);
./backend/src/routes/todo.routes.js:6:router.post('/', controller.createTodo);
./backend/src/routes/todo.routes.js:7:router.put('/:id', controller.updateTodo);
./backend/src/routes/todo.routes.js:8:router.delete('/:id', controller.deleteTodo);

## POSSIBLE ENTRY FILES
./frontend/app.js
./backend/src/app.js

## INSTALLED DEPENDENCIES
/home/ubuntu/todo
└── (empty)


## GIT STATUS
On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  (use "git add/rm <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   Dockerfile
	deleted:    package-lock.json
	deleted:    package.json
	deleted:    src/app.js
	deleted:    src/controllers/todo.controller.js
	deleted:    src/db.js
	deleted:    src/redis.js
	deleted:    src/routes/todo.routes.js

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	backend/
	frontend/
	full-project-analysis.md

no changes added to commit (use "git add" and/or "git commit -a")

==================================================
PROJECT ANALYSIS COMPLETE
Review this file to understand:
- Backend APIs
- Database structure
- Missing frontend pieces
- Required environment variables
- Security/auth flow
- Docker/K8s deployment setup
- Potential code issues
==================================================
