///|
/// ExecutionContext for background tasks
/// Similar to Cloudflare Workers ExecutionContext

///|
/// Background task that will run after response is sent
pub(all) struct BackgroundTask {
  /// Task function to execute
  task : async () -> Unit
  /// Task name for debugging
  name : String
}

///|
/// ExecutionContext manages background tasks
pub(all) struct ExecutionContext {
  /// Pending background tasks
  priv tasks : Array[BackgroundTask]
  /// Whether the context is still accepting tasks
  priv mut active : Bool
}

///|
/// Create a new ExecutionContext
pub fn ExecutionContext::new() -> ExecutionContext {
  { tasks: [], active: true }
}

///|
/// Schedule a background task to run after response is sent
/// Similar to Cloudflare's ctx.waitUntil()
pub fn ExecutionContext::wait_until(
  self : ExecutionContext,
  task : async () -> Unit,
  name? : String = "background",
) -> Unit {
  if self.active {
    self.tasks.push({ task, name })
  }
}

///|
/// Implement ExecCtx trait for ExecutionContext
pub impl ExecCtx for ExecutionContext with wait_until(self, task, name~) {
  self.wait_until(task, name~)
}

///|
/// Get number of pending tasks
pub fn ExecutionContext::pending_count(self : ExecutionContext) -> Int {
  self.tasks.length()
}

///|
/// Check if context is still active
pub fn ExecutionContext::is_active(self : ExecutionContext) -> Bool {
  self.active
}

///|
/// Deactivate context (no more tasks can be added)
pub fn ExecutionContext::deactivate(self : ExecutionContext) -> Unit {
  self.active = false
}

///|
/// Execute all pending background tasks
/// Called after response is sent
pub async fn ExecutionContext::run_tasks(self : ExecutionContext) -> Unit {
  self.active = false
  for bg_task in self.tasks {
    (bg_task.task)() catch {
      e => println("Background task '\{bg_task.name}' failed: \{e}")
    }
  }
}

///|
/// Get all pending tasks (for testing)
pub fn ExecutionContext::get_tasks(
  self : ExecutionContext,
) -> Array[BackgroundTask] {
  self.tasks
}
