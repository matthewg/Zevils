#include "lwalib.h"
#include <math.h>
#include <time.h>

/* Change the resolution here */
#define WIDTH 640
#define HEIGHT 480

int main(int argc, char *argv[]) {
	SDL_Surface *screen;
	SDL_Event event;
	int x, y;

	/* For fullscreen, make last parameter SDL_FULLSCREEN */
	screen = LWA_Init(WIDTH, HEIGHT, 32, 0);

	srand(time(NULL));

	printf("Drawing...\n");
	SDL_LockSurface(screen);
	for(x = 0; x < WIDTH; x++) {
		for(y = 0; y < HEIGHT; y++) {
			DrawPixel(screen, x, y, rand(), rand(), rand());
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
