#include "lwalib.h"
#include <math.h>
#include <time.h>

/* Change the resolution here */
#define WIDTH 800
#define HEIGHT 600

#define PI 3.1415926
#define KX 2*PI/WIDTH
#define KY 2*PI/HEIGHT
#define ITERMAX 100

int main(int argc, char *argv[]) {
	SDL_Surface *screen;
	SDL_Event event;
	float x = 0, y = 0, cx = 0, cy = 0, x1, x2, y1, y2, escaped, i, xleft,yleft,zoomx,zoomy;

	/* For fullscreen, make last parameter SDL_FULLSCREEN */
	screen = LWA_Init(WIDTH, HEIGHT, 8, 0);

	srand(time(NULL));

	printf("Drawing...\n");
	SDL_LockSurface(screen);
	zoomx=1; zoomy=1; xleft=2; yleft=2;
	for(x = 0; x < WIDTH; x++) {
		cx = ((x/WIDTH*4/zoomx))-xleft;
		for(y = 0; y < HEIGHT; y++) {
			/*DrawPixel(screen, x, y, rand(), rand(), rand()); */
			cy = ((y/HEIGHT*4/zoomy))-yleft;
			x1 = x2 = y1 = y2 = escaped = 0;
			for(i = 0; i <= ITERMAX; i++) {
				x2 = x1*x1;
				y2 = y1*y1;
				if((x2+y2) > 4) break;
				y1 = 2*x1*y1 + cy;
				x1 = x2-y2 + cx;
			}

			//printf("Drawing pixel at %d,%d color %d\n", x, y, i);
			DrawPixel(screen, (int)x, (int)y, (Uint32)i);
		}
	}
	SDL_UnlockSurface(screen);
	SDL_UpdateRect(screen, 0, 0, 0, 0);
	printf("Done!  Click to exit.\n");

	while(SDL_WaitEvent(&event)) {
		switch(event.type) {
			case SDL_MOUSEBUTTONDOWN:
				goto exit;
				break;
		}
	}

	exit:
	return 0;
}
