# zargo

**zargo** is a zig library for 2D drawing using OpenGL.
It supports both desktop OpenGL and OpenGL ES.

Simple usage:

```zig
// initialize engine
var e: zargo.Engine = undefined;
const backend =  if (std.builtin.os.tag.isDarwin()) .ogl_32
    else if (std.builtin.os.tag == .windows) .ogl43 else .ogles_20;
try e.init(backend, window_width, window_height, false);
defer e.close();

// load some image into a texture
const tex = e.loadImage("test.png");
defer tex.free();

// draw a red rectangle
e.fillRect(zargo.Rectangle{.x = 100, .y = 100, .width = 200, .height = 200},
    [_]u8{255,0,0,255}, false);

// draw the whole texture into a rectangle with the lower left corner at
// (500, 400)
tex.drawAll(&e, tex.area().move(500, 400), 255);
```

zargo does not create a window or an OpenGL context for you. You can use
libraries like GLFW or SDL to do that. Be sure to tell the library to construct
the same version of the OpenGL context that you instruct the engine to use as
backend!

## license

MIT