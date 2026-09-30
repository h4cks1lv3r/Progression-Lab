import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testLocalDeletionIncludesPrivatePluginPhotosAndAllCacheChildren() throws {
    let manager = FileManager.default
    let fixture = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? manager.removeItem(at: fixture) }
    let support = fixture.appendingPathComponent("support", isDirectory: true)
    let temporary = fixture.appendingPathComponent("tmp", isDirectory: true)
    let caches = fixture.appendingPathComponent("caches", isDirectory: true)
    let stage = support.appendingPathComponent("Progression Lab Delete Staging", isDirectory: true)
    let outside = fixture.appendingPathComponent("outside", isDirectory: true)
    for directory in [support, temporary, caches, stage, outside] {
      try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    let camera = temporary.appendingPathComponent("camera/session", isDirectory: true)
    try manager.createDirectory(at: camera, withIntermediateDirectories: true)
    let files = [
      temporary.appendingPathComponent("image_picker_fixture.jpg"),
      camera.appendingPathComponent("private-photo.jpg"),
      temporary.appendingPathComponent(".private-plugin-cache"),
      caches.appendingPathComponent("private-thumbnail.jpg"),
      support.appendingPathComponent("private-data.json"),
    ]
    for file in files { try Data("private".utf8).write(to: file) }
    let exported = outside.appendingPathComponent("exported-photo.jpg")
    try Data("exported".utf8).write(to: exported)
    let externalLink = temporary.appendingPathComponent("external-link")
    try manager.createSymbolicLink(at: externalLink, withDestinationURL: outside)

    let paths = try AppDelegate.localDataDeletionPaths(
      supportDirectory: support,
      temporaryDirectory: temporary,
      cachesDirectory: caches,
      stagingDirectory: stage
    )
    let selectedPaths = paths.map { $0.standardizedFileURL.path }
    XCTAssertFalse(selectedPaths.contains(stage.standardizedFileURL.path))
    XCTAssertTrue(selectedPaths.contains(temporary.appendingPathComponent("image_picker_fixture.jpg").path))
    XCTAssertTrue(selectedPaths.contains(temporary.appendingPathComponent("camera", isDirectory: true).path))
    XCTAssertTrue(selectedPaths.contains(temporary.appendingPathComponent(".private-plugin-cache").path))
    XCTAssertTrue(selectedPaths.contains(caches.appendingPathComponent("private-thumbnail.jpg").path))
    for (index, original) in paths.enumerated() {
      try manager.moveItem(at: original, to: stage.appendingPathComponent("data-\(index)"))
    }
    try manager.removeItem(at: stage)
    for file in files { XCTAssertFalse(manager.fileExists(atPath: file.path)) }
    XCTAssertTrue(manager.fileExists(atPath: exported.path))
    XCTAssertEqual(try Data(contentsOf: exported), Data("exported".utf8))
  }

}
