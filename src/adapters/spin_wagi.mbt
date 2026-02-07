///|
/// Spin(WAGI) adapter configuration placeholder
/// Actual runtime bridge will be implemented in moon-component side.
pub(all) struct SpinWagiConfig {
  component : String
  route : String
  executor : String
}

///|
pub fn SpinWagiConfig::default() -> SpinWagiConfig {
  { component: "mars-app", route: "/...", executor: "wagi" }
}

///|
pub(all) struct SpinWagiAdapter {
  app : @mars.Server
  config : SpinWagiConfig
}

///|
pub fn spin_wagi_adapter(
  app : @mars.Server,
  config? : SpinWagiConfig = SpinWagiConfig::default(),
) -> SpinWagiAdapter {
  { app, config }
}

///|
pub fn spin_wagi_runtime() -> RuntimeTarget {
  RuntimeTarget::SpinWagi
}

///|
pub fn SpinWagiAdapter::manifest_hint(self : SpinWagiAdapter) -> String {
  "[component.\{self.config.component}] route=\"\{self.config.route}\" executor=\"\{self.config.executor}\""
}
