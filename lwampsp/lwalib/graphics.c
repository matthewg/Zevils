#include <lwalib.h>
#include <stdarg.h>
#include <string.h>

/* Program MUST initialize these! */
int screen_width = 0;
int screen_height = 0;

/* Screen has upper-left as 0,0; we use lower-left */
int FIX_Y(int y) { return screen_height - y - 1; }

static GLUI *msgbox_parent, *msgbox_box;
static int glut_win;

static int updated_min_x, updated_min_y, updated_max_x, updated_max_y;

SDL_Surface *LWA_Init(int width, int height, int bpp, Uint32 flags) {
	SDL_Surface *screen;

	if(SDL_Init(SDL_INIT_AUDIO|SDL_INIT_VIDEO|SDL_INIT_TIMER) < 0) {
		fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
		exit(1);
	}

	atexit(SDL_Quit);

	if(flags & (SDL_OPENGL|SDL_OPENGLBLIT)) {
		SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 5);
		SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 5);
		SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 5);
		SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
	}

	if(!(flags & SDL_SWSURFACE)) flags |= SDL_HWSURFACE;
	screen = SDL_SetVideoMode(width, height, bpp, flags);
	if(screen == NULL) {
		fprintf(stderr, "Unable to set video: %s\n", SDL_GetError());
		exit(1);
	}
}

void DrawStart(SDL_Surface *screen) {
	SDL_LockSurface(screen);
	updated_min_x = 0;
	updated_min_y = 0;
	updated_max_x = screen_width - 1;
	updated_max_y = screen_height - 1;
}
void DrawEnd(SDL_Surface *screen) {
	SDL_UnlockSurface(screen);
	SDL_UpdateRect(screen, updated_min_x, FIX_Y(updated_min_y), updated_max_x - updated_min_x, updated_max_y - updated_min_y);
}
static void update_coords(int x, int y) {
	if(x < updated_min_x) updated_min_x = x;
	if(x > updated_max_x) updated_max_x = x;
	if(y < updated_min_y) updated_min_y = y;
	if(y > updated_max_y) updated_max_y = y;
}

void DrawPixel(SDL_Surface *screen, int x, int y, Uint8 R, Uint8 G, Uint8 B) {
	Uint32 color = SDL_MapRGB(screen->format, R, G, B);
	DrawPixel(screen, x, y, color);
}

void DrawPixel(SDL_Surface *screen, int x, int y, Uint32 color) {
	int bpp = screen->format->BytesPerPixel;
	Uint8 *bufp = (Uint8 *)screen->pixels + FIX_Y(y)*screen->pitch + x * bpp;

	update_coords(x, y);

	switch(bpp) {
		case 1: { /* 8-bpp */
			*bufp = color;
			break;
		}
		case 2: { /* Probably 15-bpp or 16-bpp */
			*(Uint16 *)bufp = color;
			break;
		}
		case 3: { /* Slow 24-bpp mode, usually not used */
			if(SDL_BYTEORDER == SDL_BIG_ENDIAN) {
				bufp[0] = (color >> 16) & 0xff;
				bufp[1] = (color >> 8) & 0xff;
				bufp[2] = color & 0xff;
			} else {
				bufp[2] = (color >> 16) & 0xff;
				bufp[1] = (color >> 8) & 0xff;
				bufp[0] = color & 0xff;
			}
			break;
		}
		case 4: { /* Probably 32-bpp */
			*(Uint32 *)bufp = color;
			break;
		}
	}
}

void DrawRect(SDL_Surface *screen, int x, int y, int w, int h, Uint32 color) {
	SDL_Rect rect;

	update_coords(x, y);
	update_coords(x+w, y+h);

	rect.x = x;
	rect.y = FIX_Y(y);
	rect.w = w;
	rect.h = h;

	SDL_FillRect(screen, &rect, color);
}
void DrawRect(SDL_Surface *screen, int x, int y, int w, int h, Uint8 r, Uint8 g, Uint8 b) {
	DrawRect(screen, x, y, w, h, SDL_MapRGB(screen->format, r, g, b));
}

void DrawParabola(SDL_Surface *screen, int x0, int y0, double radangle, double velocity, Uint32 color) {
	double Vx = vector_x(radangle, velocity);
	double Vy = vector_y(radangle, velocity);

	/* update_coords is taken care of by DrawLine */

	int prev_x = 0, prev_y = (int) parabola_x_to_y(0 - x0, radangle, velocity);

	int x, y;

	for(x = 0; x < screen_width; x++) {
		y = (int) parabola_x_to_y(x - x0, radangle, velocity);
		if((y < 0) || (y >= screen_height)) continue;
		DrawLine(screen, prev_x, prev_y, x, y, color);
	}
}
void DrawParabola(SDL_Surface *screen, int x0, int y0, double radangle, double velocity, Uint8 r, Uint8 g, Uint8 b) {
	DrawParabola(screen, x0, y0, radangle, velocity, SDL_MapRGB(screen->format, r, g, b));
}


void DrawLine(SDL_Surface *screen, int x0, int y0, int x1, int y1, Uint32 color) {
	double d = sqrt(
		pow(x1 - x0, 2) +
		pow(y1 - y0, 2)
	);

	update_coords(x0, y0);
	update_coords(x1, y1);

	for(double t = 0; t < d; t++) {
		double x = x0 + (x1 - x0)*t/d;
		double y = y0 + (y1 - y0)*t/d;

		if((x >= 0) && (y >= 0) && (x < screen_width) && (y < screen_height))
			DrawPixel(screen, x, y, color);
	}
}
void DrawLine(SDL_Surface *screen, int x0, int y0, int x1, int y1, Uint8 r, Uint8 g, Uint8 b) {
	DrawLine(screen, x0, y0, x1, y1, SDL_MapRGB(screen->format, r, g, b));
}

void DrawBlast(SDL_Surface *screen, int x_center, int y_center, int w, int h, Uint32 color) {
	/* update_coords is handled by DrawLine */

	for(int counter = 0; counter < w; counter++) {
		double x = x_center - w/2;
		double y = cos(counter)*h + y_center;
		if(color == 0) color = rand();
		DrawLine(screen, x_center, y_center, x, y, color);
	}
}
void DrawBlast(SDL_Surface *screen, int x_center, int y_center, int w, int h, Uint8 r, Uint8 g, Uint8 b) {
	DrawBlast(screen, x_center, y_center, w, h, SDL_MapRGB(screen->format, r, g, b));
}

char *float2str(float f) {
	static char buf[1024];
	sprintf(buf, "%f", f);
	buf[1023] = 0;
	return &buf[0];
}

void glut_display() {}

GLUI *LWA_GUI(sdl_handler sdlhandler, int *argc, char **argv) {
	GLUI *glui;

	glutInit(argc, argv);
	glutInitDisplayMode(GLUT_RGB | GLUT_DOUBLE | GLUT_DEPTH);

	glut_win = glutCreateWindow("UI");
	glutHideWindow();
	glutKeyboardFunc(NULL);
	glutDisplayFunc(&glut_display);
	glutReshapeFunc(NULL);
	glutMotionFunc(NULL);
	glutMouseFunc(NULL);

	GLUI_Master.set_glutIdleFunc(sdlhandler);
	glui = GLUI_Master.create_glui("UI", 0);
	glui->set_main_gfx_window(glut_win);
	return glui;
}

void LWA_MsgBox_ok(int id) {
	msgbox_parent->enable();
	msgbox_box->close();
}

void LWA_MsgBox(GLUI *parent, const char *title, const char *fmt, ...) {
	va_list ap;
	char charbuf[32768];
	GLUI *glui;
	/* int x, y, glutwin; */

	msgbox_parent = parent;

	va_start(ap, fmt);
	vsprintf(charbuf, fmt, ap);
	charbuf[32767] = 0;

	parent->disable();
	msgbox_box = GLUI_Master.create_glui((char *) title, 0);
	msgbox_box->set_main_gfx_window(glut_win);
	msgbox_box->add_statictext(charbuf);
	msgbox_box->add_button("OK", -1, &LWA_MsgBox_ok);

	/* x = glutGet(GLUT_SCREEN_WIDTH)/2 - glutGet(GLUT_WINDOW_WIDTH)/2;
	y = glutGet(GLUT_SCREEN_HEIGHT)/2 - glutGet(GLUT_WINDOW_HEIGHT)/2;
	glutwin = glutGetWindow();
	glutSetWindow(msgbox_box->get_glut_window_id());
	glutPositionWindow(x, y);
	glutSetWindow(glutwin); */
}

GLUI_StaticText *LWA_LabelLabel(GLUI *glui, GLUI_Panel *panel, char *text) {
	GLUI_Panel *temp_panel = glui->add_panel_to_panel(panel, "", GLUI_PANEL_NONE);
	glui->add_statictext_to_panel(temp_panel, text);
	glui->add_column_to_panel(temp_panel, false);
	return glui->add_statictext_to_panel(temp_panel, "");
}
