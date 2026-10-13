import PulsebarKit
import SwiftUI

enum ServerTestState {
  case running
  case finished(String)
}

struct ServerSettingsSection: View {
  @State private var servers = ServerSettings.load()
  @State private var monitor = HomelabMonitor()
  @State private var testStates: [UUID: ServerTestState] = [:]
  @State private var newName = ""
  @State private var newURL = ""

  var body: some View {
    Section("Servers") {
      ForEach($servers) { $server in
        ServerRow(
          server: $server,
          testState: testStates[server.id],
          onCommit: { ServerSettings.save(servers) },
          onTest: { test(server) },
          onRemove: remove)
      }
      VStack(alignment: .leading) {
        TextField("Name", text: $newName)
        TextField("URL", text: $newURL)
          .onSubmit(addServer)
        HStack {
          Spacer()
          Button("Add server", action: addServer)
            .disabled(ServerURL.normalize(newURL) == nil)
        }
      }
    }
  }

  private func test(_ server: ServerConfig) {
    testStates[server.id] = .running
    Task {
      let result = await monitor.fetch(server.url)
      testStates[server.id] = .finished(ServerTestResult.message(for: result, url: server.url))
    }
  }

  private func remove(_ id: UUID) {
    servers.removeAll { $0.id == id }
    testStates[id] = nil
    ServerSettings.save(servers)
  }

  private func addServer() {
    guard let url = ServerURL.normalize(newURL) else { return }
    servers.append(ServerConfig(name: displayName(newName, for: url), url: url))
    newName = ""
    newURL = ""
    ServerSettings.save(servers)
  }
}

private struct ServerRow: View {
  @Binding var server: ServerConfig
  let testState: ServerTestState?
  let onCommit: () -> Void
  let onTest: () -> Void
  let onRemove: (UUID) -> Void

  @State private var name: String
  @State private var urlDraft: String
  @State private var urlIsInvalid = false
  @FocusState private var focus: Field?

  private enum Field {
    case name
    case url
  }

  init(
    server: Binding<ServerConfig>,
    testState: ServerTestState?,
    onCommit: @escaping () -> Void,
    onTest: @escaping () -> Void,
    onRemove: @escaping (UUID) -> Void
  ) {
    _server = server
    self.testState = testState
    self.onCommit = onCommit
    self.onTest = onTest
    self.onRemove = onRemove
    _name = State(initialValue: server.wrappedValue.name)
    _urlDraft = State(initialValue: server.wrappedValue.url.absoluteString)
  }

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        TextField("Name", text: $name)
          .focused($focus, equals: .name)
          .onSubmit(commitName)
          .frame(width: 120)
        TextField("URL", text: $urlDraft)
          .focused($focus, equals: .url)
          .onSubmit(commitURL)
        Button("Test", action: onTest)
          .disabled(isRunning)
        Button {
          onRemove(server.id)
        } label: {
          Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Remove \(server.name)")
      }
      .onChange(of: focus) { old, new in
        if old == .name, new != .name { commitName() }
        if old == .url, new != .url { commitURL() }
      }
      if urlIsInvalid {
        Text("Enter a host like nas.lan or a URL like http://nas.lan:9100/metrics")
          .font(.caption)
          .foregroundStyle(.red)
      }
      if let testState {
        switch testState {
        case .running:
          ProgressView().controlSize(.small)
        case .finished(let message):
          Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var isRunning: Bool {
    if case .running = testState { return true }
    return false
  }

  private func commitName() {
    server.name = displayName(name, for: server.url)
    name = server.name
    onCommit()
  }

  private func commitURL() {
    guard let url = ServerURL.normalize(urlDraft) else {
      urlIsInvalid = true
      return
    }
    urlIsInvalid = false
    server.url = url
    urlDraft = url.absoluteString
    onCommit()
  }
}

private func displayName(_ name: String, for url: URL) -> String {
  let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
  return trimmed.isEmpty ? (url.host() ?? url.absoluteString) : trimmed
}
