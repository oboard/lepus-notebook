///|
pub impl @oboard/morm.Entity for Note with table(_self) -> @oboard/morm.Table {
  Note::table()
}

///|
pub fn Note::table() -> @oboard/morm.Table {
  @oboard/morm.Table::{
    name: "note",
    schema: None,
    catalog: None,
    columns: [
      {
        name: "id",
        column_type: Int,
        size: 0,
        nullable: false,
        auto_increment: true,
        primary_key: true,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
        engine_options: [{ key: "pk.strategy", value: "auto_increment" }],
      },
      {
        name: "content",
        column_type: VarChar(255),
        size: 0,
        nullable: false,
        auto_increment: false,
        primary_key: false,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
        engine_options: [],
      },
    ],
    indexes: [],
    foreign_keys: [],
    temporary: false,
    if_not_exists: true,
    engine: None,
    charset: None,
    collation: None,
    tablespace: None,
    comment: "",
    auto_increment: None,
    engine_options: [],
  }
}

///|
pub fn Note::_from(row : Map[String, @engine.Param]) -> Note {
  let id_param = match row.get("id") {
    Some(value) => value
    None => panic()
  }
  let id : Int? = match id_param {
    Null => None
    _ => Some((try! @engine.from_param(id_param) : Int))
  }
  let content_param = match row.get("content") {
    Some(value) => value
    None => panic()
  }
  let content : String = (try! @engine.from_param(content_param) : String)
  return Note::{ id, content }
}

///|
pub impl @engine.FromParam for Note with from_param(value) {
  match value {
    @engine.Object(obj) => {
      let row : Map[String, @engine.Param] = Map::new()
      for key in obj.keys() {
        if obj.get(key) is Some(value) {
          row.set(key, value)
        }
      }
      Note::_from(row)
    }
    _ =>
      raise @engine.ParamDecodeError(
        "Note::from_param: expected Json object row",
      )
  }
}

///|
pub struct NoteMapperImpl {
  engine : &@engine.Engine
}

///|
pub fn NoteMapperImpl::new(engine : &@engine.Engine) -> NoteMapperImpl {
  NoteMapperImpl::{ engine, }
}

///|
pub impl NoteMapper for NoteMapperImpl with save(self, entity : Note) -> Note {
  let q = @oboard/morm.upsert_into("note").from(entity)
  let res = self.engine.exec(q)
  if res.rows is [result, ..] {
    return Note::_from(result)
  }
  panic()
}

///|
pub impl NoteMapper for NoteMapperImpl with delete(self, entity : Note) -> Bool {
  let q = @oboard/morm.delete_from("note").from(entity)
  self.engine.exec(q).ok
}

///|
pub impl NoteMapper for NoteMapperImpl with find_all(
  self,
  pageable : @engine.Pageable,
) -> @engine.Page[Note] {
  @morm.paginate(self.engine, @morm.select_from("note"), pageable)
}
