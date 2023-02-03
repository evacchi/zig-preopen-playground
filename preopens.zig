const std = @import("std");
const io = std.io;
const os = std.os;
const allocator = std.heap.page_allocator;
const warn = std.log.warn;
const preopensAlloc = std.fs.wasi.preopensAlloc;
const stdout = std.io.getStdOut().writer();
const File = std.fs.File;
const testing = std.testing;

fn prefixMatches(prefix: []const u8, path: []const u8) bool {
    if (path[0] != '/' and prefix.len == 0)
        return true;

    if (path.len < prefix.len)
        return false;

    if (prefix.len == 1) {
        return prefix[0] == path[0];        
    }

    if (!std.mem.eql(u8, path[0..prefix.len], prefix)) {
        return false;
    }

    return path.len == prefix.len or 
           path[prefix.len] == '/';
}

pub fn findFile(p: std.fs.wasi.Preopens, full_path: []const u8, flags: File.OpenFlags) std.fs.File.OpenError!std.fs.File {
    var prefix: []const u8 = "";
    var fd: usize = 0;
    for (p.names) |preopen, i| {
        if (i > 2 and prefixMatches(preopen, full_path)) {
            if (preopen.len > prefix.len) {
                prefix = preopen;
                fd=i;
            }
        }
    }
    const d = std.fs.Dir{ .fd = @intCast(os.fd_t, fd) };
    const rel = full_path[prefix.len..full_path.len];
    return d.openFile(rel, flags);
}


test "prefix=/" {
    try testing.expect(prefixMatches("/", "/foo"));
}

test "prefix=/testcases, path=/testcases/test.txt" {
    try testing.expect(prefixMatches("/testcases", "/testcases/test.txt"));
}


test "empty prefix" {
    try testing.expect(prefixMatches("", "foo"));
}

test "equal prefix" {
    try testing.expect(prefixMatches("foo", "foo"));
}

test "sub path" {
    try testing.expect(prefixMatches("foo", "foo/bar"));
}

test "different sub path" {
    try testing.expect(!prefixMatches("bar", "foo/bar"));
}

test "different path same length" {
    try testing.expect(!prefixMatches("bar", "foo"));
}

test "longer path" { 
    try testing.expect(prefixMatches("foo", "foo/bar"));
}

test "path is shorter" { 
    try testing.expect(!prefixMatches("fooo", "foo"));
}

test "path is longer" {
    try testing.expect(!prefixMatches("foo", "fooo"));
}

test "prefix starts with path" { 
    try testing.expect(!prefixMatches("foo/bar", "foo"));
}

test "prefix ends with path" { 
    try testing.expect(!prefixMatches("bar/foo", "foo"));
}

test "equal prefix leading /" {
    try testing.expect(prefixMatches("/foo", "/foo"));
}

test "prefix_matches /foo /foo/" {
    try testing.expect(prefixMatches("/foo", "/foo"));
}

test "prefix_matches /foo /foo/bar" {
    try testing.expect(prefixMatches("/foo", "/foo/"));
}

// assume the test runtime was started with mount / and /tmp
// with contents:
// /    -> { "tmp/a" = "1" }
// /tmp -> { "a" = "2" } 

test "preopens: /a ($ROOT/001/tmp/a) = 1" {
    
    var wasi_preopens = try preopensAlloc(allocator);

    const path = "/a";
    const file = try findFile(wasi_preopens, path, .{ .mode = .read_only });
    defer file.close();

    const b = try file.reader().readByte();
    try testing.expect(b == '1');
}

test "preopens /tmp/a ($ROOT/001/tmp/a) = 2" {
    
    var wasi_preopens = try preopensAlloc(allocator);

    const path = "/tmp/a";
    const file = try findFile(wasi_preopens, path, .{ .mode = .read_only });
    defer file.close();

    const b = try file.reader().readByte();
    try testing.expect(b == '2');
}


test "preopens /tmp2 FileNotFound" {
    var wasi_preopens = try preopensAlloc(allocator);

    const path = "/tmp2";
    try testing.expectError(File.OpenError.FileNotFound, findFile(wasi_preopens, path, .{ .mode = .read_only }));
}


