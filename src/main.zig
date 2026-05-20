const std = @import("std");
const net = std.net;
const http = std.http;

// ── In-memory store ──────────────────────────────────────────────────────────

const MAX_URLS = 10_000;
const CODE_LEN = 6;

const Entry = struct {
    code: [CODE_LEN]u8,
    url: [2048]u8,
    url_len: usize,
    hits: u64,
};

var entries: [MAX_URLS]Entry = undefined;
var entry_count: usize = 0;
var total_redirects: u64 = 0;
var entries_mutex = std.Thread.Mutex{};

// ── Random code generator ────────────────────────────────────────────────────

const CHARSET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

fn generateCode(out: *[CODE_LEN]u8) void {
    var rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    const rand = rng.random();
    for (out) |*c| {
        c.* = CHARSET[rand.intRangeAtMost(u8, 0, CHARSET.len - 1)];
    }
}

fn findByCode(code: []const u8) ?*Entry {
    for (entries[0..entry_count]) |*e| {
        if (std.mem.eql(u8, e.code[0..CODE_LEN], code)) return e;
    }
    return null;
}

// ── HTML templates ───────────────────────────────────────────────────────────

const INDEX_HTML = @embedFile("../static/index.html");

fn statsHtml(buf: []u8) ![]u8 {
    entries_mutex.lock();
    defer entries_mutex.unlock();
    return std.fmt.bufPrint(buf,
        \\<div class="stats">
        \\  <span>🔗 <strong>{d}</strong> links created</span>
        \\  <span>🚀 <strong>{d}</strong> total redirects</span>
        \\</div>
    , .{ entry_count, total_redirects });
}

fn shortenHtml(buf: []u8, code: []const u8, host: []const u8) ![]u8 {
    return std.fmt.bufPrint(buf,
        \\<div class="result">
        \\  <p class="label">Your short link:</p>
        \\  <div class="link-row">
        \\    <a class="short-link" href="http://{s}/{s}" target="_blank">http://{s}/{s}</a>
        \\    <button onclick="navigator.clipboard.writeText('http://{s}/{s}').then(()=>this.textContent='✅ Copied!').catch(()=>{{}})" class="copy-btn">📋 Copy</button>
        \\  </div>
        \\</div>
    , .{ host, code, host, code, host, code });
}

fn errorHtml(buf: []u8, msg: []const u8) ![]u8 {
    return std.fmt.bufPrint(buf,
        \\<div class="error">⚠️ {s}</div>
    , .{msg});
}

// ── Request body parser ──────────────────────────────────────────────────────

fn parseFormValue(body: []const u8, key: []const u8, out: []u8) ?[]u8 {
    var iter = std.mem.splitScalar(u8, body, '&');
    while (iter.next()) |pair| {
        const eq = std.mem.indexOfScalar(u8, pair, '=') orelse continue;
        const k = pair[0..eq];
        const v = pair[eq + 1 ..];
        if (std.mem.eql(u8, k, key)) {
            const len = @min(v.len, out.len);
            @memcpy(out[0..len], v[0..len]);
            return out[0..len];
        }
    }
    return null;
}

// URL-decode %XX and + → space
fn urlDecode(input: []const u8, out: []u8) []u8 {
    var i: usize = 0;
    var j: usize = 0;
    while (i < input.len and j < out.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            const hi = std.fmt.charToDigit(input[i + 1], 16) catch {
                out[j] = input[i];
                i += 1;
                j += 1;
                continue;
            };
            const lo = std.fmt.charToDigit(input[i + 2], 16) catch {
                out[j] = input[i];
                i += 1;
                j += 1;
                continue;
            };
            out[j] = @as(u8, hi * 16 + lo);
            i += 3;
            j += 1;
        } else if (input[i] == '+') {
            out[j] = ' ';
            i += 1;
            j += 1;
        } else {
            out[j] = input[i];
            i += 1;
            j += 1;
        }
    }
    return out[0..j];
}

// ── HTTP handler ─────────────────────────────────────────────────────────────

fn handleConnection(conn: net.Server.Connection, host_buf: []const u8) !void {
    defer conn.stream.close();

    var read_buf: [8192]u8 = undefined;
    var http_server = http.Server.init(conn, &read_buf);

    var req = http_server.receiveHead() catch return;

    const method = req.head.method;
    const target = req.head.target;

    // GET / → serve index
    if (method == .GET and std.mem.eql(u8, target, "/")) {
        try req.respond(INDEX_HTML, .{
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "text/html; charset=utf-8" },
            },
        });
        return;
    }

    // GET /stats → stats HTML fragment
    if (method == .GET and std.mem.eql(u8, target, "/stats")) {
        var buf: [512]u8 = undefined;
        const html = try statsHtml(&buf);
        try req.respond(html, .{
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "text/html" },
            },
        });
        return;
    }

    // POST /shorten → create short link
    if (method == .POST and std.mem.eql(u8, target, "/shorten")) {
        var body_buf: [4096]u8 = undefined;
        const body = try req.reader().readAll(&body_buf);

        var raw_url_buf: [2048]u8 = undefined;
        var decoded_buf: [2048]u8 = undefined;
        var out_buf: [2048]u8 = undefined;

        const raw = parseFormValue(body_buf[0..body], "url", &raw_url_buf) orelse {
            const html = try errorHtml(&out_buf, "No URL provided.");
            try req.respond(html, .{ .status = .bad_request });
            return;
        };

        const url = urlDecode(raw, &decoded_buf);

        if (url.len < 7 or (!std.mem.startsWith(u8, url, "http://") and !std.mem.startsWith(u8, url, "https://"))) {
            const html = try errorHtml(&out_buf, "Please enter a valid URL starting with http:// or https://");
            try req.respond(html, .{ .status = .bad_request, .extra_headers = &.{.{ .name = "Content-Type", .value = "text/html" }} });
            return;
        }

        entries_mutex.lock();
        if (entry_count >= MAX_URLS) {
            entries_mutex.unlock();
            const html = try errorHtml(&out_buf, "Server is full. Try again later.");
            try req.respond(html, .{ .status = .service_unavailable });
            return;
        }

        var code: [CODE_LEN]u8 = undefined;
        generateCode(&code);

        const idx = entry_count;
        entries[idx].code = code;
        entries[idx].url_len = @min(url.len, 2048);
        @memcpy(entries[idx].url[0..entries[idx].url_len], url[0..entries[idx].url_len]);
        entries[idx].hits = 0;
        entry_count += 1;
        entries_mutex.unlock();

        const html = try shortenHtml(&out_buf, &code, host_buf);
        try req.respond(html, .{
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "text/html" },
            },
        });
        return;
    }

    // GET /:code → redirect
    if (method == .GET and target.len > 1) {
        const code = target[1..];
        entries_mutex.lock();
        const entry = findByCode(code);
        if (entry) |e| {
            const url = e.url[0..e.url_len];
            e.hits += 1;
            total_redirects += 1;
            entries_mutex.unlock();

            var loc_buf: [2100]u8 = undefined;
            const location = try std.fmt.bufPrint(&loc_buf, "{s}", .{url});
            try req.respond("Redirecting...", .{
                .status = .found,
                .extra_headers = &.{
                    .{ .name = "Location", .value = location },
                },
            });
        } else {
            entries_mutex.unlock();
            try req.respond("<h2>404 — Short link not found.</h2>", .{
                .status = .not_found,
                .extra_headers = &.{.{ .name = "Content-Type", .value = "text/html" }},
            });
        }
        return;
    }

    try req.respond("Not Found", .{ .status = .not_found });
}

// ── Main ─────────────────────────────────────────────────────────────────────

pub fn main() !void {
    const port: u16 = blk: {
        const env = std.posix.getenv("PORT") orelse break :blk 8080;
        break :blk std.fmt.parseInt(u16, env, 10) catch 8080;
    };

    const host_env = std.posix.getenv("HOST") orelse "localhost:8080";
    var host_buf: [256]u8 = undefined;
    const host = try std.fmt.bufPrint(&host_buf, "{s}", .{host_env});

    const addr = try net.Address.resolveIp("0.0.0.0", port);
    var server = try addr.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.debug.print("⚡ Zig URL Shortener running on http://0.0.0.0:{d}\n", .{port});
    std.debug.print("   Set HOST env var to your public domain for correct short links\n", .{});

    while (true) {
        const conn = server.accept() catch continue;
        const thread = std.Thread.spawn(.{}, handleConnection, .{ conn, host }) catch continue;
        thread.detach();
    }
}
