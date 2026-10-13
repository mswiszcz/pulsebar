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

  @Test func argumentsSkipPathAndPaddingThenStopAtCount() {
    let bytes = argumentCount + Array("/bin/claude\0\0\0claude\0-p\0HOME=/Users/me\0".utf8)
    #expect(ProcessArguments.arguments(fromProcArgs: bytes) == ["claude", "-p"])
  }

  @Test func argumentsKeepEmptyArgument() {
    let bytes: [UInt8] = [3, 0, 0, 0] + Array("/bin/x\0x\0\0last\0".utf8)
    #expect(ProcessArguments.arguments(fromProcArgs: bytes) == ["x", "", "last"])
  }

  @Test func argumentsReadCountAboveOneByte() {
    let values = (0..<300).map { "a\($0)" }
    let bytes: [UInt8] =
      [44, 1, 0, 0] + Array(("/bin/x\0" + values.joined(separator: "\0") + "\0").utf8)
    #expect(ProcessArguments.arguments(fromProcArgs: bytes) == values)
  }

  @Test(arguments: [[UInt8](), [1, 0, 0, 0], [1, 0, 0, 0] + Array("/bin/x".utf8)])
  func argumentsFromTruncatedBufferAreEmpty(bytes: [UInt8]) {
    #expect(ProcessArguments.arguments(fromProcArgs: bytes).isEmpty)
  }
}
