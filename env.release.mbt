///|
let source : @lepus.Source = @lepus.Source::zip(resource) catch {
  _ => @lepus.Source::html("Loading resource failed.")
}
