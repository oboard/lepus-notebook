export interface Note {
  id?: number
  content: string
  created_at?: string
  updated_at?: string
}

export interface Pageable {
  page: number
  size: number
  sort?: Sort | null
}

export interface Sort {
  direction: 'ASC' | 'DESC'
  property: string
}

export interface Page<T> {
  content: T[]
  total_elements: number
  total_pages: number
  number: number
  size: number
  first: boolean
  last: boolean
  empty: boolean
}

export interface DatabaseApi {
  save: (note: Note) => Promise<Note>
  delete: (note: Note) => Promise<boolean>
  list: (pageable: Pageable) => Promise<Page<Note>>
}

export interface LepusApi {
  database: DatabaseApi
}

// @ts-ignore
export let lepusApi: LepusApi = window.lepusApi
