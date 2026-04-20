<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { lepusApi, type Note, type Pageable, type Page } from './lepusApi'

const notes = ref<Note[]>([])
const newNoteContent = ref('')
const loading = ref(false)
const page = ref(0)
const size = ref(20)
const totalElements = ref(0)

async function loadNotes() {
  loading.value = true
  try {
    const pageable: Pageable = { page: page.value, size: size.value }
    const result: Page<Note> = await lepusApi.database.list(pageable)
    notes.value = result.content
    totalElements.value = result.total_elements
  } catch (e) {
    console.error('Failed to load notes:', e)
  } finally {
    loading.value = false
  }
}

async function addNote() {
  if (!newNoteContent.value.trim()) return
  try {
    const note: Note = { id: 0, content: newNoteContent.value }
    await lepusApi.database.save(note)
    newNoteContent.value = ''
    await loadNotes()
  } catch (e) {
    console.error('Failed to add note:', e)
  }
}

async function deleteNote(id: number) {
  try {
    await lepusApi.database.save({ id, content: '' })
    await loadNotes()
  } catch (e) {
    console.error('Failed to delete note:', e)
  }
}

onMounted(() => {
  loadNotes()
})
</script>

<template>
  <div class="container">
    <header class="header">
      <h1>Lepus Notebook</h1>
      <span class="subtitle">{{ totalElements }} notes</span>
    </header>

    <div class="add-form">
      <input
        v-model="newNoteContent"
        type="text"
        placeholder="Write a new note..."
        @keyup.enter="addNote"
      />
      <button @click="addNote" :disabled="!newNoteContent.trim()">Add</button>
    </div>

    <div v-if="loading" class="loading">Loading...</div>

    <div v-else class="notes-list">
      <div v-for="note in notes" :key="note.id" class="note-item">
        <div class="note-content">{{ note.content }}</div>
        <button class="delete-btn" @click="deleteNote(note.id)">Delete</button>
      </div>

      <div v-if="notes.length === 0 && !loading" class="empty">
        No notes yet. Start typing above!
      </div>
    </div>
  </div>
</template>

<style scoped>
.container {
  max-width: 600px;
  margin: 0 auto;
  padding: 20px;
}

.header {
  display: flex;
  align-items: baseline;
  gap: 12px;
  margin-bottom: 24px;
}

.header h1 {
  margin: 0;
  font-size: 24px;
  color: #213547;
}

.subtitle {
  color: #666;
  font-size: 14px;
}

.add-form {
  display: flex;
  gap: 8px;
  margin-bottom: 20px;
}

.add-form input {
  flex: 1;
  padding: 10px 14px;
  border: 1px solid #d1d5db;
  border-radius: 8px;
  font-size: 14px;
}

.add-form input:focus {
  outline: none;
  border-color: #646cff;
}

.add-form button {
  padding: 10px 20px;
  background: #646cff;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  cursor: pointer;
}

.add-form button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.notes-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.note-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
}

.note-content {
  flex: 1;
  color: #374151;
}

.delete-btn {
  padding: 6px 12px;
  background: #fee2e2;
  color: #dc2626;
  border: none;
  border-radius: 6px;
  font-size: 12px;
  cursor: pointer;
}

.delete-btn:hover {
  background: #fecaca;
}

.loading {
  text-align: center;
  color: #666;
  padding: 20px;
}

.empty {
  text-align: center;
  color: #999;
  padding: 40px;
}
</style>
