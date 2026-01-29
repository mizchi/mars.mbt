///|
test "ExecutionContext creation" {
  let ctx = ExecutionContext::new()
  inspect(ctx.is_active(), content="true")
  inspect(ctx.pending_count(), content="0")
}

///|
test "ExecutionContext wait_until adds tasks" {
  let ctx = ExecutionContext::new()
  ctx.wait_until(async fn() { () })
  ctx.wait_until(async fn() { () }, name="task2")
  inspect(ctx.pending_count(), content="2")
}

///|
test "ExecutionContext deactivate prevents new tasks" {
  let ctx = ExecutionContext::new()
  ctx.wait_until(async fn() { () })
  inspect(ctx.pending_count(), content="1")
  ctx.deactivate()
  inspect(ctx.is_active(), content="false")
  ctx.wait_until(async fn() { () }) // Should be ignored
  inspect(ctx.pending_count(), content="1") // Still 1
}

///|
test "ExecutionContext get_tasks returns all tasks" {
  let ctx = ExecutionContext::new()
  ctx.wait_until(async fn() { () }, name="first")
  ctx.wait_until(async fn() { () }, name="second")
  let tasks = ctx.get_tasks()
  inspect(tasks.length(), content="2")
  inspect(tasks[0].name, content="first")
  inspect(tasks[1].name, content="second")
}

///|
test "ExecutionContext default task name" {
  let ctx = ExecutionContext::new()
  ctx.wait_until(async fn() { () })
  let tasks = ctx.get_tasks()
  inspect(tasks[0].name, content="background")
}
