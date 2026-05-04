import Foundation

protocol Command {
    func run() async throws
}
