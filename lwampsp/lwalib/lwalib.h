#include <stdlib.h>
#include <stdio.h>
#include <SDL.h>
#include <SDL_endian.h>
#include <SDL_types.h>
#include <glui.h>
#include <lwalib_math.h>

/* Program MUST set these! */
extern int screen_width;
extern int screen_height;

typedef void (*sdl_handler)(void);

SDL_Surface *LWA_Init(int width, int height, int bpp, Uint32 flags);

GLUI *LWA_GUI(sdl_handler sdlhandler, int *argc, char **argv);
void LWA_MsgBox(GLUI *parent, const char *title, const char *fmt, ...);
GLUI_StaticText *LWA_LabelLabel(GLUI *glui, GLUI_Panel *panel, char *text);
char *float2str(float f);

int FIX_Y(int y);
void DrawStart(SDL_Surface *screen);
void DrawEnd(SDL_Surface *screen);
void DrawPixel(SDL_Surface *screen, int x, int y, Uint8 R, Uint8 G, Uint8 B);
void DrawPixel(SDL_Surface *screen, int x, int y, Uint32 color);
void DrawRect(SDL_Surface *screen, int x, int y, int w, int h, Uint8 r, Uint8 g, Uint8 b);
void DrawRect(SDL_Surface *screen, int x, int y, int w, int h, Uint32 color);
void DrawParabola(SDL_Surface *screen, int x, int y, double radangle, double velocity, Uint8 r, Uint8 g, Uint8 b);
void DrawParabola(SDL_Surface *screen, int x, int y, double radangle, double velocity, Uint32 color);
void DrawLine(SDL_Surface *screen, int x0, int y0, int x1, int y1, Uint32 color);
void DrawLine(SDL_Surface *screen, int x0, int y0, int x1, int y1, Uint8 r, Uint8 g, Uint8 b);
void DrawBlast(SDL_Surface *screen, int x_center, int y_center, int radius, Uint32 color);
void DrawBlast(SDL_Surface *screen, int x_center, int y_center, int radius, Uint8 r, Uint8 g, Uint8 b);

double deg2rad(double deg);
double rad2deg(double rad);
double vector_x(double radangle, double magnitude);
double vector_y(double radangle, double magnitude);

double parabola_x_to_y(double x, double radangle, double velocity);
