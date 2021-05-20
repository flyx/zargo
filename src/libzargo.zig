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

export fn zargo_engine_fill_unit(e: ?*zargo.Engine, t: zargo.Transform, color: *[4]u8, copy_alpha: bool) void {
  if (e) |engine| {
    engine.fillUnit(t, color.*, copy_alpha);
  } else unreachable;
}

export fn zargo_engine_fill_rect(e: ?*zargo.Engine, r: CRectangle, color: *[4]u8, copy_alpha: bool) void {
  if (e) |engine| {
    engine.fillRect(CRectangle.from(r), color.*, copy_alpha);
  } else unreachable;
}

export fn zargo_engine_load_image(e: ?*zargo.Engine, path: [*:0]u8) zargo.Image {
  if (e) |engine| {
    return engine.loadImage(std.mem.span(path));
  } else unreachable;
}

export fn zargo_engine_draw_image(e: ?*zargo.Engine, i: zargo.Image, dst_transform: zargo.Transform, src_transform: zargo.Transform, alpha: u8) void {
  if (e) |engine| {
    engine.drawImage(i, dst_transform, src_transform, alpha);
  } else unreachable;
}

export fn zargo_transform_identity() zargo.Transform {
  return zargo.Transform.identity();
}

export fn zargo_transform_translate(t: zargo.Transform, x: f32, y: f32) zargo.Transform {
  return t.translate(x, y);
}

export fn zargo_transform_rotate(t: zargo.Transform, angle: f32) zargo.Transform {
  return t.rotate(angle);
}

export fn zargo_transform_scale(t: zargo.Transform, x: f32, y: f32) zargo.Transform {
  return t.scale(x, y);
}

export fn zargo_transform_compose(t1: zargo.Transform, t2: zargo.Transform) zargo.Transform {
  return t1.compose(t2);
}

const CRectangle = extern struct {
  x: i32, y: i32, width: u32, height: u32,

  fn to(r: zargo.Rectangle) CRectangle {
    var ret: CRectangle = undefined;
    inline for(std.meta.fields(CRectangle)) |fld| {
      @field(ret, fld.name) = @field(r, fld.name);
    }
    return ret;
  }

  fn from(r: CRectangle) zargo.Rectangle {
    var ret: zargo.Rectangle = undefined;
    inline for(std.meta.fields(zargo.Rectangle)) |fld| {
      @field(ret, fld.name) = @intCast(fld.field_type, @field(r, fld.name));
    }
    return ret;
  }
};

export fn zargo_rectangle_translation(r: CRectangle) zargo.Transform {
  return CRectangle.from(r).translation();
}

export fn zargo_rectangle_transformation(r: CRectangle) zargo.Transform {
  return CRectangle.from(r).transformation();
}

export fn zargo_rectangle_move(r: CRectangle, dx: i32, dy: i32) CRectangle {
  return CRectangle.to(CRectangle.from(r).move(dx, dy));
}

export fn zargo_rectangle_grow(r: CRectangle, dw: i32, dh: i32) CRectangle {
  return CRectangle.to(CRectangle.from(r).grow(dw, dh));
}

export fn zargo_rectangle_scale(r: CRectangle, factorX: f32, factorY: f32) CRectangle {
  return CRectangle.to(CRectangle.from(r).scale(factorX, factorY));
}

export fn zargo_rectangle_position(r: CRectangle, width: u32, height: u32, horiz: zargo.Rectangle.HAlign, vert: zargo.Rectangle.VAlign) CRectangle {
  return CRectangle.to(CRectangle.from(r).position(@intCast(u31, width), @intCast(u31, height), horiz, vert));
}

export fn zargo_image_empty() zargo.Image {
  return zargo.Image.empty();
}

export fn zargo_image_is_empty(i: zargo.Image) bool {
  return i.isEmpty();
}

export fn zargo_image_area(i: zargo.Image) CRectangle {
  return CRectangle.to(i.area());
}

export fn zargo_image_draw(i: zargo.Image, e: ?*zargo.Engine, dst_area: CRectangle, src_area: CRectangle, alpha: u8) void {
  if (e) |engine| {
    i.draw(engine, CRectangle.from(dst_area), CRectangle.from(src_area), alpha);
  } else unreachable;
}

export fn zargo_image_draw_all(i: zargo.Image, e: ?*zargo.Engine, dst_area: CRectangle, alpha: u8) void {
  if (e) |engine| {
    i.drawAll(engine, CRectangle.from(dst_area), alpha);
  } else unreachable;
}

export fn zargo_canvas_create(e: ?*zargo.Engine, width: usize, height: usize, with_alpha: bool) zargo.Canvas {
  if (e) |engine| {
    return engine.createCanvas(width, height, with_alpha) catch zargo.Canvas{
      .e = engine,
      .previous_framebuffer = .invalid,
      .framebuffer = .invalid,
      .target_image = zargo.Image.empty(),
      .alpha = false,
      .prev_width = 0,
      .prev_height = 0,
    };
  } else unreachable;
}

export fn zargo_canvas_rectangle(c: ?*zargo.Canvas) CRectangle {
  if (c) |canvas| {
    return CRectangle.to(canvas.rectangle());
  } else unreachable;
}

export fn zargo_canvas_finish(c: ?*zargo.Canvas) zargo.Image {
  if (c) |canvas| {
    return canvas.finish() catch zargo.Image.empty();
  } else unreachable;
}

export fn zargo_canvas_close(c: ?*zargo.Canvas) void {
  if (c) |canvas| {
    canvas.close();
  } else unreachable;
}

