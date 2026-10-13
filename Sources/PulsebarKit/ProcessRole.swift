public enum ProcessRole {
  private static let geckoRoles = [
    "tab": "Web Content", "gpu": "GPU", "socket": "Network", "rdd": "Media Decoder",
    "utility": "Utility", "forkserver": "Fork Server",
  ]
  private static let chromiumRoles = [
    "renderer": "Renderer", "gpu-process": "GPU", "utility": "Utility", "zygote": "Zygote",
    "crashpad-handler": "Crash Reporter",
  ]

  public static func name(arguments: [String], executablePath: String) -> String {
    let executable = executablePath.split(separator: "/").last.map(String.init) ?? executablePath
    if let type = value(of: "--type", in: arguments) {
      if type == "utility", let subtype = value(of: "--utility-sub-type", in: arguments) {
        return serviceName(subtype)
      }
      return chromiumRoles[type] ?? type
    }
    if executable == "plugin-container" || arguments.contains("-contentproc"),
      let kind = arguments.last
    {
      return geckoRoles[kind] ?? kind
    }
    return executable
  }

  private static func value(of option: String, in arguments: [String]) -> String? {
    let prefix = option + "="
    return arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
  }

  private static func serviceName(_ subtype: String) -> String {
    let service = subtype.split(separator: ".").last.map(String.init) ?? subtype
    var words = ""
    for character in service {
      if character.isUppercase, !words.isEmpty { words.append(" ") }
      words.append(character)
    }
    return words
  }
}
