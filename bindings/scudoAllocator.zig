//! implementation for Zig using the Scudo allocator.
//! Unofficial docs: http://web.archive.org/web/20230922193604/https://trenchant.io/scudo-hardened-allocator-unofficial-internals-documentation/

const std = @import("std");
const builtin = @import("builtin");

pub const ScudoAllocator = struct {
    pub fn init(allocation_type: allocationType) ScudoAllocator {
        return .{
            .alloc = allocation_type,
        };
    }
    pub fn allocator(self: *ScudoAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = switch (self.alloc) {
                    .valloc => m_alloc,
                    .malloc => v_alloc,
                    .pvalloc => pv_alloc,
                },
                .resize = resize,
                .free = free,
            },
        };
    }

    fn m_alloc(_: *anyopaque, len: usize, log2_ptr_align: u8, _: usize) ?[*]u8 {
        std.debug.assert(log2_ptr_align <= comptime std.math.log2_int(
            usize,
            @alignOf(std.c.max_align_t),
        ));
        return @as(?[*]u8, @ptrCast(std.c.malloc(len)));
    }
    fn v_alloc(_: *anyopaque, len: usize, log2_ptr_align: u8, _: usize) ?[*]u8 {
        std.debug.assert(log2_ptr_align <= comptime std.math.log2_int(
            usize,
            @alignOf(std.c.max_align_t),
        ));
        return @as(?[*]u8, @ptrCast(valloc(len)));
    }
    fn pv_alloc(_: *anyopaque, len: usize, log2_ptr_align: u8, _: usize) ?[*]u8 {
        std.debug.assert(log2_ptr_align <= comptime std.math.log2_int(
            usize,
            @alignOf(std.c.max_align_t),
        ));
        return @as(?[*]u8, @ptrCast(pvalloc(len)));
    }

    fn resize(ctx: *anyopaque, buf: []u8, _: u8, new_len: usize, _: usize) bool {
        if (new_len <= buf.len)
            return true;

        const full_len = if (@TypeOf(malloc_usable_size) != void)
            malloc_usable_size(ctx);
        if (new_len <= full_len) return true;

        return false;
    }

    fn free(_: *anyopaque, buf: []u8, _: u8, _: usize) void {
        std.c.free(buf.ptr);
    }

    alloc: allocationType = .valloc,
};

const allocationType = enum {
    malloc,
    valloc,
    pvalloc,
};

const __scudo_mallinfo_data_t = if (builtin.abi == .android) usize else u32;

const __scudo_mallinfo = struct {
    arena: __scudo_mallinfo_data_t,
    ordblks: __scudo_mallinfo_data_t,
    smblks: __scudo_mallinfo_data_t,
    hblks: __scudo_mallinfo_data_t,
    hblkhd: __scudo_mallinfo_data_t,
    usmblks: __scudo_mallinfo_data_t,
    fsmblks: __scudo_mallinfo_data_t,
    uordblks: __scudo_mallinfo_data_t,
    fordblks: __scudo_mallinfo_data_t,
    keepcost: __scudo_mallinfo_data_t,
};

const __scudo_mallinfo2 = struct {
    arena: usize,
    ordblks: usize,
    smblks: usize,
    hblks: usize,
    hblkhd: usize,
    usmblks: usize,
    fsmblks: usize,
    uordblks: usize,
    fordblks: usize,
    keepcost: usize,
};

pub extern fn malloc_postinit() void;
pub extern fn malloc_enable() void;
pub extern fn malloc_disable() void;
pub extern fn malloc_disable_memory_tagging() void;
pub extern fn malloc_set_track_allocation_stacks(track: c_int) void;
pub extern fn malloc_set_zero_contents(zero_contents: c_int) void;
pub extern fn malloc_set_pattern_fill_contents(pattern_fill_contents: c_int) void;
pub extern fn malloc_set_add_large_allocation_slack(add_slack: c_int) void;
pub extern fn malloc_iterate(base: usize, size: usize, callback: ?*const fn (usize, usize, ?*anyopaque) callconv(.C) void, arg: ?*anyopaque) c_int;
pub extern fn pvalloc(size: usize) ?*anyopaque;
pub extern fn valloc(size: usize) ?*anyopaque;
pub extern fn calloc(nmemb: usize, size: usize) ?*anyopaque;
pub extern fn realloc(ptr: ?*anyopaque, size: usize) ?*anyopaque;
pub extern fn malloc_usable_size(ptr: ?*anyopaque) usize;
pub extern fn mallopt(param: i32, value: i32) c_int;
pub extern fn memalign(alignment: usize, size: usize) ?*anyopaque;
pub extern fn aligned_alloc(alignment: usize, size: usize) ?*anyopaque;
pub extern fn malloc_info(options: c_int, stream: *std.c.FILE) c_int;
pub extern fn posix_memalign(memptr: **anyopaque, alignment: usize, size: usize) c_int;
pub extern fn mallinfo() __scudo_mallinfo;
pub extern fn mallinfo2() __scudo_mallinfo2;

test "allocation" {
    {
        var scudo = ScudoAllocator.init(.valloc);
        const buf = try scudo.allocator().alloc(u8, 10);
        try std.testing.expect(buf.len == 10);
    }
    {
        var scudo = ScudoAllocator.init(.malloc);
        const buf = try scudo.allocator().alloc(u8, 10);
        try std.testing.expect(buf.len == 10);
    }
    {
        var scudo = ScudoAllocator.init(.pvalloc);
        const buf = try scudo.allocator().alloc(u8, 10);
        try std.testing.expect(buf.len == 10);
    }
}

test "Arena" {
    {
        var scudo_v = ScudoAllocator.init(.valloc);
        const arena_v = std.heap.ArenaAllocator.init(scudo_v.allocator());
        defer arena_v.deinit();
    }
    {
        var scudo_m = ScudoAllocator.init(.malloc);
        const arena_m = std.heap.ArenaAllocator.init(scudo_m.allocator());
        defer arena_m.deinit();
    }
    {
        var scudo_pv = ScudoAllocator.init(.pvalloc);
        const arena_pv = std.heap.ArenaAllocator.init(scudo_pv.allocator());
        defer arena_pv.deinit();
    }
}
