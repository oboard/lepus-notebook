///|
async fn main {
  let engine = @sqlite3.SQLiteEngine::open("data.db")
  let note_mapper = NoteMapperImpl::new(engine)
  @morm.auto_migrate(engine, [Note::table()])
  @lepus.Window::new(title="Lepus Vite Example", source~, debug=1, plugins=[
    @webview.Plugin::new("database", plugin => {
      plugin.command("save", (note : Note) => {
        println(note.to_json().stringify())
        note_mapper.save(note)
      })
      plugin.command("delete", (note : Note) => note_mapper.delete(note))
      plugin.command("list", (pageable : @engine.Pageable) => {
        note_mapper.find_all(pageable)
      })
    }),
  ]).run()
}
