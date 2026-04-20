<template>
  <div class="app">
    <aside class="sidebar">
      <div class="toolbar">
        <span class="note-count">{{ notes.length }} 个备忘录</span>
        <button class="compose-btn" @click="createNote" title="新建备忘录">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 20h9M16.5 3.5a2.121 2.121 0 013 3L7 19l-4 1 1-4L16.5 3.5z" />
          </svg>
        </button>
      </div>

      <div class="search-wrap">
        <svg class="search-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"
          stroke-width="2.5">
          <circle cx="11" cy="11" r="8" />
          <path d="m21 21-4.35-4.35" />
        </svg>
        <input v-model="search" class="search-input" placeholder="搜索" @input="filterNotes" />
        <button v-if="search" class="search-clear" @click="search = ''; filterNotes()">×</button>
      </div>

      <div class="notes-scroll" @scroll="handleScroll">
        <div v-for="note in filteredNotes" :key="note.id" class="note-row" :class="{ active: activeId === note.id }"
          @click="selectNote(note)">
          <div class="row-body">
            <div class="row-title">{{ firstLine(note.content) }}</div>
            <div class="row-meta">
              <span class="row-date">{{ formatDate(note.updated_at || note.created_at) }}</span>
              <span class="row-snippet">{{ secondLine(note.content) }}</span>
            </div>
          </div>
          <button class="row-delete" @click.stop="deleteNote(note.id!)">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
          </button>
        </div>
        <div v-if="loading" class="list-loading">
          <span class="spinner"></span>
        </div>
        <div v-if="filteredNotes.length === 0 && !loading" class="list-empty">无备忘录</div>
      </div>
    </aside>

    <main class="editor" @click="focusEditor">
      <div v-if="currentNote" class="editor-inner">
        <div class="editor-meta">{{ formatDateFull(currentNote.updated_at || currentNote.created_at) }}</div>
        <textarea ref="editorEl" v-model="currentNote.content" class="editor-area" placeholder="开始输入..."
          @input="onInput" spellcheck="false"></textarea>
        <div v-if="saving" class="save-indicator">保存中...</div>
        <div v-else-if="saved" class="save-indicator saved">已保存</div>
      </div>
      <div v-else class="editor-placeholder">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#ccc" stroke-width="1.5">
          <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
          <polyline points="14 2 14 8 20 8" />
          <line x1="16" y1="13" x2="8" y2="13" />
          <line x1="16" y1="17" x2="8" y2="17" />
          <polyline points="10 9 9 9 8 9" />
        </svg>
        <p>选择或新建备忘录</p>
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, nextTick, onMounted } from 'vue'
import { lepusApi, type Note } from './lepusApi'

const notes = ref<Note[]>([])
const filteredNotes = ref<Note[]>([])
const currentNote = ref<Note | null>(null)
const activeId = ref<number | null>(null)
const search = ref('')
const loading = ref(false)
const saving = ref(false)
const saved = ref(false)
const page = ref(0)
const hasMore = ref(true)
const editorEl = ref<HTMLTextAreaElement>()

// ---- 数据加载 ----
async function loadNotes(append = false) {
  if (loading.value || (!append && false) || (append && !hasMore.value)) return
  loading.value = true
  try {
    const res = await lepusApi.database.list({ page: page.value, size: 20 })
    const items = res.content
    if (append) {
      notes.value.push(...items)
    } else {
      notes.value = items
      if (items.length > 0 && !currentNote.value) selectNote(items[0])
    }
    filteredNotes.value = applyFilter(notes.value)
    hasMore.value = items.length === 20
    page.value++
  } finally {
    loading.value = false
  }
}

function handleScroll(e: Event) {
  const el = e.target as HTMLElement
  if (el.scrollHeight - el.scrollTop - el.clientHeight < 80) {
    loadNotes(true)
  }
}

// ---- 搜索 ----
function applyFilter(list: Note[]) {
  if (!search.value.trim()) return list
  const kw = search.value.toLowerCase()
  return list.filter(n => n.content.toLowerCase().includes(kw))
}
function filterNotes() {
  filteredNotes.value = applyFilter(notes.value)
}

// ---- CRUD ----
async function createNote() {
  const note = await lepusApi.database.save({ content: '' } as Note)
  notes.value.unshift(note)
  filteredNotes.value = applyFilter(notes.value)
  await selectNote(note)
}

async function selectNote(note: Note) {
  // 切换前先把当前未保存的内容强制保存
  if (currentNote.value && currentNote.value.id !== note.id) {
    clearTimeout(saveTimer)
    await doSave()
  }
  currentNote.value = { ...note }
  activeId.value = note.id ?? null
  nextTick(() => editorEl.value?.focus())
}

async function deleteNote(id: number) {
  await lepusApi.database.delete({ id, content: '' } as Note)
  notes.value = notes.value.filter(n => n.id !== id)
  filteredNotes.value = filteredNotes.value.filter(n => n.id !== id)
  if (activeId.value === id) {
    const next = filteredNotes.value[0] ?? null
    currentNote.value = next ? { ...next } : null
    activeId.value = next?.id ?? null
  }
}

// ---- 保存 ----
let saveTimer: ReturnType<typeof setTimeout>
let savedTimer: ReturnType<typeof setTimeout>

function onInput() {
  saved.value = false
  clearTimeout(saveTimer)
  saveTimer = setTimeout(doSave, 600)
}

async function doSave() {
  if (!currentNote.value) return
  saving.value = true
  try {
    const updated = await lepusApi.database.save(currentNote.value)
    // 同步列表里的数据
    const idx = notes.value.findIndex(n => n.id === updated.id)
    if (idx !== -1) notes.value[idx] = updated
    filteredNotes.value = applyFilter(notes.value)
    saved.value = true
    clearTimeout(savedTimer)
    savedTimer = setTimeout(() => { saved.value = false }, 2000)
  } finally {
    saving.value = false
  }
}

// ---- 格式化 ----
function firstLine(content: string) {
  return content.split('\n').find(l => l.trim()) || '新备忘录'
}
function secondLine(content: string) {
  const lines = content.split('\n').filter(l => l.trim())
  return lines[1] ?? '暂无其他内容'
}
function formatDate(dt?: string) {
  if (!dt) return ''
  const d = new Date(dt)
  const now = new Date()
  const diff = (now.getTime() - d.getTime()) / 1000
  if (diff < 60) return '刚刚'
  if (diff < 3600) return `${Math.floor(diff / 60)} 分钟前`
  if (diff < 86400) return d.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
  if (diff < 86400 * 7) {
    const days = ['日', '一', '二', '三', '四', '五', '六']
    return `星期${days[d.getDay()]}`
  }
  return d.toLocaleDateString('zh-CN', { month: 'numeric', day: 'numeric' })
}
function formatDateFull(dt?: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleString('zh-CN', {
    year: 'numeric', month: 'long', day: 'numeric',
    hour: '2-digit', minute: '2-digit'
  })
}

function focusEditor() {
  editorEl.value?.focus()
}

onMounted(() => {
  loadNotes()
  // 切换标签页 / 最小化窗口时立即保存
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') {
      clearTimeout(saveTimer)
      doSave()
    }
  })
})
</script>

<style>
*,
*::before,
*::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  background: #1e1e1e;
}
</style>

<style scoped>
.app {
  display: flex;
  height: 100vh;
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', sans-serif;
  background: #fff;
}

/* ---- sidebar ---- */
.sidebar {
  width: 280px;
  min-width: 220px;
  background: #f6f5f3;
  border-right: 1px solid #e0dedd;
  display: flex;
  flex-direction: column;
  user-select: none;
}

.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px 16px 10px;
}

.note-count {
  font-size: 11px;
  font-weight: 600;
  color: #888;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}

.compose-btn {
  width: 30px;
  height: 30px;
  border: none;
  background: transparent;
  color: #f5a623;
  border-radius: 6px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.15s;
}

.compose-btn:hover {
  background: rgba(0, 0, 0, .06);
}

.search-wrap {
  position: relative;
  margin: 0 10px 8px;
}

.search-icon {
  position: absolute;
  left: 9px;
  top: 50%;
  transform: translateY(-50%);
  color: #999;
  pointer-events: none;
}

.search-input {
  width: 100%;
  padding: 6px 28px 6px 28px;
  border: none;
  border-radius: 7px;
  background: rgba(0, 0, 0, .07);
  font-size: 13px;
  color: #333;
}

.search-input:focus {
  outline: none;
  background: rgba(0, 0, 0, .1);
}

.search-clear {
  position: absolute;
  right: 8px;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  color: #999;
  font-size: 15px;
  cursor: pointer;
  line-height: 1;
}

.notes-scroll {
  flex: 1;
  overflow-y: auto;
  padding-bottom: 8px;
}

.notes-scroll::-webkit-scrollbar {
  width: 5px;
}

.notes-scroll::-webkit-scrollbar-thumb {
  background: #ccc;
  border-radius: 3px;
}

.note-row {
  display: flex;
  align-items: center;
  padding: 10px 12px 10px 16px;
  cursor: pointer;
  border-bottom: 1px solid rgba(0, 0, 0, .05);
  position: relative;
  gap: 8px;
}

.note-row:hover {
  background: rgba(0, 0, 0, .04);
}

.note-row.active {
  background: #fde68a;
}

.note-row.active .row-date,
.note-row.active .row-snippet {
  color: rgba(0, 0, 0, .5);
}

.row-body {
  flex: 1;
  min-width: 0;
}

.row-title {
  font-size: 14px;
  font-weight: 600;
  color: #1a1a1a;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin-bottom: 3px;
}

.row-meta {
  display: flex;
  gap: 6px;
  align-items: baseline;
}

.row-date {
  font-size: 11px;
  color: #888;
  white-space: nowrap;
  flex-shrink: 0;
}

.row-snippet {
  font-size: 12px;
  color: #aaa;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.row-delete {
  opacity: 0;
  width: 22px;
  height: 22px;
  border: none;
  background: rgba(0, 0, 0, .1);
  border-radius: 50%;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #666;
  flex-shrink: 0;
  transition: opacity 0.15s, background 0.15s;
}

.note-row:hover .row-delete {
  opacity: 1;
}

.row-delete:hover {
  background: #ff3b30;
  color: #fff;
}

.list-loading {
  display: flex;
  justify-content: center;
  padding: 16px;
}

.spinner {
  width: 18px;
  height: 18px;
  border: 2px solid #ddd;
  border-top-color: #999;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.list-empty {
  text-align: center;
  padding: 40px 0;
  font-size: 13px;
  color: #bbb;
}

/* ---- editor ---- */
.editor {
  flex: 1;
  display: flex;
  flex-direction: column;
  background: #fffef9;
  cursor: text;
}

.editor-inner {
  flex: 1;
  display: flex;
  flex-direction: column;
  position: relative;
}

.editor-meta {
  text-align: center;
  padding: 16px 0 4px;
  font-size: 11px;
  color: #bbb;
  letter-spacing: 0.02em;
}

.editor-area {
  flex: 1;
  padding: 16px 60px 60px;
  border: none;
  background: transparent;
  resize: none;
  font-size: 15px;
  line-height: 1.7;
  font-family: inherit;
  color: #1a1a1a;
}

.editor-area:focus {
  outline: none;
}

.editor-area::placeholder {
  color: #ccc;
}

.save-indicator {
  position: absolute;
  bottom: 16px;
  right: 20px;
  font-size: 11px;
  color: #bbb;
  transition: opacity 0.3s;
}

.save-indicator.saved {
  color: #34c759;
}

.editor-placeholder {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  color: #ccc;
  font-size: 14px;
  cursor: default;
}
</style>