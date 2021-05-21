const std = @import("std");
const zargo = @import("zargo.zig");

export fn zargo_engine_init(backend: zargo.Backend, window_width: u32, window_height: u32, debug: bool) ?*zargo.Engine {
  var e = std.heap.c_allocator.create(zargo.Engine) catch return null;
  errdefer std.heap.c_allocator.free(e);
  e.init(backend, window_width, window_height, debug) catch return null;
  return e;
}

export fn zargo_engine_set_window_size(e: ?*zargo.Engine, width: u32, height: u32) void {
  if (e) |engine| {
    engine.setWindowSize(width, height);
  } else unreachable;
}

export fn zargo_engine_area(e: ?*zargo.Engine, r: ?*CRectangle) void {
  if (e != null and r != null) {
    r.?.* = CRectangle.to(e.?.area());
  } else unreachable;
}

export fn zargo_engine_clear(e: ?*zargo.Engine, color: *[4]u8) void {
  if (e) |engine| {
    engine.clear(color.*);
  } else unreachable;
}

export fn zargo_engine_close(e: ?*zargo.Engine) void {
  if (e) |engine| {
    engine.close();
    std.heap.c_allocator.destroy(engine);
  } else unreachable;
}

export fn zargo_engine_fill_unit(e: ?*zargo.Engine, t: ?*zargo.Transform, color: *[4]u8, copy_alpha: bool) void {
  if (e != null and t != null) {
    e.?.fillUnit(t.?.*, color.*, copy_alpha);
  } else unreachable;
}

export fn zargo_engine_fill_rect(e: ?*zargo.Engine, r: ?*CRectangle, color: *[4]u8, copy_alpha: bool) void {
  if (e != null and r != null) {
    e.?.fillRect(CRectangle.from(r.?.*), color.*, copy_alpha);
  } else unreachable;
}

export fn zargo_engine_load_image(e: ?*zargo.Engine, i: ?*zargo.Image, path: [*:0]u8) void {
  if (e) |engine| {
    if (i) |image| {
      image.* = engine.loadImage(std.mem.span(path));
    } else unreachable;
  } else unreachable;
}

export fn zargo_engine_draw_image(e: ?*zargo.Engine, i: ?*zargo.Image, dst_transform: ?*zargo.Transform, src_transform: ?*zargo.Transform, alpha: u8) void {
  if (e != null and i != null and dst_transform != null and src_transform != null) {
    e.?.drawImage(i.?.*, dst_transform.?.*, src_transform.?.*, alpha);
  } else unreachable;
}

export fn zargo_transform_identity(t: ?*zargo.Transform) void {
  if (t) |transform| {
    transform.* = zargo.Transform.identity();
  } else unreachable;
}

export fn zargo_transform_translate(in: ?*zargo.Transform, out: ?*zargo.Transform, dx: f32, dy: f32) void {
  if (in) |t| {
    (out orelse t).* = t.translate(dx, dy);
  } else unreachable;
}

export fn zargo_transform_rotate(in: ?*zargo.Transform, out: ?*zargo.Transform, angle: f32) void {
  if (in) |t| {
    const res = t.rotate(angle);
    (out orelse t).* = res;
  } else unreachable;
}

export fn zargo_transform_scale(in: ?*zargo.Transform, out: ?*zargo.Transform, factorX: f32, factorY: f32) void {
  if (in) |t| {
    (out orelse t).* = t.scale(factorX, factorY);
  } else unreachable;
}

export fn zargo_transform_compose(l: ?*zargo.Transform, r: ?*zargo.Transform, out: ?*zargo.Transform) void {
  if (l != null and r != null and out != null) {
    const res = l.?.compose(r.?.*);
    out.?.* = res;
  } else unreachable;
}

const CRectangle = extern struct {
  x: i32, y: i32, width: u32, height: u32,

  fn to(r: zargo.Rectangle) callconv(.Inline) CRectangle {
    var ret: CRectangle = undefined;
    inline for(std.meta.fields(CRectangle)) |fld| {
      @field(ret, fld.name) = @field(r, fld.name);
    }
    return ret;
  }

  fn from(r: CRectangle) callconv(.Inline) zargo.Rectangle {
    var ret: zargo.Rectangle = undefined;
    inline for(std.meta.fields(zargo.Rectangle)) |fld| {
      @field(ret, fld.name) = @intCast(fld.field_type, @field(r, fld.name));
    }
    return ret;
  }
};

export fn zargo_rectangle_translation(in: ?*CRectangle, out: ?*zargo.Transform) void {
  if (in != null and out != null) {
    out.?.* = CRectangle.from(in.?.*).translation();
  } else unreachable;
}

export fn zargo_rectangle_transformation(in: ?*CRectangle, out: ?*zargo.Transform) void {
  if (in != null and out != null) {
    out.?.* = CRectangle.from(in.?.*).transformation();
  } else unreachable;
}

export fn zargo_rectangle_move(in: ?*CRectangle, out: ?*CRectangle, dx: i32, dy: i32) void {
  if (in) |r| {
    const res = CRectangle.to(CRectangle.from(r.*).move(dx, dy));
    (out orelse r).* = res;
  } else unreachable;
}

export fn zargo_rectangle_grow(in: ?*CRectangle, out: ?*CRectangle, dw: i32, dh: i32) void {
  if (in) |r| {
    const res = CRectangle.to(CRectangle.from(r.*).grow(dw, dh));
    (out orelse r).* = res;
  } else unreachable;
}

export fn zargo_rectangle_scale(in: ?*CRectangle, out: ?*CRectangle, factorX: f32, factorY: f32) void {
  if (in) |r| {
    const res = CRectangle.to(CRectangle.from(r.*).scale(factorX, factorY));
    (out orelse r).* = res;
  } else unreachable;
}

export fn zargo_rectangle_position(in: ?*CRectangle, out: ?*CRectangle, width: u32, height: u32, horiz: zargo.Rectangle.HAlign, vert: zargo.Rectangle.VAlign) void {
  if (in) |r| {
    const res = CRectangle.to(CRectangle.from(r.*).position(@intCast(u31, width), @intCast(u31, height), horiz, vert));
    (out orelse r).* = res;
  } else unreachable;
}

export fn zargo_image_empty(i: ?*zargo.Image) void {
  if (i) |image| {
    image.* = zargo.Image.empty();
  } else unreachable;
}

export fn zargo_image_is_empty(i: ?*zargo.Image) bool {
  if (i) |image| {
    return image.isEmpty();
  } else unreachable;
}

export fn zargo_image_area(in: ?*zargo.Image, out: ?*CRectangle) void {
  if (in != null and out != null) {
    out.?.* = CRectangle.to(in.?.area());
  } else unreachable;
}

export fn zargo_image_draw(i: ?*zargo.Image, e: ?*zargo.Engine, dst_area: ?*CRectangle, src_area: ?*CRectangle, alpha: u8) void {
  if (e != null and i != null) {
    var src = if (src_area) |v| CRectangle.from(v.*) else i.?.area();
    var dst = if (dst_area) |v| CRectangle.from(v.*) else e.?.area();
    i.?.draw(e.?, dst, src, alpha);
  } else unreachable;
}

export fn zargo_canvas_create(out: ?*zargo.Canvas, e: ?*zargo.Engine, width: usize, height: usize, with_alpha: bool) void {
  if (e != null and out != null) {
    out.?.* = e.?.createCanvas(width, height, with_alpha) catch zargo.Canvas{
      .e = e.?,
      .previous_framebuffer = .invalid,
      .framebuffer = .invalid,
      .target_image = zargo.Image.empty(),
      .alpha = false,
      .prev_width = 0,
      .prev_height = 0,
    };
  } else unreachable;
}

export fn zargo_canvas_rectangle(c: ?*zargo.Canvas, out: ?*CRectangle) void {
  if (c != null and out != null) {
    out.?.* = CRectangle.to(c.?.rectangle());
  } else unreachable;
}

export fn zargo_canvas_finish(c: ?*zargo.Canvas, out: ?*zargo.Image) void {
  if (c != null and out != null) {
    out.?.* = c.?.finish() catch zargo.Image.empty();
  } else unreachable;
}

export fn zargo_canvas_close(c: ?*zargo.Canvas) void {
  if (c) |canvas| {
    canvas.close();
  } else unreachable;
}

