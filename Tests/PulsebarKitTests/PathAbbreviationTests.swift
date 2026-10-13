import PulsebarKit
import Testing

struct PathAbbreviationTests {
  @Test(arguments: [
    ("/Users/me/Labs/storykit", "~/Labs/storykit"),
    ("/Users/me/Labs/a/b/storykit", "~/…/b/storykit"),
    ("/Users/me/Labs", "~/Labs"),
    ("/Users/me", "~"),
    ("/Users/me/", "~"),
    ("/Users/meadow/x", "/…/meadow/x"),
    ("/opt/homebrew/var/www", "/…/var/www"),
    ("/tmp", "/tmp"),
    ("/", "/"),
  ])
  func abbreviatesHomeAndKeepsLastTwo(path: String, expected: String) {
    #expect(PathAbbreviation.short(path, home: "/Users/me") == expected)
  }
}
