import PulsebarKit
import Testing

struct ProcessArgumentsTests {
  private let argumentCount: [UInt8] = [2, 0, 0, 0]

  @Test func readsExecutablePathAfterArgumentCount() {
    let bytes = argumentCount + Array("/Users/me/.local/bin/claude\0\0\0claude\0-p\0".utf8)
    #expect(ProcessArguments.executablePath(fromProcArgs: bytes) == "/Users/me/.local/bin/claude")
  }

  @Test func withoutTerminatorIsNil() {
    let bytes = argumentCount + Array("/bin/zsh".utf8)
    #expect(ProcessArguments.executablePath(fromProcArgs: bytes) == nil)
  }

  @Test func withEmptyPathIsNil() {
    #expect(ProcessArguments.executablePath(fromProcArgs: argumentCount + [0, 0]) == nil)
  }

  @Test(arguments: [[UInt8](), [1, 0]])
  func withTruncatedBufferIsNil(bytes: [UInt8]) {
    #expect(ProcessArguments.executablePath(fromProcArgs: bytes) == nil)
  }
}
