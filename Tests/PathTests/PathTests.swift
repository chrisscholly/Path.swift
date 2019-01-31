import XCTest
import Path

class PathTests: XCTestCase {
    func testConcatenation() {
        XCTAssertEqual((Path.root/"bar").string, "/bar")
        XCTAssertEqual(Path.cwd.string, FileManager.default.currentDirectoryPath)
        XCTAssertEqual((Path.root/"/bar").string, "/bar")
        XCTAssertEqual((Path.root/"///bar").string, "/bar")
        XCTAssertEqual((Path.root/"foo///bar////").string, "/foo/bar")
        XCTAssertEqual((Path.root/"foo"/"/bar").string, "/foo/bar")
    }

    func testEnumeration() throws {
        let tmpdir_ = try TemporaryDirectory()
        let tmpdir = tmpdir_.path
        try tmpdir.a.mkdir().c.touch()
        try tmpdir.join("b.swift").touch()
        try tmpdir.c.touch()
        try tmpdir.join(".d").mkdir().e.touch()

        var paths = Set<String>()
        let lsrv = try tmpdir.ls()
        var dirs = 0
        for entry in lsrv {
            if entry.kind == .directory {
                dirs += 1
            }
            paths.insert(entry.path.basename())
        }
        XCTAssertEqual(dirs, 2)
        XCTAssertEqual(dirs, lsrv.directories.count)
        XCTAssertEqual(["a", ".d"], Set(lsrv.directories.map{ $0.relative(to: tmpdir) }))
        XCTAssertEqual(["b.swift", "c"], Set(lsrv.files.map{ $0.relative(to: tmpdir) }))
        XCTAssertEqual(["b.swift"], Set(lsrv.files(withExtension: "swift").map{ $0.relative(to: tmpdir) }))
        XCTAssertEqual(["c"], Set(lsrv.files(withExtension: "").map{ $0.relative(to: tmpdir) }))
        XCTAssertEqual(paths, ["a", "b.swift", "c", ".d"])
        
    }

    func testEnumerationSkippingHiddenFiles() throws {
    #if !os(Linux)
        let tmpdir_ = try TemporaryDirectory()
        let tmpdir = tmpdir_.path
        try tmpdir.join("a").mkdir().join("c").touch()
        try tmpdir.join("b").touch()
        try tmpdir.join("c").touch()
        try tmpdir.join(".d").mkdir().join("e").touch()
        
        var paths = Set<String>()
        var dirs = 0
        for entry in try tmpdir.ls(includeHiddenFiles: false) {
            if entry.kind == .directory {
                dirs += 1
            }
            paths.insert(entry.path.basename())
        }
        XCTAssertEqual(dirs, 1)
        XCTAssertEqual(paths, ["a", "b", "c"])
    #endif
    }

    func testRelativeTo() {
        XCTAssertEqual((Path.root/"tmp/foo").relative(to: .root/"tmp"), "foo")
        XCTAssertEqual((Path.root/"tmp/foo/bar").relative(to: .root/"tmp/baz"), "../foo/bar")
    }

    func testExists() {
        XCTAssert(Path.root.exists)
        XCTAssert((Path.root/"bin").exists)
    }

    func testIsDirectory() {
        XCTAssert(Path.root.isDirectory)
        XCTAssert((Path.root/"bin").isDirectory)
    }

    func testExtension() {
        XCTAssertEqual(Path.root.join("a.swift").extension, "swift")
        XCTAssertEqual(Path.root.join("a").extension, "")
        XCTAssertEqual(Path.root.join("a.").extension, "")
        XCTAssertEqual(Path.root.join("a..").extension, "")
        XCTAssertEqual(Path.root.join("a..swift").extension, "swift")
        XCTAssertEqual(Path.root.join("a..swift.").extension, "")
        XCTAssertEqual(Path.root.join("a.tar.gz").extension, "tar.gz")
        XCTAssertEqual(Path.root.join("a..tar.gz").extension, "tar.gz")
        XCTAssertEqual(Path.root.join("a..tar..gz").extension, "gz")
    }

    func testMktemp() throws {
        var path: Path!
        try Path.mktemp {
            path = $0
            XCTAssert(path.isDirectory)
        }
        XCTAssert(!path.exists)
        XCTAssert(!path.isDirectory)
    }

    func testMkpathIfExists() throws {
        try Path.mktemp {
            for _ in 0...1 {
                try $0.join("a").mkdir()
                try $0.join("b/c").mkdir(.p)
            }
        }
    }

    func testBasename() {
        XCTAssertEqual(Path.root.join("foo.bar").basename(dropExtension: true), "foo")
        XCTAssertEqual(Path.root.join("foo").basename(dropExtension: true), "foo")
        XCTAssertEqual(Path.root.join("foo.").basename(dropExtension: true), "foo.")
        XCTAssertEqual(Path.root.join("foo.bar.baz").basename(dropExtension: true), "foo.bar")
    }

    func testCodable() throws {
        let input = [Path.root/"bar"]
        XCTAssertEqual(try JSONDecoder().decode([Path].self, from: try JSONEncoder().encode(input)), input)
    }

    func testRelativePathCodable() throws {
        let root = Path.root/"bar"
        let input = [
            root/"foo"
        ]

        let encoder = JSONEncoder()
        encoder.userInfo[.relativePath] = root
        let data = try encoder.encode(input)

        XCTAssertEqual(try JSONSerialization.jsonObject(with: data) as? [String], ["foo"])

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode([Path].self, from: data))
        decoder.userInfo[.relativePath] = root
        XCTAssertEqual(try decoder.decode([Path].self, from: data), input)
    }

    func testJoin() {
        let prefix = Path.root/"Users/mxcl"

        XCTAssertEqual(prefix/"b", Path("/Users/mxcl/b"))
        XCTAssertEqual(prefix/"b"/"c", Path("/Users/mxcl/b/c"))
        XCTAssertEqual(prefix/"b/c", Path("/Users/mxcl/b/c"))
        XCTAssertEqual(prefix/"/b", Path("/Users/mxcl/b"))
        let b = "b"
        let c = "c"
        XCTAssertEqual(prefix/b/c, Path("/Users/mxcl/b/c"))
        XCTAssertEqual(Path.root/"~b", Path("/~b"))
        XCTAssertEqual(Path.root/"~/b", Path("/~/b"))
        XCTAssertEqual(Path("~/foo"), Path.home/"foo")
        XCTAssertNil(Path("~foo"))

        XCTAssertEqual(Path.root/"a/foo"/"../bar", Path.root/"a/bar")
        XCTAssertEqual(Path.root/"a/foo"/"/../bar", Path.root/"a/bar")
        XCTAssertEqual(Path.root/"a/foo"/"../../bar", Path.root/"bar")
        XCTAssertEqual(Path.root/"a/foo"/"../../../bar", Path.root/"bar")
    }

    func testDynamicMember() {
        XCTAssertEqual(Path.root.Documents, Path.root/"Documents")

        let a = Path.home.foo
        XCTAssertEqual(a.Documents, Path.home/"foo/Documents")
    }

    func testCopyTo() throws {
        try Path.mktemp { root in
            try root.foo.touch().copy(to: root.bar)
            XCTAssert(root.foo.isFile)
            XCTAssert(root.bar.isFile)
        }
    }

    func testCopyInto() throws {
        try Path.mktemp { root1 in
            let bar1 = try root1.join("bar").touch()
            try Path.mktemp { root2 in
                let bar2 = try root2.join("bar").touch()
                XCTAssertThrowsError(try bar1.copy(into: root2))
                try bar1.copy(into: root2, overwrite: true)
                XCTAssertTrue(bar1.exists)
                XCTAssertTrue(bar2.exists)
            }
        }
    }

    func testMoveTo() throws {
        try Path.mktemp { root in
            try root.foo.touch().move(to: root.bar)
            XCTAssertFalse(root.foo.exists)
            XCTAssert(root.bar.isFile)
        }
    }

    func testMoveInto() throws {
        try Path.mktemp { root1 in
            let bar1 = try root1.join("bar").touch()
            try Path.mktemp { root2 in
                let bar2 = try root2.join("bar").touch()
                XCTAssertThrowsError(try bar1.move(into: root2))
                try bar1.move(into: root2, overwrite: true)
                XCTAssertFalse(bar1.exists)
                XCTAssertTrue(bar2.exists)
            }
        }
    }

    func testRename() throws {
        try Path.mktemp { root in
            do {
                let file = try root.bar.touch()
                let foo = try file.rename(to: "foo")
                XCTAssertFalse(file.exists)
                XCTAssertTrue(foo.isFile)
            }
            do {
                let file = try root.bar.touch()
                XCTAssertThrowsError(try file.rename(to: "foo"))
            }
        }
    }

    func testCommonDirectories() {
        XCTAssertEqual(Path.root.string, "/")
        XCTAssertEqual(Path.home.string, NSHomeDirectory())
        XCTAssertEqual(Path.documents.string, NSHomeDirectory() + "/Documents")
    #if os(macOS)
        XCTAssertEqual(Path.caches.string, NSHomeDirectory() + "/Library/Caches")
        XCTAssertEqual(Path.cwd.string, FileManager.default.currentDirectoryPath)
        XCTAssertEqual(Path.applicationSupport.string, NSHomeDirectory() + "/Library/Application Support")
    #endif
    }

    func testStringConvertibles() {
        XCTAssertEqual(Path.root.description, "/")
        XCTAssertEqual(Path.root.debugDescription, "Path(/)")
    }

    func testFilesystemAttributes() throws {
        XCTAssert(Path(#file)!.isFile)
        XCTAssert(Path(#file)!.isReadable)
        XCTAssert(Path(#file)!.isWritable)
        XCTAssert(Path(#file)!.isDeletable)
        XCTAssert(Path(#file)!.parent.isDirectory)

        try Path.mktemp { tmpdir in
            XCTAssertTrue(tmpdir.isDirectory)
            XCTAssertFalse(tmpdir.isFile)

            let bar = try tmpdir.bar.touch().chmod(0o000)
            XCTAssertFalse(bar.isReadable)
            XCTAssertFalse(bar.isWritable)
            XCTAssertFalse(bar.isDirectory)
            XCTAssertFalse(bar.isExecutable)
            XCTAssertTrue(bar.isFile)
            XCTAssertTrue(bar.isDeletable)  // can delete even if no read permissions

            try bar.chmod(0o777)
            XCTAssertTrue(bar.isReadable)
            XCTAssertTrue(bar.isWritable)
            XCTAssertTrue(bar.isDeletable)
            XCTAssertTrue(bar.isExecutable)

            try bar.delete()
            XCTAssertFalse(bar.exists)
            XCTAssertFalse(bar.isReadable)
            XCTAssertFalse(bar.isWritable)
            XCTAssertFalse(bar.isExecutable)
            XCTAssertFalse(bar.isDeletable)

            let nonExistantFile = tmpdir.baz
            XCTAssertFalse(nonExistantFile.exists)
            XCTAssertFalse(nonExistantFile.isExecutable)
            XCTAssertFalse(nonExistantFile.isReadable)
            XCTAssertFalse(nonExistantFile.isWritable)
            XCTAssertFalse(nonExistantFile.isDeletable)
            XCTAssertFalse(nonExistantFile.isDirectory)
            XCTAssertFalse(nonExistantFile.isFile)

            let baz = try tmpdir.baz.touch()
            XCTAssertTrue(baz.isDeletable)
            try tmpdir.chmod(0o500)  // remove write permission on directory
            XCTAssertFalse(baz.isDeletable)  // this is how deletion is prevented on UNIX
        }
    }

    func testTimes() throws {
        try Path.mktemp { tmpdir in
            let foo = try tmpdir.foo.touch()
            let now1 = Date().timeIntervalSince1970.rounded(.down)
        #if !os(Linux)
            XCTAssertEqual(foo.ctime?.timeIntervalSince1970.rounded(.down), now1)  //FIXME flakey
        #endif
            XCTAssertEqual(foo.mtime?.timeIntervalSince1970.rounded(.down), now1)  //FIXME flakey
            sleep(1)
            try foo.touch()
            let now2 = Date().timeIntervalSince1970.rounded(.down)
            XCTAssertNotEqual(now1, now2)
            XCTAssertEqual(foo.mtime?.timeIntervalSince1970.rounded(.down), now2)  //FIXME flakey
        }
    }

    func testDelete() throws {
        try Path.mktemp { tmpdir in
            try tmpdir.bar1.delete()
            try tmpdir.bar2.touch().delete()
            try tmpdir.bar3.touch().chmod(0o000).delete()
        #if !os(Linux)
            XCTAssertThrowsError(try tmpdir.bar3.touch().lock().delete())
        #endif
        }
    }

    func testRelativeCodable() throws {
        let path = Path.home.foo
        let encoder = JSONEncoder()
        encoder.userInfo[.relativePath] = Path.home
        let data = try encoder.encode([path])
        let decoder = JSONDecoder()
        decoder.userInfo[.relativePath] = Path.home
        XCTAssertEqual(try decoder.decode([Path].self, from: data), [path])
        decoder.userInfo[.relativePath] = Path.documents
        XCTAssertEqual(try decoder.decode([Path].self, from: data), [Path.documents.foo])
        XCTAssertThrowsError(try JSONDecoder().decode([Path].self, from: data))
    }

    func testBundleExtensions() {
        XCTAssertTrue(Bundle.main.path.isDirectory)
        XCTAssertTrue(Bundle.main.resources.isDirectory)

        // don’t exist in tests
        _ = Bundle.main.path(forResource: "foo", ofType: "bar")
        _ = Bundle.main.sharedFrameworks
    }

    func testDataExentsions() throws {
        let data = try Data(contentsOf: Path(#file)!)
        try Path.mktemp { tmpdir in
            _ = try data.write(to: tmpdir.foo)
        }
    }

    func testStringExentsions() throws {
        let string = try String(contentsOf: Path(#file)!)
        try Path.mktemp { tmpdir in
            _ = try string.write(to: tmpdir.foo)
        }
    }

    func testFileHandleExtensions() throws {
        _ = try FileHandle(forReadingAt: Path(#file)!)
        _ = try FileHandle(forWritingAt: Path(#file)!)
        _ = try FileHandle(forUpdatingAt: Path(#file)!)
    }
}
