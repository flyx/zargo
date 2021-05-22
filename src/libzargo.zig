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

export fn zargo_engine_area(e: ?*zargo.Engine, r: ?*zargo.CRectangle) void {
  if (e != null and r != null) {
    r.?.* = zargo.CEngineInterface.area(e.?);
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

export fn zargo_engine_fill_rect(e: ?*zargo.Engine, r: ?*zargo.CRectangle, color: *[4]u8, copy_alpha: bool) void {
  if (e != null and r != null) {
    zargo.CEngineInterface.fillRect(e.?, r.?.*, color.*, copy_alpha);
  } else unreachable;
}

export fn zargo_engine_blend_unit(e: ?*zargo.Engine, mask: ?*zargo.CImage, dst_transform: ?*zargo.Transform, src_transform: ?*zargo.Transform, color1: *[4]u8, color2: *[4]u8) void {
  if (e != null and mask != null) {
    var src = if (src_transform) |v| v.* else mask.?.area().transformation();
    var dst = if (dst_transform) |v| v.* else zargo.CEngineInterface.area(e.?).transformation();
    zargo.CEngineInterface.blendUnit(e.?, mask.?.*, dst, src, color1.*, color2.*);
  } else unreachable;
}

export fn zargo_engine_blend_rect(e: ?*zargo.Engine, mask: ?*zargo.CImage, dst_rect: ?*zargo.CRectangle, src_rect: ?*zargo.CRectangle, color1: *[4]u8, color2: *[4]u8) void {
  if (e != null and mask != null) {
    var src = if (src_rect) |v| v.* else mask.?.area();
    var dst = if (dst_rect) |v| v.* else zargo.CEngineInterface.area(e.?);
    zargo.CEngineInterface.blendRect(e.?, mask.?.*, dst, src, color1.*, color2.*);
  } else unreachable;
}

export fn zargo_engine_load_image(e: ?*zargo.Engine, i: ?*zargo.CImage, path: [*:0]u8) void {
  if (e) |engine| {
    if (i) |image| {
      image.* = zargo.CEngineInterface.loadImage(engine, std.mem.span(path));
    } else unreachable;
  } else unreachable;
}

export fn zargo_engine_draw_image(e: ?*zargo.Engine, i: ?*zargo.CImage, dst_transform: ?*zargo.Transform, src_transform: ?*zargo.Transform, alpha: u8) void {
  if (e != null and i != null) {
    var src = if (src_transform) |v| v.* else i.?.area().transformation();
    var dst = if (dst_transform) |v| v.* else zargo.CEngineInterface.area(e.?).transformation();
    zargo.CEngineInterface.drawImage(e.?, i.?.*, dst, src, alpha);
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

export fn zargo_rectangle_translation(in: ?*zargo.CRectangle, out: ?*zargo.Transform) void {
  if (in != null and out != null) {
    out.?.* = in.?.translation();
  } else unreachable;
}

export fn zargo_rectangle_transformation(in: ?*zargo.CRectangle, out: ?*zargo.Transform) void {
  if (in != null and out != null) {
    out.?.* = in.?.transformation();
  } else unreachable;
}

export fn zargo_rectangle_move(in: ?*zargo.CRectangle, out: ?*zargo.CRectangle, dx: i32, dy: i32) void {
  if (in) |r| {
    const res = r.move(dx, dy);
    (out orelse r).* = res;
  } else unreachable;
}

export fn zargo_rectangle_grow(in: ?*zargo.CRectangle, out: ?*zargo.CRectangle, dw: i32, dh: i32) void {
  if (in) |r| {
    const res = r.grow(dw, dh);
    (out orelse r).* = res;
  } else unreachable;
}

export fn zargo_rectangle_scale(in: ?*zargo.CRectangle, out: ?*zargo.CRectangle, factorX: f32, factorY: f32) void {
  if (in) |r| {
    const res = r.scale(factorX, factorY);
    (out orelse r).* = res;
  } else unreachable;
}

export fn zargo_rectangle_position(in: ?*zargo.CRectangle, out: ?*zargo.CRectangle, width: u32, height: u32, horiz: zargo.CRectangle.HAlign, vert: zargo.CRectangle.VAlign) void {
  if (in) |r| {
    const res = r.position(@intCast(u31, width), @intCast(u31, height), horiz, vert);
    (out orelse r).* = res;
  } else unreachable;
}

export fn zargo_image_empty(i: ?*zargo.CImage) void {
  if (i) |image| {
    image.* = zargo.CImage.empty();
  } else unreachable;
}

export fn zargo_image_is_empty(i: ?*zargo.CImage) bool {
  if (i) |image| {
    return image.isEmpty();
  } else unreachable;
}

export fn zargo_image_area(in: ?*zargo.Image, out: ?*zargo.CRectangle) void {
  if (in != null and out != null) {
    out.?.* = zargo.CRectangle.from(in.?.area());
  } else unreachable;
}

export fn zargo_image_draw(i: ?*zargo.CImage, e: ?*zargo.Engine, dst_area: ?*zargo.CRectangle, src_area: ?*zargo.CRectangle, alpha: u8) void {
  if (e != null and i != null) {
    var src = if (src_area) |v| v.* else i.?.area();
    var dst = if (dst_area) |v| v.* else zargo.CEngineInterface.area(e.?);
    i.?.draw(e.?, dst, src, alpha);
  } else unreachable;
}

export fn zargo_canvas_create(out: ?*zargo.CCanvas, e: ?*zargo.Engine, width: u32, height: u32, with_alpha: bool) void {
  if (e != null and out != null) {
    out.?.* = zargo.CCanvas.create(e.?, width, height, with_alpha) catch zargo.CCanvas{
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

export fn zargo_canvas_rectangle(c: ?*zargo.CCanvas, out: ?*zargo.CRectangle) void {
  if (c != null and out != null) {
    out.?.* = c.?.rectangle();
  } else unreachable;
}

export fn zargo_canvas_finish(c: ?*zargo.CCanvas, out: ?*zargo.CImage) void {
  if (c != null and out != null) {
    out.?.* = c.?.finish() catch zargo.CImage.empty();
  } else unreachable;
}

export fn zargo_canvas_close(c: ?*zargo.CCanvas) void {
  if (c) |canvas| {
    canvas.close();
  } else unreachable;
}