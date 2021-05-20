#ifndef ZARGO_H
#define ZARGO_H

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__MINGW32__)
#   define  ZARGO_DECLARE(type)  type
#elif defined(_WIN32)
#   if defined(ZARGO_DECLARE_STATIC)
#       define  ZARGO_DECLARE(type)  type
#   else
#       define  ZARGO_DECLARE(type)  __declspec(dllimport) type
#   endif
#else
#   define  ZARGO_DECLARE(type)  type
#endif

#include<stddef.h>
#include<stdint.h>
#include<stdbool.h>

typedef struct _zargo_Engine_impl *zargo_Engine;

typedef struct {
  float m[3][2];
} zargo_Transform;

typedef struct {
  int32_t x, y;
  uint32_t width, height;
} zargo_Rectangle;

typedef struct {
  uint32_t id;
  size_t width, height;
  bool flipped, has_alpha;
} zargo_Image;

typedef struct {
  zargo_Engine e;
  uint32_t previous_framebuffer, framebuffer;
  zargo_Image target_image;
  bool alpha;
  uint32_t prev_width, prev_height;
} zargo_Canvas;

enum {
  ZARGO_BACKEND_OGL_32,
  ZARGO_BACKEND_OGL_43,
  ZARGO_BACKEND_OGLES_20,
  ZARGO_BACKEND_OGLES_31
};

enum {
  ZARGO_HALIGN_LEFT,
  ZARGO_HALIGN_CENTER,
  ZARGO_HALIGN_RIGHT
};

enum {
  ZARGO_VALIGN_TOP,
  ZARGO_VALIGN_MIDDLE,
  ZARGO_VALIGN_BOTTOM
};

ZARGO_DECLARE(zargo_Engine)
zargo_engine_init(int backend, uint32_t window_width, uint32_t window_height, bool debug);

ZARGO_DECLARE(void)
zargo_engine_set_window_size(zargo_Engine e, uint32_t width, uint32_t height);

ZARGO_DECLARE(void)
zargo_engine_clear(zargo_Engine e, uint8_t color[4]);

ZARGO_DECLARE(void)
zargo_engine_close(zargo_Engine e);

ZARGO_DECLARE(void)
zargo_engine_fill_unit(zargo_Engine e, zargo_Transform t, uint8_t color[4], bool copy_alpha);

ZARGO_DECLARE(void)
zargo_engine_fill_rect(zargo_Engine e, zargo_Rectangle r, uint8_t color[4], bool copy_alpha);

ZARGO_DECLARE(zargo_Image)
zargo_engine_load_image(zargo_Engine e, const char *path);

ZARGO_DECLARE(void)
zargo_engine_draw_image(zargo_Engine e, zargo_Image i, zargo_Transform dst_transform, zargo_Transform src_transform, uint8_t alpha);

ZARGO_DECLARE(zargo_Transform)
zargo_transform_identity();

ZARGO_DECLARE(zargo_Transform)
zargo_transform_translate(zargo_Transform t, float x, float y);

ZARGO_DECLARE(zargo_Transform)
zargo_transform_rotate(zargo_Transform t, float angle);

ZARGO_DECLARE(zargo_Transform)
zargo_transform_scale(zargo_Transform t, float x, float y);

ZARGO_DECLARE(zargo_Transform)
zargo_transform_compose(zargo_Transform t1, zargo_Transform t2);

ZARGO_DECLARE(zargo_Transform)
zargo_rectangle_translation(zargo_Rectangle r);

ZARGO_DECLARE(zargo_Transform)
zargo_rectangle_transformation(zargo_Rectangle r);

ZARGO_DECLARE(zargo_Rectangle)
zargo_rectangle_move(zargo_Rectangle r, int32_t dx, int32_t dy);

ZARGO_DECLARE(zargo_Rectangle)
zargo_rectangle_grow(zargo_Rectangle r, int32_t dw, int32_t dh);

ZARGO_DECLARE(zargo_Rectangle)
zargo_rectangle_scale(zargo_Rectangle r, float factorX, float factorY);

ZARGO_DECLARE(zargo_Rectangle)
zargo_rectangle_position(zargo_Rectangle r, uint32_t width, uint32_t height, int halign, int valign);

ZARGO_DECLARE(zargo_Image)
zargo_image_empty();

ZARGO_DECLARE(bool)
zargo_image_is_empty(zargo_Image i);

ZARGO_DECLARE(zargo_Rectangle)
zargo_image_area(zargo_Image i);

ZARGO_DECLARE(void)
zargo_image_draw(zargo_Image i, zargo_Engine e, zargo_Rectangle dst_area, zargo_Rectangle src_area, uint8_t alpha);

ZARGO_DECLARE(void)
zargo_image_draw_all(zargo_Image i, zargo_Engine e, zargo_Rectangle dst_area, uint8_t alpha);

ZARGO_DECLARE(zargo_Canvas)
zargo_canvas_create(zargo_Engine e, size_t width, size_t height, bool with_alpha);

ZARGO_DECLARE(zargo_Rectangle)
zargo_canvas_rectangle(zargo_Canvas *c);

ZARGO_DECLARE(zargo_Image)
zargo_canvas_finish(zargo_Canvas *c);

ZARGO_DECLARE(void)
zargo_canvas_close(zargo_Canvas *c);

#ifdef __cplusplus
}
#endif

#endif