#include <stdio.h>
#include <math.h>

#include <GLFW/glfw3.h>

#include "../include/zargo/zargo.h"

void keyCallback(GLFWwindow *win, int key, int scancode, int action, int mods) {
  if (action != GLFW_PRESS) return;

  switch (key) {
    case GLFW_KEY_ESCAPE: glfwSetWindowShouldClose(win, GL_TRUE); break;
    default: break;
  }
}

int main(int argc, char *argv[]) {
  //c.glfwSetErrorCallback(errorCallback);

  if (glfwInit() == GL_FALSE) {
    puts("Failed to initialize GLFW");
    return 1;
  }

  glfwWindowHint(GLFW_SAMPLES, 4);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

  GLFWwindow *window = glfwCreateWindow(800, 600, "test", NULL, NULL);

  glfwSetKeyCallback(window, keyCallback);
  glfwMakeContextCurrent(window);
  glfwSwapInterval(1);

  int w, h;
  glfwGetFramebufferSize(window, &w, &h);

  zargo_Engine e = zargo_engine_init(
#if defined(_WIN32)
      ZARGO_BACKEND_OGL_43
#elif defined(__APPLE__)
      ZARGO_BACKEND_OGL_32
#else
      ZARGO_BACKEND_OGLES_20
#endif
      , w, h, false);
  zargo_Image tex;
  zargo_engine_load_image(e, &tex, "test.png");
  printf("loaded texture: w = %zu, h = %zu, alpha = %d\n", tex.width, tex.height, tex.has_alpha);
  float angle = 0, iangle = 0;

  zargo_Image painted;
  zargo_image_empty(&painted);

  {
    zargo_Canvas canvas;
    zargo_canvas_create(&canvas, e, 200, 200, false);
    printf("created canvas: w= %zu, h = %zu\n", canvas.target_image.width, canvas.target_image.height);
    zargo_Rectangle area, target;
    zargo_canvas_rectangle(&canvas, &area);
    zargo_rectangle_position(&area, &target, 100, 100, ZARGO_HALIGN_LEFT, ZARGO_VALIGN_TOP);
    zargo_engine_fill_rect(e, &target, (uint8_t[]){255,0,0,255}, true);
    zargo_rectangle_position(&area, &target, 100, 100, ZARGO_HALIGN_RIGHT, ZARGO_VALIGN_TOP);
    zargo_engine_fill_rect(e, &target, (uint8_t[]){255,255,0,255}, true);
    zargo_rectangle_position(&area, &target, 100, 100, ZARGO_HALIGN_LEFT, ZARGO_VALIGN_BOTTOM);
    zargo_engine_fill_rect(e, &target, (uint8_t[]){0,0,255,255}, true);
    zargo_rectangle_position(&area, &target, 100, 100, ZARGO_HALIGN_RIGHT, ZARGO_VALIGN_BOTTOM);
    zargo_engine_fill_rect(e, &target, (uint8_t[]){0,255,0,255}, true);
    zargo_canvas_finish(&canvas, &painted);
  }

  zargo_Rectangle r1 = (zargo_Rectangle){
    .x = w/4 - 50, .y = h/4 - 50, .width = 100, .height = 100};
  zargo_Rectangle r2 = (zargo_Rectangle){
    .x = w*3/4 - 50, .y = h*3/4 - 50, .width = 100, .height = 100};

  while (glfwWindowShouldClose(window) == GL_FALSE) {
    zargo_engine_clear(e, (uint8_t[]){0,0,0,255});
    zargo_engine_fill_rect(e, &r1, (uint8_t[]){255,0,0,255}, true);
    zargo_Transform target;
    zargo_rectangle_transformation(&r2, &target);
    zargo_transform_rotate(&target, NULL, angle);
    zargo_engine_fill_unit(e, &target, (uint8_t[]){0,255,0,255}, true);
    zargo_Rectangle area, moved;
    zargo_image_area(&tex, &area);
    zargo_rectangle_move(&area, &moved, 500, 400);
    zargo_rectangle_transformation(&moved, &target);
    zargo_Transform src, tmp;
    zargo_transform_identity(&tmp);
    zargo_transform_rotate(&tmp, NULL, iangle);
    zargo_rectangle_transformation(&area, &src);
    zargo_transform_compose(&tmp, &src, &src);

    zargo_engine_draw_image(e, &tex, &target, &src, 255);
    angle = fmodf(angle + 0.01, 2*3.14159);
    iangle = fmodf(iangle + 0.001, 2*3.14159);

    if (!zargo_image_is_empty(&painted)) {
      zargo_image_area(&painted, &area);
      zargo_image_draw(&painted, e, &area, NULL, 255);
    }

    glfwSwapBuffers(window);
    glfwPollEvents();
  }
  return 0;
}