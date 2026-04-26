///|
using @time {type PlainDateTime}

///|
#morm.entity
struct Note {
  #morm.id
  #morm.default(autoincrement())
  id : Int?
  content : String
  created_at : PlainDateTime?
  updated_at : PlainDateTime?
} derive(ToJson, FromJson)

///|
#morm.mapper(table="note")
trait NoteMapper {
  async save(Self, entity : Note) -> Note
  async delete(Self, entity : Note) -> Bool
  async find_all(Self, pageable : @engine.Pageable) -> @engine.Page[Note]
}