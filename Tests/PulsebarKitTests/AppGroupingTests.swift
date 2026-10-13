import PulsebarKit
import Testing

struct AppGroupingTests {
  @Test(arguments: [
    ("/Applications/Firefox.app/Contents/MacOS/firefox", "Firefox", "/Applications/Firefox.app"),
    (
      "/Applications/Firefox.app/Contents/MacOS/plugin-container.app/Contents/MacOS/plugin-container",
      "Firefox", "/Applications/Firefox.app"
    ),
    (
      "/Applications/Docker.app/Contents/MacOS/com.docker.sailor", "Docker",
      "/Applications/Docker.app"
    ),
    (
      "/Applications/Visual Studio Code.app/Contents/MacOS/Electron", "Visual Studio Code",
      "/Applications/Visual Studio Code.app"
    ),
    ("Tools/Thing.app/Contents/MacOS/thing", "Thing", "Tools/Thing.app"),
  ])
  func bundledPathUsesOutermostApp(path: String, name: String, bundlePath: String) {
    #expect(
      AppGrouping.identity(forExecutablePath: path)
        == AppIdentity(name: name, bundlePath: bundlePath))
  }

  @Test(arguments: [
    ("/opt/homebrew/bin/node", "node"),
    ("/Users/me/.local/bin/claude", "claude"),
    ("bun", "bun"),
    ("/usr/libexec/app.applet/helper", "helper"),
    ("/tmp/weird/Tool.app", "Tool.app"),
    ("/opt/.app/bin/tool", "tool"),
  ])
  func nonBundlePathUsesBasename(path: String, name: String) {
    #expect(
      AppGrouping.identity(forExecutablePath: path) == AppIdentity(name: name, bundlePath: nil))
  }

  @Test(arguments: ["", "/", "///"])
  func emptyPathHasNoIdentity(path: String) {
    #expect(AppGrouping.identity(forExecutablePath: path) == nil)
  }
}
