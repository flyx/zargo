const std = @import("std");

//////////////////////////////////////////////////////////////////////////////
// Transforms

/// Transform is a 2D affine transformation matrix.
/// It is the low level interface for positioning, scaling and rotating things.
pub const Transform = extern struct {
  m: [3][2]f32,

  /// identity returns the identity matrix.
  pub fn identity() Transform {
    return Transform{.m = .{.{1, 0}, .{0, 1}, .{0, 0}}};
  }

  /// translate adds translation to the given matrix according to the given x
  /// and y values.
  pub fn translate(t: Transform, dx: f32, dy: f32) Transform {
    return Transform{.m = .{
        t.m[0], t.m[1], .{
          t.m[0][0]*dx + t.m[1][0]*dy + t.m[2][0],
          t.m[0][1]*dx + t.m[1][1]*dy + t.m[2][1]
        }
    }};
  }

  /// rotate adds counter-clockwise rotation by the given angle (in radians)
  // to the matrix.
  pub fn rotate(t: Transform, angle: f32) Transform {
    var sin = std.math.sin(angle);
    var cos = std.math.cos(angle);
    return Transform{.m = .{
        .{cos*t.m[0][0] + sin*t.m[1][0], cos*t.m[0][1] + sin*t.m[1][1]},
        .{cos*t.m[1][0] - sin*t.m[0][0], cos*t.m[1][1] - sin*t.m[0][1]},
        t.m[2]
    }};
  }

  /// scale adds scaling to the given matrix, with the scaling factors for x and
  /// y direction given separately.
  pub fn scale(t: Transform, x: f32, y: f32) Transform {
    return Transform{.m = .{
      .{t.m[0][0] * x, t.m[0][1] * x},
      .{t.m[1][0] * y, t.m[1][1] * y},
      t.m[2]
    }};
  }

  /// compose multiplies the two given matrixes.
  pub fn compose(t1: Transform, t2: Transform) Transform {
    return Transform{.m = .{
      .{t2.m[0][0] * t1.m[0][0] + t2.m[0][1] * t1.m[1][0],              t2.m[0][0] * t1.m[0][1] + t2.m[0][1] * t1.m[1][1]},
      .{t2.m[1][0] * t1.m[0][0] + t2.m[1][1] * t1.m[1][0],              t2.m[1][0] * t1.m[0][1] + t2.m[1][1] * t1.m[1][1]},
      .{t2.m[2][0] * t1.m[0][0] + t2.m[2][1] * t1.m[1][0] + t1.m[2][0], t2.m[2][0] * t1.m[0][1] + t2.m[2][1] * t1.m[1][1] + t1.m[2][1]},
    }};
  }
};

//////////////////////////////////////////////////////////////////////////////
// Rectangles

fn RectangleImpl(comptime Self: type) type {
  return struct {
    /// translation returns a translation matrix that will translate the point
    /// (0,0) to the current center of the rectangle.
    pub fn translation(r: Self) Transform {
      return Transform.identity().translate(@intToFloat(f32, r.x) + @intToFloat(f32, r.width) / 2.0,
          @intToFloat(f32, r.y) + @intToFloat(f32, r.height) / 2.0);
    }

    /// transformation returns a transformation matrix that will transform a unit
    /// square at ((-0.5,-0.5), (0.5,-0.5), (0.5, 0.5), (-0.5, 0.5)) into the
    /// given rectangle.
    pub fn transformation(r: Self) Transform {
      return r.translation().scale(@intToFloat(f32, r.width), @intToFloat(f32, r.height));
    }

    /// move modifies the rectangle's position by the given dx and dy values.
    pub fn move(r: Self, dx: i32, dy: i32) Self {
      return Self{.x = r.x + dx, .y = r.y + dy, .width = r.width, .height = r.height};
    }

    /// grows the rectangle by the given dw and dh values,
    /// keeping its center point (i.e. dw and dh will be evenly distributed to
    /// the four edges).
    /// use negative values to shrink.
    pub fn grow(r: Self, dw: i32, dh: i32) Self {
      return Self{.x = r.x + @divTrunc(dw, 2), .y = r.y + @divTrunc(dh, 2), .width = @intCast(u31, @intCast(u31, r.width) - dw), .height = @intCast(u31, @intCast(u31, r.height) - dh)};
    }

    /// scale will scale the rectangle by the given factors.
    pub fn scale(r: Self, factorX: f32, factorY: f32) Self {
      var ret = Self{.x = undefined, .y = undefined,
        .width = @floatToInt(u31, @intToFloat(f32, r.width) * factorX),
        .height = @floatToInt(u31, @intToFloat(f32, r.height) * factorY)};
      ret.x = r.x + @intCast(i32, @divTrunc(r.width - ret.width, 2));
      ret.y = r.y + @intCast(i32, @divTrunc(r.height - ret.height, 2));
      return ret;
    }

    /// HAlign describse horizontal alignment.
    pub const HAlign = enum(c_int) {
      left, center, right
    };

    /// VAlign describes vertical alignment.
    pub const VAlign = enum(c_int) {
      top, middle, bottom
    };

    /// position takes a width and a height, and positions a rectangle with these
    /// dimensions inside the given rectangle.
    /// Horizontal and vertical alignment can be given with horiz and vert.
    pub fn position(r: Self, width: u31, height: u31, horiz: HAlign, vert: VAlign) Self {
      return Self{
        .x = switch (horiz) {
          .left    => r.x,
          .center  => r.x + @rem(@intCast(u31, r.width) - width, 2),
          .right   => r.x + @intCast(u31, r.width) - width
        },
        .y = switch (vert) {
          .top    => r.y + @intCast(u31, r.height) - height,
          .middle => r.y + @rem(@intCast(u31, r.height) - height, 2),
          .bottom => r.y
        },
        .width = width,
        .height = height
      };
    }
  };
}

/// A Rectangle represents a rectangular area with given size and offset.
/// This is the high-level API for positioning.
pub const Rectangle = struct {
  x: i32, y: i32, width: u31, height: u31,

  usingnamespace RectangleImpl(@This());

  pub fn from(r: CRectangle) Rectangle {
    var ret: Rectangle = undefined;
    inline for(std.meta.fields(Rectangle)) |fld| {
      @field(ret, fld.name) = @intCast(fld.field_type, @field(r, fld.name));
    }
    return ret;
  }
};

pub const CRectangle = extern struct {
  x: i32, y: i32, width: u32, height: u32,

  usingnamespace RectangleImpl(@This());

  pub fn from(r: Rectangle) CRectangle {
    var ret: CRectangle = undefined;
    inline for(std.meta.fields(CRectangle)) |fld| {
      @field(ret, fld.name) = @field(r, fld.name);
    }
    return ret;
  }
};

//////////////////////////////////////////////////////////////////////////////
// Images

fn ImageImpl(comptime Self: type, comptime RectImpl: type) type {
  return struct {
    /// empty returns an empty image, which is not linked to a GPU texture.
    pub fn empty() Self {
      return Self{
        .id = .invalid, .width = 0, .height = 0, .flipped = false, .has_alpha = false
      };
    }

    /// isEmpty returns true iff the given image is linked to a GPU texture.
    pub fn isEmpty(i: Self) bool {
      return i.width == 0;
    }

    /// area returns a rectangle with lower left corner at (0,0) that has the
    /// image's width and height.
    pub fn area(i: Self) RectImpl {
      return RectImpl{.x = 0, .y = 0, .width = @intCast(u31, i.width), .height = @intCast(u31, i.height)};
    }

    pub fn free(i: *Self) void {
      i.id.delete();
      i.* = empty();
    }
  };
}

/// Image is an image in GPU memory, i.e. a texture.
/// Images must be explicitly free'd using free().
/// Images can be created via the engine, you cannot load an image into GPU
/// memory before initializing the engine.
pub const Image = struct {
  id: gl.Texture,
  width: u31,
  height: u31,
  flipped: bool,
  has_alpha: bool,

  usingnamespace ImageImpl(@This(), Rectangle);

  /// draw draws the given image with the given engine.
  /// dst_area is the rectangle to draw into.
  /// src_area is the rectangle to draw from ??? give i.area() to draw the whole
  /// image.
  /// alpha defines the opacity of the image, with 255 being fully opaque and
  /// 0 being fully transparent (i.e. invisible).
  /// alpha is applied on top of the image's alpha channel, if it has one.
  pub fn draw(i: Image, e: *Engine, dst_area: Rectangle, src_area: Rectangle, alpha: u8) void {
    e.drawImage(i, dst_area.transformation(), src_area.transformation(), alpha);
  }

  /// drawAll is a convenience function that calls draw with i.area() as the
  /// src_area.
  pub fn drawAll(i: Image, e: *Engine, dst_area: Rectangle, alpha: u8) void {
    i.draw(e, dst_area, i.area(), alpha);
  }
};

pub const CImage = extern struct {
  id: gl.Texture,
  width: u32,
  height: u32,
  flipped: bool,
  has_alpha: bool,

  usingnamespace ImageImpl(@This(), CRectangle);

  /// draw draws the given image with the given engine.
  /// dst_area is the rectangle to draw into.
  /// src_area is the rectangle to draw from ??? give i.area() to draw the whole
  /// image.
  /// alpha defines the opacity of the image, with 255 being fully opaque and
  /// 0 being fully transparent (i.e. invisible).
  /// alpha is applied on top of the image's alpha channel, if it has one.
  pub fn draw(i: CImage, e: *Engine, dst_area: CRectangle, src_area: CRectangle, alpha: u8) void {
    CEngineInterface.drawImage(e, i, dst_area.transformation(), src_area.transformation(), alpha);
  }

  /// drawAll is a convenience function that calls draw with i.area() as the
  /// src_area.
  pub fn drawAll(i: CImage, e: *Engine, dst_area: CRectangle, alpha: u8) void {
    draw(i, e, dst_area, i.area(), alpha);
  }
};

//////////////////////////////////////////////////////////////////////////////
// Canvas

pub const CanvasError = error {
  AlreadyClosed
};

fn CanvasImpl(comptime Self: type, comptime ImgImpl: type, comptime RectImpl: type, comptime EngImpl: type) type {
  const len_type = std.meta.fieldInfo(ImgImpl, .width).field_type;
  return struct {
    fn reinstatePreviousFb(canvas: *Self) void {
      canvas.e.canvas_count -= 1;
      canvas.previous_framebuffer.bind(.buffer);
      canvas.framebuffer.delete();
      canvas.framebuffer = .invalid;
      if (canvas.e.canvas_count == 0) {
        canvas.e.target_framebuffer = .{.width = canvas.e.window.width, .height = canvas.e.window.height};
      } else {
        canvas.e.target_framebuffer = .{.width = canvas.prev_width, .height = canvas.prev_height};
      }
      gl.viewport(0, 0, canvas.e.target_framebuffer.width, canvas.e.target_framebuffer.height);
    }

    pub fn create(e: *Engine, width: len_type, height: len_type, with_alpha: bool) !Self {
      var ret = Self{
        .e = e,
        .previous_framebuffer = @intToEnum(gl.Framebuffer, @intCast(std.meta.Tag(gl.Framebuffer), gl.getInteger(.draw_framebuffer_binding))),
        .framebuffer = gl.Framebuffer.gen(),
        .target_image = EngImpl.genTexture(e, width, height, if (with_alpha) 3 else 4, true, null),
        .alpha = with_alpha,
        .prev_width = e.target_framebuffer.width,
        .prev_height = e.target_framebuffer.height,
      };
      ret.framebuffer.texture2D(.buffer, .color0, .@"2d", ret.target_image.id, 0);
      if (e.backend == .ogl_32 or e.backend == .ogl_43) {
        gl.drawBuffers(&[_]gl.FramebufferAttachment{.color0});
      }
      if (gl.Framebuffer.checkStatus(.buffer) != .complete) unreachable;
      gl.clearColor(0, 0, 0, 0);
      gl.clear(.{.color = true});
      e.canvas_count += 1;
      return ret;
    }

    pub fn rectangle(canvas: *Self) RectImpl {
      return canvas.target_image.area();
    }

    /// closes the canvas and returns the resulting Image.
    /// returns CanvasError.AlreadyClosed if either finish() or close() have
    /// already been called on this canvas.
    pub fn finish(canvas: *Self) !ImgImpl {
      if (canvas.framebuffer == .invalid) {
        return CanvasError.AlreadyClosed;
      }
      reinstatePreviousFb(canvas);
      return canvas.target_image;
    }

    /// closes the canvas, dropping the drawn image.
    /// does nothing if either close() or finish() has been called previously on
    /// this Canvas.
    /// Should be used with `defer` after creating a Canvas.
    pub fn close(canvas: *Self) void {
      if (canvas.framebuffer != .invalid) {
        reinstatePreviousFb(canvas);
        canvas.target_image.free();
      }
    }
  };
}


/// A Canvas is a surface you can draw onto.
/// Creating a canvas will direct all OpenGL drawing commands onto the canvas.
/// You can frame the canvas to create an Image of what you've drawn onto the
/// canvas.
/// Taking down the canvas will discard what you've drawn if you haven't already
/// framed it.
/// Canvases do stack, so it is safe to create a Canvas while another Canvas is
/// active. If you take down or frame the new Canvas, the previous canvas will
/// be active again.
pub const Canvas = struct {
  e: *Engine,
  previous_framebuffer: gl.Framebuffer,
  framebuffer: gl.Framebuffer,
  target_image: Image,
  alpha: bool,
  prev_width: u32,
  prev_height: u32,

  usingnamespace CanvasImpl(@This(), Image, Rectangle, Engine.Impl);
};

pub const CCanvas = extern struct {
  e: *Engine,
  previous_framebuffer: gl.Framebuffer,
  framebuffer: gl.Framebuffer,
  target_image: CImage,
  alpha: bool,
  prev_width: u32,
  prev_height: u32,

  usingnamespace CanvasImpl(@This(), CImage, CRectangle, CEngineInterface);
};

//////////////////////////////////////////////////////////////////////////////
// Text rendering

const ft = @cImport({
  @cInclude("ft2build.h");
  @cInclude("freetype/freetype.h");
  @cInclude("freetype/ftmodapi.h");
  @cInclude("freetype/fterrors.h");
});

const FreeTypeMemImpl = struct {
  fn userAllocator(memory: ft.FT_Memory) std.mem.Allocator {
    return @ptrCast(*std.mem.Allocator, @alignCast(@alignOf(*std.mem.Allocator), memory.*.user)).*;
  }

  fn allocFunc(memory: ft.FT_Memory, size: c_long) callconv(.C) ?*anyopaque {
    const slice = userAllocator(memory).allocAdvanced(u8, @alignOf(usize), @intCast(usize, size) + @sizeOf(usize), .at_least) catch return null;
    const p = @ptrCast([*]usize, slice.ptr);
    p.* = @intCast(usize, size);
    return @ptrCast(*anyopaque, p+1);
  }

  fn freeFunc(memory: ft.FT_Memory, block: ?*anyopaque) callconv(.C) void {
    const p = @ptrCast([*]usize, @alignCast(@alignOf(usize), block orelse return)) - 1;
    const slice: []u8 = @ptrCast([*]u8, p)[0..p[0] + @sizeOf(usize)];
    userAllocator(memory).free(slice);
  }

  fn reallocFunc(memory: ft.FT_Memory, cur_size: c_long, new_size: c_long, block: ?*anyopaque) callconv(.C) ?*anyopaque {
    _ = cur_size;
    const p = @ptrCast([*]usize, @alignCast(@alignOf(usize), block orelse return null)) - 1;
    const slice = @ptrCast([*]u8, p)[0..p[0] + @sizeOf(usize)];
    const ret_slice = userAllocator(memory).realloc(slice, @intCast(usize, new_size) + @sizeOf(usize)) catch return null;
    const rp = @ptrCast([*]usize, ret_slice.ptr);
    rp.* = @intCast(usize, new_size);
    return @ptrCast(*anyopaque, rp+1);
  }
};

pub const Font = extern struct {

};

//////////////////////////////////////////////////////////////////////////////
// Engine

const gl = @import("zgl");

const c = @cImport({
  @cInclude("stb_image.h");
});

const ShaderError = error {
  CompilationFailed,
  LinkingFailed,
  AttributeProblem
};

const EngineError = error {
  NoDebugAvailable,
  FreeTypeError,
};

fn loadShader(src: []const u8, t: gl.ShaderType) !gl.Shader {
  var shader = gl.createShader(t);
  gl.shaderSource(shader, 1, &[_][]const u8{src});
  errdefer gl.deleteShader(shader);
  gl.compileShader(shader);
  var compiled = gl.getShader(shader, gl.ShaderParameter.compile_status);
  if (compiled == 1) {
    return shader;
  }
  var log = try gl.getShaderInfoLog(shader, std.heap.c_allocator);
  defer std.heap.c_allocator.free(log);
  std.log.scoped(.zargo).err("error compiling shader: {s} ?????? shader source:\n{s}\n-- end shader source", .{log, src});
  return ShaderError.CompilationFailed;
}

fn linkProgram(vs_src: []const u8, fs_src: []const u8) !gl.Program {
  var vertex_shader = try loadShader(vs_src, gl.ShaderType.vertex);
  errdefer gl.deleteShader(vertex_shader);
  var fragment_shader = try loadShader(fs_src, gl.ShaderType.fragment);
  errdefer gl.deleteShader(fragment_shader);
  var program = gl.createProgram();
  errdefer gl.deleteProgram(program);
  gl.attachShader(program, vertex_shader);
  gl.attachShader(program, fragment_shader);
  gl.linkProgram(program);
  var linked = gl.getProgram(program, gl.ProgramParameter.link_status);
  if (linked == 1) {
    return program;
  }
  var log = try gl.getProgramInfoLog(program, std.heap.c_allocator);
  defer std.heap.c_allocator.free(log);
  std.log.scoped(.zargo).err("error compiling shader: {s}", .{log});
  return ShaderError.LinkingFailed;
}

fn getUniformLocation(p: gl.Program, name: [:0]const u8) !u32 {
  if (gl.getUniformLocation(p, name)) |value| {
    return value;
  }
  std.log.scoped(.zargo).err("unable to get attribute '{s}' location\n", .{name});
  return ShaderError.AttributeProblem;
}

fn getAttribLocation(p: gl.Program, name: [:0]const u8) !u32 {
  if (gl.getAttribLocation(p, name)) |value| {
    return value;
  }
  std.log.scoped(.zargo).err("unable to get attribute '{s}' location\n", .{name});
  return ShaderError.AttributeProblem;
}

fn setUniformColor(id: u32, color: [4]u8) void {
  gl.uniform4f(id, @intToFloat(f32, color[0]) / 255.0,
      @intToFloat(f32, color[1]) / 255.0, @intToFloat(f32, color[2]) / 255.0,
      @intToFloat(f32, color[3]) / 255.0);
}

/// Backend defines the possible backends the engine can use. These are
/// currently OpenGL 3.2, OpenGL 4.3, OpenGL ES 2.0, and OpenGL ES 3.1.
/// The differences relevant to the engine are:
///
///  * OpenGL 4.3 will enable you to turn on debug output and is the only
///    backend with this capability.
///  * OpenGL 3.2 is the only backend available on macOS.
///  * OpenGL ES 2.0 is widely supported on mobile devices but does not let you
///    use MSAA when drawing to a canvas.
///  * OpenGL ES 3.1 is supported on a small number on recent devices and does
///    let you use MSAA when drawing to a canvas.
///
/// Other OpenGL versions are not supported as backends because they don't bring
/// any relevant functionality.
pub const Backend = enum(c_int) {
  ogl_32, ogl_43, ogles_20, ogles_31
};

const ShaderKind = enum {
  vertex, fragment
};

const Shaders = struct {
  rect_vertex: []const u8,
  rect_fragment: []const u8,
  img_vertex: []const u8,
  img_fragment: []const u8,
  blend_vertex: []const u8,
  blend_fragment: []const u8,
};

fn genShaders(comptime backend: Backend) Shaders {
  const builder = struct {
    fn versionDef() []const u8 {
      return switch (backend) {
        .ogl_32, .ogl_43 => "#version 150\n",
        .ogles_20, .ogles_31 => "#version 100\n",
      };
    }

    fn attr(comptime def: []const u8) []const u8 {
      return switch (backend) {
        .ogl_32, .ogl_43 => "in ",
        .ogles_20, .ogles_31 => "attribute ",
      } ++ def ++ ";\n";
    }

    fn uniform(comptime def: []const u8) []const u8 {
      return "uniform " ++ def ++ ";\n";
    }

    fn varyOut(comptime def: []const u8) []const u8 {
      return switch (backend) {
        .ogl_32, .ogl_43 => "out ",
        .ogles_20, .ogles_31 => "varying ",
      } ++ def ++ ";\n";
    }

    fn varyIn(comptime def: []const u8) []const u8 {
      return switch (backend) {
        .ogl_32, .ogl_43 => "in ",
        .ogles_20, .ogles_31 => "varying "
      } ++ def ++ ";\n";
    }

    fn fragColorDef() []const u8 {
      return switch (backend) {
        .ogl_32, .ogl_43 => "out vec4 fragColor;\n",
        .ogles_20, .ogles_31 => "",
      };
    }

    fn fragColor() []const u8 {
      return switch (backend) {
        .ogl_32, .ogl_43 => "fragColor",
        .ogles_20, .ogles_31 => "gl_FragColor",
      };
    }

    fn texture(comptime args: []const u8) []const u8 {
      return switch (backend) {
        .ogl_32, .ogl_43 => "texture(",
        .ogles_20, .ogles_31 => "texture2D(",
      } ++ args ++ ")";
    }

    fn precision(comptime def: []const u8) []const u8 {
      return "precision " ++ def ++ ";\n";
    }

    fn matMult(comptime m: []const u8, comptime v: []const u8) []const u8 {
      return "vec2(" ++ m ++ "[0].x * " ++ v ++ ".x + " ++ m ++ "[1].x * " ++ v ++ ".y + " ++ m ++ "[2].x, "
          ++ m ++ "[0].y * " ++ v ++ ".x + " ++ m ++ "[1].y * " ++ v ++ ".y + " ++ m ++ "[2].y)";
    }

    fn rect(comptime kind: ShaderKind) []const u8 {
      return switch(kind) {
        .vertex => versionDef() ++ uniform("vec2 u_transform[3]")
            ++ attr("vec2 a_position") ++
            \\ void main() {
            \\   gl_Position = vec4(
            ++     matMult("u_transform", "a_position") ++
            \\     , 0, 1
            \\   );
            \\ }
          ,
        .fragment => versionDef() ++ precision("mediump float")
            ++ uniform("vec4 u_color") ++ fragColorDef() ++
            "void main() {\n  " ++ fragColor() ++ " = u_color;\n}",
      };
    }

    fn img(comptime kind: ShaderKind) []const u8 {
      return switch(kind) {
        .vertex => versionDef()
            ++ uniform("vec2 u_src_transform[3]")
            ++ uniform("vec2 u_dst_transform[3]")
            ++ attr("vec2 a_position")
            ++ varyOut("vec2 v_texCoord") ++
            \\ void main() {
            \\   gl_Position = vec4(
            ++     matMult("u_dst_transform", "a_position") ++
            \\     , 0, 1);
            \\   v_texCoord = vec2(
            \\     u_src_transform[0].x * a_position.x + u_src_transform[1].x * a_position.y + u_src_transform[2].x,
            \\     u_src_transform[0].y * a_position.x + u_src_transform[1].y * a_position.y + u_src_transform[2].y
            \\   );
            \\ }
            ,
        .fragment => versionDef() ++ precision("mediump float")
            ++ varyIn("vec2 v_texCoord") ++ fragColorDef()
            ++ uniform("sampler2D s_texture") ++ uniform("float u_alpha") ++
            \\ void main() {
            \\   vec4 c =
            ++ texture("s_texture, v_texCoord") ++ ";\n  "
            ++ fragColor() ++ " = vec4(c.rgb, u_alpha * c.a);\n}",
      };
    }

    fn blend(comptime kind: ShaderKind) []const u8 {
      return switch(kind) {
        .vertex => versionDef()
            ++ uniform("vec2 u_posTrans[3]")
            ++ uniform("vec2 u_texTrans[3]")
            ++ attr("vec2 a_position")
            ++ varyOut("vec2 v_texCoord") ++
            \\ void main() {
            \\   gl_Position = vec4(
            ++       matMult("u_posTrans", "a_position") ++
            \\       , 0, 1);
            \\   vec2 flipped = vec2(a_position.x, 1.0-a_position.y);
            \\   v_texCoord =
            ++       matMult("u_texTrans", "flipped") ++
            \\   ;
            \\ }
            ,
        .fragment => versionDef() ++ precision("mediump float")
            ++ varyIn("vec2 v_texCoord") ++ fragColorDef()
            ++ uniform("sampler2D s_texture")
            ++ uniform("vec4 u_primary")
            ++ uniform("vec4 u_secondary") ++
            \\ void main() {
            \\   float a =
            ++       texture("s_texture, v_texCoord") ++ ".r;"
            ++   fragColor() ++ " = a * u_primary + (1.0-a) * u_secondary;" ++
            \\ }
      };
    }
  };
  return .{
    .rect_vertex = builder.rect(.vertex),
    .rect_fragment = builder.rect(.fragment),
    .img_vertex = builder.img(.vertex),
    .img_fragment = builder.img(.fragment),
    .blend_vertex = builder.blend(.vertex),
    .blend_fragment = builder.blend(.fragment),
  };
}

fn EngineImpl(comptime Self: type, comptime RectImpl: type, comptime ImgImpl: type) type {
  const len_type = std.meta.fieldInfo(ImgImpl, .width).field_type;
  return struct {
    fn debugCallback(e: *const Self, source: gl.DebugSource,
        msg_type: gl.DebugMessageType, id: usize, severity: gl.DebugSeverity,
        message: []const u8) void {
      _ = id; _ = e;
      if (msg_type == .@"error") {
        std.log.scoped(.OpenGL).err("[{s}] {s}: {s}", .{@tagName(severity), @tagName(source), message});
      } else if (severity != .notification) {
        std.log.scoped(.OpenGL).warn("[{s}|{s}] {s}: {s}", .{@tagName(msg_type), @tagName(severity), @tagName(source), message});
      } else {
        std.log.scoped(.OpenGL).info("[{s}|{s}] {s}: {s}", .{@tagName(msg_type), @tagName(severity), @tagName(source), message});
      }
    }

    /// init initializes the engine and must be called once before using the
    /// engine. Before initializing the engine, you must create an OpenGL context.
    /// This is platform dependent and therefore not implemented by the engine.
    /// You can use libraries like GLFW or SDL to create a context.
    ///
    /// The backend you give must match the OpenGL context you created.
    /// If it doesn't, you will likely get errors from shader compilation.
    ///
    /// windows_width and window_height ought to be the size of your OpenGL
    /// context in pixels. Mind that this must be the *real* pixel size, not the
    /// virtual pixel size you may get if you have an HiDPI monitor.
    /// If your window is resizeable, you can change the window size later with
    /// setWindowSize.
    ///
    /// Only set debug to true if backend is ogl_43. No other backend supports
    /// debug output and will return an error.
    pub fn init(
      e: *Self,
      allocator: std.mem.Allocator,
      backend: Backend,
      window_width: u32,
      window_height: u32,
      debug: bool,
    ) !void {
      e.backend = backend;
      if (debug) {
        if (backend != .ogl_43) {
          return EngineError.NoDebugAvailable;
        }
        gl.enable(gl.Capabilities.debug_output);
        gl.debugMessageCallback(e, debugCallback);
        //gl.debugMessageInsert(.application, .other, .notification, "initialized debug output");
      }

      const vertices = [_]f32{0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0};
      e.vbo = gl.genBuffer();
      gl.bindBuffer(e.vbo, gl.BufferTarget.array_buffer);
      gl.bufferData(gl.BufferTarget.array_buffer, f32, &vertices, gl.BufferUsage.static_draw);

      switch (backend) {
        .ogl_32, .ogl_43 => {
          e.vao = gl.genVertexArray();
          gl.bindVertexArray(e.vao);
          e.single_value_color = gl.PixelFormat.red;
        },
        else => {
          e.vao = .invalid;
          e.single_value_color = gl.PixelFormat.luminance;
        },
      }

      e.canvas_count = 0;

      const shaders = switch (backend) {
        .ogl_32 => genShaders(.ogl_32),
        .ogl_43 => genShaders(.ogl_43),
        .ogles_20 => genShaders(.ogles_20),
        .ogles_31 => genShaders(.ogles_31)
      };

      var rect_proc = try linkProgram(shaders.rect_vertex, shaders.rect_fragment);
      errdefer gl.deleteProgram(rect_proc);
      e.rect_proc = .{
        .p = rect_proc,
        .transform = try getUniformLocation(rect_proc, "u_transform"),
        .position  = try getAttribLocation(rect_proc, "a_position"),
        .color     = try getUniformLocation(rect_proc, "u_color"),
      };

      var img_proc = try linkProgram(shaders.img_vertex, shaders.img_fragment);
      errdefer gl.deleteProgram(img_proc);
      e.img_proc = .{
        .p = img_proc,
        .src_transform = try getUniformLocation(img_proc, "u_src_transform"),
        .dst_transform = try getUniformLocation(img_proc, "u_dst_transform"),
        .position = try getAttribLocation(img_proc, "a_position"),
        .texture = try getUniformLocation(img_proc, "s_texture"),
        .alpha = try getUniformLocation(img_proc, "u_alpha"),
      };

      var blend_proc = try linkProgram(shaders.blend_vertex, shaders.blend_fragment);
      errdefer gl.deleteProgram(blend_proc);
      e.blend_proc = .{
        .p = blend_proc,
        .posTrans = try getUniformLocation(blend_proc, "u_posTrans"),
        .texTrans = try getUniformLocation(blend_proc, "u_texTrans"),
        .position = try getAttribLocation(blend_proc, "a_position"),
        .texture = try getUniformLocation(blend_proc, "s_texture"),
        .primary = try getUniformLocation(blend_proc, "u_primary"),
        .secondary = try getUniformLocation(blend_proc, "u_secondary"),
      };

      gl.disable(gl.Capabilities.depth_test);
      gl.depthMask(false);
      e.max_tex_size = gl.getInteger(gl.Parameter.max_texture_size);
      e.setWindowSize(window_width, window_height);

      e.allocator = allocator;
      e.freetype_memory = .{
        .user = @ptrCast(*anyopaque, &e.allocator),
        .alloc = FreeTypeMemImpl.allocFunc,
        .free = FreeTypeMemImpl.freeFunc,
        .realloc = FreeTypeMemImpl.reallocFunc,
      };
      const ft_res = ft.FT_New_Library(&e.freetype_memory, &e.freetype_lib);
      if (ft_res != 0) {
        gl.deleteBuffer(e.vbo);
        if (e.vao != .invalid) {
          gl.deleteVertexArray(e.vao);
        }
        if (@hasField(ft, "FT_Error_String")) {
          const msg = std.mem.span(ft.FT_Error_String(ft_res));
          std.log.scoped(.zargo).err("FreeType init error: {s}", .{msg});
        } else {
          // FT_Error_String not supported in Raspberry Pi FreeType version.
          std.log.scoped(.zargo).err("FreeType init error", .{});
        }
        return EngineError.FreeTypeError;
      }
    }

    /// setWindowSize updates the window size.
    /// The window size is the coordinate system for Rectangles and Transforms.
    pub fn setWindowSize(e: *Self, width: u32, height: u32) void {
      e.window = .{.width = width, .height = height};
      if (e.canvas_count == 0) {
        e.target_framebuffer = .{.width = e.window.width, .height = e.window.height};
        gl.viewport(0, 0, width, height);
      }
      e.view_transform = Transform.identity().translate(-1.0, -1.0).scale(
        2.0 / @intToFloat(f32, width), 2.0 / @intToFloat(f32, height));
    }

    pub fn area(e: *Self) RectImpl {
      return RectImpl{.x = 0, .y = 0, .width = @intCast(u31, e.window.width), .height = @intCast(u31, e.window.height)};
    }

    /// clear clears the current framebuffer to be of the given color.
    pub fn clear(e: *Self, color: [4]u8) void {
      _ = e;
      gl.clearColor(@intToFloat(f32, color[0])/255.0, @intToFloat(f32, color[1])/255.0,
          @intToFloat(f32, color[2])/255.0, @intToFloat(f32, color[3])/255.0);
      gl.clear(.{.color = true});
    }

    /// close closes the engine. It must not be used after that.
    pub fn close(e: *Self) void {
      gl.deleteBuffer(e.vbo);
      if (e.vao != .invalid) {
        gl.deleteVertexArray(e.vao);
      }
      _ = ft.FT_Done_Library(e.freetype_lib);
    }

    /// fillUnit fills the unit square around (0,0) with the given color.
    /// The square is transformed by t before it is being filled.
    /// If copy_alpha is true, the alpha value of the color is copied into the
    /// framebuffer; if it is false, it will cause the rectangle to blend with the
    /// existing content according to the given alpha value.
    ///
    /// The target area spans from (0,0) to (window_width, window_height) if
    /// rendering to the primary framebuffer, or from (0,0) to (c.width, c.height)
    /// if rendering to the canvas c.
    pub fn fillUnit(e: *Self, t: Transform, color: [4]u8, copy_alpha: bool) void {
      if (!copy_alpha and color[3] != 255) {
        gl.enable(gl.Capabilities.blend);
        gl.blendFuncSeparate(gl.BlendFactor.src_alpha, gl.BlendFactor.one_minus_src_alpha, gl.BlendFactor.one_minus_dst_alpha, gl.BlendFactor.one);
        defer gl.disable(gl.Capabilities.blend);
      }
      gl.bindBuffer(e.vbo, gl.BufferTarget.array_buffer);
      if (e.vao != .invalid) {
        gl.bindVertexArray(e.vao);
      }
      gl.useProgram(e.rect_proc.p);
      gl.vertexAttribPointer(e.rect_proc.position, 2, gl.Type.float, false, 2*@sizeOf(f32), 0);
      gl.enableVertexAttribArray(e.rect_proc.position);

      const it = toInternalCoords(e, t, false);

      setUniformColor(e.rect_proc.color, color);
      gl.uniform2fv(e.rect_proc.transform, &it.m);
      gl.drawArrays(gl.PrimitiveType.triangle_fan, 0, 4);
    }

    /// fillRect fills the given rectangle with the given color according to the
    /// semantic of fillUnit.
    pub fn fillRect(e: *Self, r: RectImpl, color: [4]u8, copy_alpha: bool) void {
      e.fillUnit(r.transformation(), color, copy_alpha);
    }

    /// blendUnit fills the unit square around (0,0) with two colors.
    /// The square is transformed by dst_transform before it is being filled.
    /// The two colors are mixed via the red channel of mask by mapping
    /// 0 to color1 and 255 to color2, the values in between doing linear blending.
    ///
    /// The area of the mask used for blending is the unit square around (0,0),
    /// transformed by src_transform. The result can be larger than the mask if
    /// the mask should be repeated.
    pub fn blendUnit(e: *Self, mask: ImgImpl, dst_transform: Transform, src_transform: Transform, color1: [4]u8, color2: [4]u8) void {
      gl.bindBuffer(e.vbo, gl.BufferTarget.array_buffer);
      if (e.vao != .invalid) {
        gl.bindVertexArray(e.vao);
      }
      gl.useProgram(e.blend_proc.p);
      gl.vertexAttribPointer(e.blend_proc.position, 2, gl.Type.float, false, 2*@sizeOf(f32), 0);
      gl.enableVertexAttribArray(e.blend_proc.position);

      gl.activeTexture(gl.TextureUnit.texture_0);
      gl.bindTexture(mask.id, gl.TextureTarget.@"2d");
      gl.uniform1i(e.blend_proc.texture, 0);

      const ist = Transform.identity().scale(
        1.0 / @intToFloat(f32, mask.width), -1.0 / @intToFloat(f32, mask.height)
      ).compose(src_transform).translate(-0.5, -0.5);
      gl.uniform2fv(e.blend_proc.texTrans, &ist.m);

      const idt = toInternalCoords(e, dst_transform, false);
      gl.uniform2fv(e.blend_proc.posTrans, &idt.m);

      setUniformColor(e.blend_proc.primary, color1);
      setUniformColor(e.blend_proc.secondary, color2);

      gl.drawArrays(gl.PrimitiveType.triangle_fan, 0, 4);
    }

    /// blendRect fills the given rectangle a blend of the given colors according
    /// to the semantics of blendUnit, with src_rect being source area of the mask,
    /// which may be larger than the mask and will then cause to repeat it.
    pub fn blendRect(e: *Self, mask: ImgImpl, dst_rect: RectImpl, src_rect: RectImpl, color1: [4]u8, color2: [4]u8) void {
      blendUnit(e, mask, dst_rect.transformation(), src_rect.transformation(), color1, color2);
    }

    /// loadImage loads the image file at the given path into a texture.
    /// on failure, the returned image will be empty.
    pub fn loadImage(e: *Self, path: [:0]const u8) ImgImpl {
      var x: c_int = undefined;
      var y: c_int = undefined;
      var n: c_int = undefined;
      const pixels = c.stbi_load(path, &x, &y, &n, 0);
      defer c.stbi_image_free(pixels);
      return genTexture(e, @intCast(usize, x), @intCast(usize, y), @intCast(u8, n), false, pixels);
    }

    /// drawImage is the low-level version of Image.draw. The src_transform
    /// transforms the unit square around (0,0) into the rectangle you want
    /// to draw from (give i.area() to draw the whole image).
    /// The dst_transform transforms the unit square around (0,0) into the
    /// rectangle you want to draw into.
    /// The given alpha value will applied on top of an existing alpha value if
    /// the image has an alpha channel.
    pub fn drawImage(e: *Self, i: ImgImpl, dst_transform: Transform, src_transform: Transform, alpha: u8) void {
      if (alpha != 255 or i.has_alpha) {
        gl.enable(gl.Capabilities.blend);
        gl.blendFuncSeparate(gl.BlendFactor.src_alpha, gl.BlendFactor.one_minus_src_alpha, gl.BlendFactor.one_minus_dst_alpha, gl.BlendFactor.one);
      }

      gl.bindBuffer(e.vbo, .array_buffer);
      if (e.vao != .invalid) {
        gl.bindVertexArray(e.vao);
      }
      gl.useProgram(e.img_proc.p);

      gl.vertexAttribPointer(e.rect_proc.position, 2, gl.Type.float, false, 2*@sizeOf(f32), 0);
      gl.enableVertexAttribArray(e.rect_proc.position);

      gl.activeTexture(gl.TextureUnit.texture_0);
      gl.bindTexture(i.id, gl.TextureTarget.@"2d");
      gl.uniform1i(e.img_proc.texture, 0);
      gl.uniform1f(e.img_proc.alpha, @intToFloat(f32, alpha)/255.0);

      const ist = Transform.identity().scale(
        1.0 / @intToFloat(f32, i.width), -1.0 / @intToFloat(f32, i.height)
      ).compose(src_transform).translate(-0.5, -0.5);
      gl.uniform2fv(e.img_proc.src_transform, &ist.m);

      const idt = toInternalCoords(e, dst_transform, false);
      gl.uniform2fv(e.img_proc.dst_transform, &idt.m);

      gl.drawArrays(gl.PrimitiveType.triangle_fan, 0, 4);

      if (alpha != 255 or i.has_alpha) {
        gl.disable(gl.Capabilities.blend);
      }
    }

    fn toInternalCoords(e: *Self, t: Transform, flip: bool) Transform {
      var r = e.view_transform.compose(t);
      if (flip) {
        r = r.scale(1.0, -1.0);
      }
      return r.translate(-0.5, -0.5);
    }

    fn genTexture(e: *Self, width: usize, height: usize, num_colors: u8, flipped: bool, pixels: ?[*]const u8) ImgImpl {
      const ret = gl.genTexture();
      gl.bindTexture(ret, .@"2d");
      gl.texParameter(.@"2d", .mag_filter, .linear);
      gl.texParameter(.@"2d", .min_filter, .linear);
      gl.texParameter(.@"2d", .wrap_s, .repeat);
      gl.texParameter(.@"2d", .wrap_t, .repeat);
      gl.pixelStore(.unpack_alignment, @intCast(usize, num_colors));
      const gl_format = switch (num_colors) {
        1    => e.single_value_color,
        2, 3 => .rgb,
        4    => .rgba,
        else => unreachable
      };
      gl.textureImage2D(.@"2d", 0, gl_format, width, height, gl_format, gl.PixelType.unsigned_byte, pixels);
      return ImgImpl{
        .id = ret,
        .width = @intCast(len_type, width),
        .height = @intCast(len_type, height),
        .flipped = flipped,
        .has_alpha = num_colors == 4,
      };
    }
  };
}

/// The Engine is the core of the API.
/// You need to initialize an Engine with init() before doing any drawing.
///
/// Giving debug=true will enable debug output, you should have created a
/// debugging context for that. Non-debugging contexts are allowed not to
/// provide any debugging output.
pub const Engine = struct {
  backend: Backend,
  rect_proc: struct {
    p: gl.Program,
    transform: u32,
    position: u32,
    color: u32,
  },
  img_proc: struct {
    p: gl.Program,
    src_transform: u32,
    dst_transform: u32,
    position: u32,
    texture: u32,
    alpha: u32,
  },
  blend_proc: struct {
    p: gl.Program,
    posTrans: u32,
    texTrans: u32,
    position: u32,
    texture: u32,
    primary: u32,
    secondary: u32,
  },
  window: struct {
    width: u32, height: u32,
  },
  target_framebuffer: struct {
    width: u32, height: u32,
  },
  view_transform: Transform,
  vao: gl.VertexArray,
  vbo: gl.Buffer,
  canvas_count: u8,
  max_tex_size: i32,
  single_value_color: gl.PixelFormat,
  freetype_memory: ft.FT_MemoryRec_,
  freetype_lib: ft.FT_Library,
  allocator: std.mem.Allocator,

  const Impl = EngineImpl(@This(), Rectangle, Image);

  usingnamespace Impl;

  pub const createCanvas = Canvas.create;
};

pub const CEngineInterface = EngineImpl(Engine, CRectangle, CImage);