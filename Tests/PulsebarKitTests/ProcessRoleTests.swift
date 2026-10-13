import PulsebarKit
import Testing

struct ProcessRoleTests {
  private let helper = "/Applications/Obsidian.app/Contents/Frameworks/Obsidian Helper"
  private let firefox =
    "/Applications/Firefox.app/Contents/MacOS/plugin-container.app/Contents/MacOS/plugin-container"

  @Test(arguments: [
    ("--type=renderer", "Renderer"),
    ("--type=gpu-process", "GPU"),
    ("--type=utility", "Utility"),
    ("--type=broker", "broker"),
  ])
  func chromiumTypeNamesRole(argument: String, role: String) {
    #expect(
      ProcessRole.name(arguments: [helper, argument, "--lang=en"], executablePath: helper) == role)
  }

  @Test func chromiumUtilityUsesServiceName() {
    let arguments = [helper, "--type=utility", "--utility-sub-type=network.mojom.NetworkService"]
    #expect(ProcessRole.name(arguments: arguments, executablePath: helper) == "Network Service")
  }

  @Test(arguments: [
    ("tab", "Web Content"), ("gpu", "GPU"), ("rdd", "Media Decoder"), ("socket", "Network"),
    ("weird", "weird"),
  ])
  func geckoLastArgumentNamesRole(kind: String, role: String) {
    let arguments = [
      firefox, "-isForBrowser", "-parentPid", "75740", "org.mozilla.machname.1", "161", kind,
    ]
    #expect(ProcessRole.name(arguments: arguments, executablePath: firefox) == role)
  }

  @Test func contentProcessFlagMarksGecko() {
    #expect(
      ProcessRole.name(
        arguments: ["/x/firefox", "-contentproc", "tab"], executablePath: "/x/firefox")
        == "Web Content")
  }

  @Test func otherProcessUsesExecutableName() {
    #expect(
      ProcessRole.name(
        arguments: ["firefox", "-foreground"],
        executablePath: "/Applications/Firefox.app/Contents/MacOS/firefox") == "firefox")
  }

  @Test func withoutArgumentsUsesExecutableName() {
    #expect(ProcessRole.name(arguments: [], executablePath: firefox) == "plugin-container")
  }
}
