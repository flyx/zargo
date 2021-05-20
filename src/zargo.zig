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
  pub fn translate(t: Transform, x: f32, y: f32) Transform {
    return Transform{.m = .{
        t.m[0], t.m[1], .{
          t.m[0][0]*x + t.m[1][0]*y + t.m[2][0],
          t.m[0][1]*x + t.m[1][1]*y + t.m[2][1]
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

/// A Rectangle represents a rectangular area with given size and offset.
/// This is the high-level API for positioning.
pub const Rectangle = struct {
  x: i32, y: i32, width: u31, height: u31,

  /// translation returns a translation matrix that will translate the point
  /// (0,0) to the current center of the rectangle.
  pub fn translation(r: Rectangle) Transform {
    return Transform.identity().translate(@intToFloat(f32, r.x) + @intToFloat(f32, r.width) / 2.0,
        @intToFloat(f32, r.y) + @intToFloat(f32, r.height) / 2.0);
  }

  /// transformation returns a transformation matrix that will transform a unit
  /// square at ((-0.5,-0.5), (0.5,-0.5), (0.5, 0.5), (-0.5, 0.5)) into the
  /// given rectangle.
  pub fn transformation(r: Rectangle) Transform {
    return r.translation().scale(@intToFloat(f32, r.width), @intToFloat(f32, r.height));
  }

  /// move modifies the rectangle's position by the given dx and dy values.
  pub fn move(r: Rectangle, dx: i32, dy: i32) Rectangle {
    return Rectangle{.x = r.x + dx, .y = r.y + dy, .width = r.width, .height = r.height};
  }

  /// grows the rectangle by the given dw and dh values,
  /// keeping its center point (i.e. dw and dh will be evenly distributed to
  /// the four edges).
  /// use negative values to shrink.
  pub fn grow(r: Rectangle, dw: i32, dh: i32) Rectangle {
    return Rectangle{.x = r.x + @divTrunc(dw, 2), .y = r.y + @divTrunc(dh, 2), .width = @intCast(u31, r.width - dw), .height = @intCast(u31, r.height - dh)};
  }

  /// scale will scale the rectangle by the given factors.
  pub fn scale(r: Rectangle, factorX: f32, factorY: f32) Rectangle {
    var ret = Rectangle{.x = undefined, .y = undefined,
      .width = @floatToInt(u31, @intToFloat(f32, r.width) * factorX),
      .height = @floatToInt(u31, @intToFloat(f32, r.height) * factorY)};
    ret.x = r.x + @divTrunc(r.width - ret.width, 2);
    ret.y = r.y + @divTrunc(r.height - ret.height, 2);
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
  pub fn position(r: Rectangle, width: u31, height: u31, horiz: HAlign, vert: VAlign) Rectangle {
    return Rectangle{
      .x = switch (horiz) {
        .left    => r.x,
        .center  => r.x + @rem(r.width - width, 2),
        .right   => r.x + r.width - width
      },
      .y = switch (vert) {
        .top    => r.y + r.height - height,
        .middle => r.y + @rem(r.height - height, 2),
        .bottom => r.y
      },
      .width = width,
      .height = height
    };
  }
};

//////////////////////////////////////////////////////////////////////////////
// Images

/// Image is an image in GPU memory, i.e. a texture.
/// Images must be explicitly free'd using free().
/// Images can be created via the engine, you cannot load an image into GPU
/// memory before initializing the engine.
pub const Image = extern struct {
  id: gl.Texture,
  width: usize,
  height: usize,
  flipped: bool,
  has_alpha: bool,

  /// empty returns an empty image, which is not linked to a GPU texture.
  pub fn empty() Image {
    return Image{
      .id = .invalid, .width = 0, .height = 0, .flipped = false, .has_alpha = false
    };
  }

  /// isEmpty returns true iff the given image is linked to a GPU texture.
  pub fn isEmpty(i: Image) bool {
    return i.width == 0;
  }

  /// area returns a rectangle with lower left corner at (0,0) that has the
  /// image's width and height.
  pub fn area(i: Image) Rectangle {
    return Rectangle{.x = 0, .y = 0, .width = @intCast(u31, i.width), .height = @intCast(u31, i.height)};
  }

  /// draw draws the given image with the given engine.
  /// dst_area is the rectangle to draw into.
  /// src_area is the rectangle to draw from – give i.area() to draw the whole
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

  pub fn free(i: *Image) void {
    i.id.delete();
    i.* = empty();
  }
};

//////////////////////////////////////////////////////////////////////////////
// Canvas

pub const CanvasError = error {
  AlreadyClosed
};

/// A Canvas is a surface you can draw onto.
/// Creating a canvas will direct all OpenGL drawing commands onto the canvas.
/// You can frame the canvas to create an Image of what you've drawn onto the
/// canvas.
/// Taking down the canvas will discard what you've drawn if you haven't already
/// framed it.
/// Canvases do stack, so it is safe to create a Canvas while another Canvas is
/// active. If you take down or frame the new Canvas, the previous canvas will
/// be active again.
pub const Canvas = extern struct {
  e: *Engine,
  previous_framebuffer: gl.Framebuffer,
  framebuffer: gl.Framebuffer,
  target_image: Image,
  alpha: bool,
  prev_width: u32,
  prev_height: u32,

  fn reinstatePreviousFb(canvas: *Canvas) void {
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

  pub fn create(e: *Engine, width: usize, height: usize, with_alpha: bool) !Canvas {
    var ret = Canvas{
      .e = e,
      .previous_framebuffer = @intToEnum(gl.Framebuffer, @intCast(std.meta.Tag(gl.Framebuffer), gl.getInteger(.draw_framebuffer_binding))),
      .framebuffer = gl.Framebuffer.gen(),
      .target_image = e.genTexture(width, height, if (with_alpha) 3 else 4, true, null),
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

  pub fn rectangle(canvas: *Canvas) Rectangle {
    return canvas.target_image.area();
  }

  /// closes the canvas and returns the resulting Image.
  /// returns CanvasError.AlreadyClosed if either finish() or close() have
  /// already been called on this canvas.
  pub fn finish(canvas: *Canvas) !Image {
    if (canvas.framebuffer == .invalid) {
      return CanvasError.AlreadyClosed;
    }
    canvas.reinstatePreviousFb();
    return canvas.target_image;
  }

  /// closes the canvas, dropping the drawn image.
  /// does nothing if either close() or finish() has been called previously on
  /// this Canvas.
  /// Should be used with `defer` after creating a Canvas.
  pub fn close(canvas: *Canvas) void {
    if (canvas.framebuffer != .invalid) {
      canvas.reinstatePreviousFb();
      canvas.target_image.free();
    }
  }
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
  NoDebugAvailable
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
  std.log.scoped(.zargo).err("error compiling shader: {s}", .{log});
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
  return ShaderError.AttributeProblem;
}

fn getAttribLocation(p: gl.Program, name: [:0]const u8) !u32 {
  if (gl.getAttribLocation(p, name)) |value| {
    return value;
  }
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

    fn rect(comptime kind: ShaderKind) []const u8 {
      return switch(kind) {
        .vertex => versionDef() ++ uniform("vec2 u_transform[3]")
            ++ attr("vec2 a_position") ++
            \\ void main() {
            \\   gl_Position = vec4(
            \\     u_transform[0].x * a_position.x + u_transform[1].x * a_position.y + u_transform[2].x,
            \\     u_transform[0].y * a_position.x + u_transform[1].y * a_position.y + u_transform[2].y,
            \\     0, 1
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
            \\     u_dst_transform[0].x * a_position.x + u_dst_transform[1].x * a_position.y + u_dst_transform[2].x,
            \\     u_dst_transform[0].y * a_position.x + u_dst_transform[1].y * a_position.y + u_dst_transform[2].y,
            \\     0, 1
            \\   );
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
  };
  return .{
    .rect_vertex = builder.rect(.vertex),
    .rect_fragment = builder.rect(.fragment),
    .img_vertex = builder.img(.vertex),
    .img_fragment = builder.img(.fragment),
  };
}

/// The Engine is the core of the API.
/// You need to initialize an Engine with init() before doing any drawing.
///
/// Giving debug=true will enable debug output, you should have created a
/// debugging context for that. Non-debugging contexts are allowed not to
/// provide any debugging output.
pub const Engine = extern struct {
  backend: Backend,
  rect_proc: extern struct {
    p: gl.Program,
    transform: u32,
    position: u32,
    color: u32
  },
  img_proc: extern struct {
    p: gl.Program,
    src_transform: u32,
    dst_transform: u32,
    position: u32,
    texture: u32,
    alpha: u32
  },
  window: extern struct {
    width: u32, height: u32,
  },
  target_framebuffer: extern struct {
    width: u32, height: u32,
  },
  view_transform: Transform,
  vao: gl.VertexArray,
  vbo: gl.Buffer,
  canvas_count: u8,
  max_tex_size: i32,
  single_value_color: gl.PixelFormat,

  const Self = @This();

  fn debugCallback(e: *const Self, source: gl.DebugSource,
      msg_type: gl.DebugMessageType, id: usize, severity: gl.DebugSeverity,
      message: []const u8) void {
    // TODO
  }

  /// init initializes the engine and must be called once before using the
  /// engine. Before initializing the engine, you must create an OpenGL context.
  /// This is platform dependent and therefore not implemented by the engine.
  /// You can use libraries like GLFW or SDL to create a context.
  ///
  /// The backend you give must match the OpenGL context you created.
  /// If it doesn't, you will likely get errors from shader compilation.

  /// windows_width and window_height ought to be the size of your OpenGL
  /// context in pixels. Mind that this must be the *real* pixel size, not the
  /// virtual pixel size you may get if you have an HiDPI monitor.
  /// If your window is resizeable, you can change the window size later with
  /// setWindowSize.
  ///
  /// Only set debug to true if backend is ogl_43. No other backend supports
  /// debug output and will return an error.
  pub fn init(e: *Self, backend: Backend, window_width: u32, window_height: u32, debug: bool) !void {
    e.backend = backend;
    if (debug) {
      if (backend != .ogl_43) {
        return EngineError.NoDebugAvailable;
      }
      gl.enable(gl.Capabilities.debug_output);
      gl.debugMessageCallback(e, debugCallback);
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
      .color     = try getUniformLocation(rect_proc, "u_color")
    };

    var img_proc = try linkProgram(shaders.img_vertex, shaders.img_fragment);
    errdefer gl.deleteProgram(img_proc);
    e.img_proc = .{
      .p = img_proc,
      .src_transform = try getUniformLocation(img_proc, "u_src_transform"),
      .dst_transform = try getUniformLocation(img_proc, "u_dst_transform"),
      .position = try getAttribLocation(img_proc, "a_position"),
      .texture = try getUniformLocation(img_proc, "s_texture"),
      .alpha = try getUniformLocation(img_proc, "u_alpha")
    };

    gl.disable(gl.Capabilities.depth_test);
    gl.depthMask(false);
    e.max_tex_size = gl.getInteger(gl.Parameter.max_texture_size);
    e.setWindowSize(window_width, window_height);
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

  /// clear clears the current framebuffer to be of the given color.
  pub fn clear(e: *Self, color: [4]u8) void {
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
    gl.vertexAttribPointer(e.rect_proc.position, 2, gl.Type.float, false, 2*@sizeOf(f32), null);
    gl.enableVertexAttribArray(e.rect_proc.position);

    var it = e.toInternalCoords(t, false);

    setUniformColor(e.rect_proc.color, color);
    gl.uniform2fv(e.rect_proc.transform, &it.m);
    gl.drawArrays(gl.PrimitiveType.triangle_fan, 0, 4);
  }

  /// fillRect fills the given rectangle with the given color according to the
  /// semantic of fillUnit.
  pub fn fillRect(e: *Self, r: Rectangle, color: [4]u8, copy_alpha: bool) void {
    e.fillUnit(r.transformation(), color, copy_alpha);
  }

  /// loadImage loads the image file at the given path into a texture.
  /// on failure, the returned image will be empty.
  pub fn loadImage(e: *Self, path: [:0]const u8) Image {
    var x: c_int = undefined;
    var y: c_int = undefined;
    var n: c_int = undefined;
    const pixels = c.stbi_load(path, &x, &y, &n, 0);
    defer c.stbi_image_free(pixels);
    return e.genTexture(@intCast(usize, x), @intCast(usize, y), @intCast(u8, n), false, pixels);
  }

  /// drawImage is the low-level version of Image.draw. The src_transform
  /// transforms the unit square around (0,0) into the rectangle you want
  /// to draw from (give i.area() to draw the whole image).
  /// The dst_transform transforms the unit square around (0,0) into the
  /// rectangle you want to draw into.
  /// The given alpha value will applied on top of an existing alpha value if
  /// the image has an alpha channel.
  pub fn drawImage(e: *Self, i: Image, dst_transform: Transform, src_transform: Transform, alpha: u8) void {
    if (alpha != 255 or i.has_alpha) {
      gl.enable(gl.Capabilities.blend);
      gl.blendFuncSeparate(gl.BlendFactor.src_alpha, gl.BlendFactor.one_minus_src_alpha, gl.BlendFactor.one_minus_dst_alpha, gl.BlendFactor.one);
    }

    gl.bindBuffer(e.vbo, .array_buffer);
    if (e.vao != .invalid) {
      gl.bindVertexArray(e.vao);
    }
    gl.useProgram(e.img_proc.p);

    gl.vertexAttribPointer(e.rect_proc.position, 2, gl.Type.float, false, 2*@sizeOf(f32), null);
    gl.enableVertexAttribArray(e.rect_proc.position);

    gl.activeTexture(gl.TextureUnit.texture_0);
    gl.bindTexture(i.id, gl.TextureTarget.@"2d");
    gl.uniform1i(e.img_proc.texture, 0);
    gl.uniform1f(e.img_proc.alpha, @intToFloat(f32, alpha)/255.0);

    const ist = Transform.identity().scale(
      1.0 / @intToFloat(f32, i.width), -1.0 / @intToFloat(f32, i.height)
    ).compose(src_transform).translate(-0.5, -0.5);
    //e.toInternalCoords(src_transform, false);
    gl.uniform2fv(e.img_proc.src_transform, &ist.m);

    const idt = e.toInternalCoords(dst_transform, false);
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

  fn genTexture(e: *Self, width: usize, height: usize, num_colors: u8, flipped: bool, pixels: ?[*]const u8) Image {
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
    return Image{
      .id = ret,
      .width = width,
      .height = height,
      .flipped = flipped,
      .has_alpha = num_colors == 4,
    };
  }

  pub const createCanvas = Canvas.create;
};
