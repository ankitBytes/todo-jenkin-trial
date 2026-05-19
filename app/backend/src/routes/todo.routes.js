const express = require('express');
const router = express.Router();
const controller = require('../controllers/todo.controller');

// Mounted at /api/todos in app.js — paths here are relative to that mount
router.get('/',     controller.getTodos);
router.post('/',    controller.createTodo);
router.put('/:id',  controller.updateTodo);
router.delete('/:id', controller.deleteTodo);

module.exports = router;
