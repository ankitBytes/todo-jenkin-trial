/* ── Config ─────────────────────────────────────── */
const API_BASE = 'http://k8s-default-todoingr-096e8f96c2-1251263405.us-east-1.elb.amazonaws.com';   // ← change if your server runs elsewhere

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
