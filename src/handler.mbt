///|
/// Handler function signature
/// Handler receives a Context and returns Unit
pub(all) struct Handler(async (Context) -> Unit raise Error)
