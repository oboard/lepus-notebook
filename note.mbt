///|
#morm.entity
struct Note {
  #morm.id
  id : Int
  content : String
} derive(Debug, ToJson, FromJson)

///|
#morm.mapper(table="note")
trait NoteMapper {
  async save(Self, entity : Note) -> Note
  async find_all(
    Self,
    pageable : @engine.Pageable,
  ) -> @engine.Page[Note]
}
