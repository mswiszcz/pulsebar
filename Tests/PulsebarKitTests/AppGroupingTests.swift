import PulsebarKit
import Testing

struct AppGroupingTests {
  @Test(arguments: [
    ("/Applications/Firefox.app/Contents/MacOS/firefox", "Firefox"),
    (
      "/Applications/Firefox.app/Contents/MacOS/plugin-container.app/Contents/MacOS/plugin-container",
      "Firefox"
    ),
    ("/Applications/Docker.app/Contents/MacOS/com.docker.sailor", "Docker"),
    ("/Applications/Visual Studio Code.app/Contents/MacOS/Electron", "Visual Studio Code"),
  ])
  func bundledPathUsesOutermostApp(path: String, expected: String) {
    #expect(AppGrouping.appName(forExecutablePath: path) == expected)
  }

  @Test(arguments: [
    ("/opt/homebrew/bin/node", "node"),
    ("/Users/me/.local/bin/claude", "claude"),
    ("bun", "bun"),
    ("/usr/libexec/app.applet/helper", "helper"),
  ])
  func nonBundlePathUsesBasename(path: String, expected: String) {
    #expect(AppGrouping.appName(forExecutablePath: path) == expected)
  }

  @Test func executableNamedLikeBundleUsesBasename() {
    #expect(AppGrouping.appName(forExecutablePath: "/tmp/weird/Tool.app") == "Tool.app")
  }

  @Test func bareAppSuffixDirectoryIsNotABundle() {
    #expect(AppGrouping.appName(forExecutablePath: "/opt/.app/bin/tool") == "tool")
  }

  @Test(arguments: ["", "/", "///"])
  func emptyPathHasNoName(path: String) {
    #expect(AppGrouping.appName(forExecutablePath: path) == nil)
  }
}
