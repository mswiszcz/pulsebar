import PulsebarKit
import Testing

struct PrometheusTextTests {
  private func parse(_ text: String) -> [MetricSample] {
    PrometheusText.parse(Array(text.utf8))
  }

  @Test func withPlainSampleReadsNameAndValue() {
    #expect(parse("node_load1 1.5") == [MetricSample(name: "node_load1", value: 1.5)])
  }

  @Test func withLabelsReadsEachPair() {
    let samples = parse(#"node_cpu_seconds_total{cpu="0",mode="idle"} 81234.5"#)
    #expect(
      samples == [
        MetricSample(
          name: "node_cpu_seconds_total", labels: ["cpu": "0", "mode": "idle"], value: 81234.5)
      ])
  }

  @Test func withEscapedLabelCharacters() {
    let samples = parse(#"m{path="a\"b",dir="c\\d",msg="x\ny"} 1"#)
    #expect(samples.first?.labels == ["path": #"a"b"#, "dir": #"c\d"#, "msg": "x\ny"])
  }

  @Test func whenLabelValueHasCommaAndBraceKeepsIt() {
    let samples = parse(#"m{a="x,y}z",b="2"} 2"#)
    #expect(samples.first?.labels == ["a": "x,y}z", "b": "2"])
  }

  @Test func withTrailingCommaInLabelsIsAccepted() {
    #expect(parse(#"m{a="1",} 3"#) == [MetricSample(name: "m", labels: ["a": "1"], value: 3)])
  }

  @Test func withEmptyBracesHasNoLabels() {
    #expect(parse("m{} 3") == [MetricSample(name: "m", value: 3)])
  }

  @Test func whenLineIsCommentOrBlankSkipsIt() {
    let text = """
      # HELP node_load1 1 minute load average.
      # TYPE node_load1 gauge

      node_load1 0.25
      """
    #expect(parse(text) == [MetricSample(name: "node_load1", value: 0.25)])
  }

  @Test func withSpecialFloatValuesParsesThem() {
    let samples = parse("a NaN\nb +Inf\nc -Inf")
    #expect(samples.count == 3)
    #expect(samples[0].value.isNaN)
    #expect(samples[1].value == .infinity)
    #expect(samples[2].value == -.infinity)
  }

  @Test func withExponentValueParsesIt() {
    #expect(parse("m 1.5e+09").first?.value == 1_500_000_000)
  }

  @Test func whenTimestampIsPresentIgnoresIt() {
    #expect(
      parse(#"m{a="1"} 42 1700000000000"#) == [
        MetricSample(name: "m", labels: ["a": "1"], value: 42)
      ])
  }

  @Test func whenLineIsMalformedSkipsOnlyThatLine() {
    let text = """
      m{a="unterminated 1
      bad value abc
      m{a=1} 2
      m 3 notatimestamp
      ok 5
      """
    #expect(parse(text) == [MetricSample(name: "ok", value: 5)])
  }

  @Test func withEmptyInputIsEmpty() {
    #expect(parse("").isEmpty)
    #expect(PrometheusText.parse([]).isEmpty)
  }
}
