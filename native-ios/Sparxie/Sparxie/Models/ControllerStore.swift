import Foundation
import Combine

@MainActor
class ControllerStore: ObservableObject {
    @Published var controllers: [Controller] = []
    @Published var activeControllerId: UUID?

    private let saveURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("sparxie", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.saveURL = dir.appendingPathComponent("controllers.json")
        load()
    }

    var activeController: Controller? {
        controllers.first { $0.id == activeControllerId }
    }

    func add(_ controller: Controller) {
        controllers.append(controller)
        if controllers.count == 1 {
            activeControllerId = controller.id
        }
        save()
    }

    func update(_ controller: Controller) {
        if let idx = controllers.firstIndex(where: { $0.id == controller.id }) {
            controllers[idx] = controller
            save()
        }
    }

    func delete(_ controller: Controller) {
        controllers.removeAll { $0.id == controller.id }
        if activeControllerId == controller.id {
            activeControllerId = controllers.first?.id
        }
        save()
    }

    func activate(_ controller: Controller) {
        activeControllerId = controller.id
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(controllers) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([Controller].self, from: data) else { return }
        controllers = decoded
    }
}