#include <lwalib.h>
#include <time.h>

/*
	antimissile: Missile defense simulation
	by Matthew Sachs, Daniel Ameli, and Bruce Einsohn
	Created for Lawrence Woodmere Academy's BC Calculus class, 2002

	Researchers at MIT's Defense Lab have just completed a prototype
	ICBA (Intercontinental Ballistic Artillery) system.  Al Qaeda has
	broken into the lab and stolen the plans.  They've had time to
	bring a single ICBA battery online, and they are about to test it
	against Boston.  You must use the prototype ICBA in Boston to
	bring down their projectile.  However, due to environmental
	regulations, you must bring the projectile down not only over
	the Atlantic ocean, but over a precise spot in the Atlantic.
	
	1. Set the distance between Afghanistan and Boston.
	2. Set how long it takes B to fire.
	3. Click "Fire A" to compute the quickest trajectory for A to hit B.
		The trajectory will be drawn on the screen as a red parabola.
	4. Click a spot on the trajectory where B must intersect the missile.
	5. Click "Fire B" to compute the trajectory that B must use.
	6. Click "Go!" to see it in action!

	See antimissile.pdf for mathematical formulas used.
*/

/* Change the resolution here */
#define WIDTH 640
#define HEIGHT 480

#define GRAVITY 9.80665

double distance, isect_x, isect_y, delay, isect_t;
struct icba {
	double velocity, angle;
} site_a, site_b;
struct {
	GLUI_EditText *distance, *delay;
	GLUI_Button *fire_a, *go, *exit;
	GLUI_StaticText *velocity_a, *angle_a, *velocity_b, *angle_b, *time, *animation_time, *isect_x, *isect_y;
	GLUI_Panel *panel_a, *panel_b;
} controls;

SDL_Surface *screen;

GLUI *glui;

void do_draw_fire_a(bool trajectory = true, bool clrscr = true) {
	DrawStart(screen);

	if(clrscr) 
		DrawRect(screen, 0, HEIGHT - 1, WIDTH, HEIGHT, 0, 0, 0);

	DrawRect(screen, 0, 15, 15, 15, 255, 0, 0);	/* Draw A */
	DrawRect(screen, distance, 15, 15, 15, 0, 255, 0); /* Draw B */

	/* Draw A->B trajectory */
	if(trajectory) DrawParabola(screen, 0, 0, deg2rad(site_a.angle), site_a.velocity, 255, 0, 0);

	DrawEnd(screen);

	controls.go->disable();
	
}

void do_fire_b() {
	float dispangle;

	delay = controls.delay->get_float_val();

	controls.isect_x->set_text(float2str(isect_x));
	controls.isect_y->set_text(float2str(isect_y));

	/* Time; t=0 is when a fires */
	isect_t = isect_x/(site_a.velocity*cos(deg2rad(site_a.angle)));
	controls.time->set_text(float2str(isect_t));

	if(isect_t < delay) { /* User didn't give us enough time */
		LWA_MsgBox(glui, "Time Error",
			"The time of intersection, which is %f, must be greater than the delay (%f)",
			isect_t, delay);
		return;
	}

	/* We subtract delay from isect_t since we want it in terms of t=0 when b fires */

	printf("Angle is atan(((%f + (%f)(%f)^2)/2)/(%f-%f)) == atan((%f + %f)/%f) == atan(%f/%f) == atan(%f) == %f\n",
		isect_y, GRAVITY, isect_t - delay, distance, isect_x,
		isect_y, GRAVITY*pow(isect_t - delay, 2)/2, distance - isect_x,
		isect_y + GRAVITY*pow(isect_t - delay, 2)/2, distance - isect_x,
		(isect_y + GRAVITY*pow(isect_t - delay, 2)/2) / (distance - isect_x),
		rad2deg(atan((isect_y + GRAVITY*pow(isect_t - delay, 2)/2) / (distance - isect_x)))
	);

	site_b.angle = rad2deg(atan(
				(isect_y + GRAVITY*pow(isect_t - delay, 2)/2) /
	//              -------------------------------------------------
						(distance - isect_x)
			));
	dispangle = site_b.angle;
	if(dispangle < 0) dispangle = -dispangle;
	if(dispangle < 90) dispangle = 180 - dispangle;
	controls.angle_b->set_text(float2str(dispangle));
	site_b.angle = dispangle;

	printf("Velocity is (%f - %f) / (cos(%f) * %f) == %f / (%f * %f) == %f\n",
		distance, isect_x, deg2rad(site_b.angle), isect_t,
		distance - isect_x, cos(deg2rad(site_b.angle)), isect_t,
		(distance - isect_x) / (cos(deg2rad(site_b.angle)) * isect_t)
	);

	site_b.velocity = 		(distance - isect_x) /
	//                 --------------------------------------------
				(cos(deg2rad(site_b.angle))*(isect_t-delay));
	
	if(site_b.velocity < 0) site_b.velocity = -site_b.velocity;
	controls.velocity_b->set_text(float2str(site_b.velocity));


	DrawStart(screen);
	do_draw_fire_a();
	DrawRect(screen, isect_x-4, isect_y+4, 8, 8, 255, 0, 0);
	DrawParabola(screen, distance, 0, deg2rad(site_b.angle), site_b.velocity, 0, 255, 0);
	DrawEnd(screen);

	controls.go->enable();
}

void sdl_events() {
	SDL_Event event;
	double y;

	while(SDL_PollEvent(&event)) {
		switch(event.type) {
			case SDL_MOUSEBUTTONDOWN:
				/* Make sure we've fired A */
				if(site_a.velocity == 0) break;


				/* Was it near the parabola? */
				y = parabola_x_to_y(
					event.button.x,
					deg2rad(site_a.angle),
					site_a.velocity
				);
				if(abs((int)event.button.y - FIX_Y((int)y)) < 5) {
					controls.panel_b->enable();
					if(isect_x != -1) do_draw_fire_a();
					isect_x = event.button.x;
					isect_y = y;
					do_fire_b();
				}
				break;
		}
	}
}

void clicked_fire_a(int id) {
	double radangle;

	distance = controls.distance->get_float_val();

	/* Pick a random trajectory (that will hit b) */
	site_a.angle = (rand() % 80) + 5;
	radangle = deg2rad(site_a.angle);
	printf("Using angle %f degrees (%f radians); ", site_a.angle, radangle);
	site_a.velocity = sqrt(distance*GRAVITY/(2*cos(radangle)*sin(radangle)));
	printf("velocity = %f*%f/%f = %f\n", GRAVITY, distance, 2*sin(radangle)*cos(radangle), site_a.velocity);
	controls.panel_a->enable();
	controls.velocity_a->set_text(float2str(site_a.velocity));
	controls.angle_a->set_text(float2str(site_a.angle));

	do_draw_fire_a();

	//LWA_MsgBox(glui, "A Fired", "The trajectory of A has been drawn in red.  Click a point on the trajectory to calculate how B should fire to intercept at that point.");
}

void do_projectiles(double t, double *xa, double *ya, double *xb, double *yb, double Vax, double Vay, double Vbx, double Vby) {
	DrawStart(screen);

	/* Clear previous projectiles */
	DrawRect(screen, *xa, *ya, 10, 10, 0, 0, 0);
	DrawRect(screen, *xb, *yb, 10, 10, 0, 0, 0);

	/* The -5 is to center the rectangles */
	*xa = Vax*t - 5;
	*ya = Vay*t - .5*GRAVITY*pow(t, 2) - 5;
	*xb = Vbx*(t - delay) - 5 + distance;
	*yb = Vby*(t - delay) - .5*GRAVITY*pow(t - delay, 2) - 5;

	if(
		(*ya >= 0) &&
		(*ya < HEIGHT) &&
		(*xa >= 0) &&
		(*xa < WIDTH)
	)
		DrawRect(screen, (int) *xa, *ya, 10, 10, 255, 0, 0);
	if(
		(t - delay >= 0) &&
		(*yb >= 0) &&
		(*yb < HEIGHT) &&
		(*xb >= 0) &&
		(*xb < WIDTH)
	)
		DrawRect(screen, (int) *xb, *yb, 10, 10, 0, 255, 0);

	DrawEnd(screen);
}

void clicked_go(int id) {
	SDL_Rect clip_rect;
	double t = 0;
	double Vax, Vay, Vbx, Vby, xa = 0, ya = 0, xb = 0, yb = 0;

	/* Precompute rectangular velocities */
	Vax = vector_x(deg2rad(site_a.angle), site_a.velocity);
	Vay = vector_y(deg2rad(site_a.angle), site_a.velocity);
	Vbx = vector_x(deg2rad(site_b.angle), site_b.velocity);
	Vby = vector_y(deg2rad(site_b.angle), site_b.velocity);

	printf("Components: %f, %f, %f, %f\n", Vax, Vay, Vbx, Vby);

	/* Clear the screen, redraw the batteries */
	do_draw_fire_a(false);


	/* Don't draw over A or B */
	clip_rect.x = 0;
	clip_rect.y = FIX_Y(HEIGHT - 1);
	clip_rect.w = WIDTH;
	clip_rect.h = HEIGHT - 15;

	SDL_SetClipRect(screen, &clip_rect);
	xb = distance;
	for(t = 0; t < isect_t; t += 0.05) {
		controls.animation_time->set_text(float2str(t));
		do_projectiles(t, &xa, &ya, &xb, &yb, Vax, Vay, Vbx, Vby);
		SDL_Delay(5); /* Game time is real time */
	}
	controls.animation_time->set_text(float2str(isect_t));
	do_projectiles(isect_t, &xa, &ya, &xb, &yb, Vax, Vay, Vbx, Vby);
	SDL_SetClipRect(screen, NULL);

	/*DrawStart(screen);
	DrawBlast(screen, xa + 5, ya - 5, 15, 0);
	DrawEnd(screen);*/
}

void clicked_exit(int id) { exit(0); }

int main(int argc, char *argv[]) {
	GLUI_Panel *panel_config, *panel_a, *panel_b, *temp_panel;

	screen_width = WIDTH;
	screen_height = HEIGHT;

	site_a.velocity = site_b.velocity = 0;
	isect_x = -1;

	srand(time(NULL));

	SDL_WM_SetCaption("AntiMissile", NULL);

	/* For fullscreen, make last parameter SDL_FULLSCREEN */
	screen = LWA_Init(WIDTH, HEIGHT, 32, 0);

	/* Set up GUI stuff - function sdl_events will handle SDL events */
	glui = LWA_GUI(&sdl_events, &argc, argv);

	panel_config = glui->add_panel("Configuration");
	controls.distance = glui->add_edittext_to_panel(panel_config, "Distance: ", GLUI_EDITTEXT_FLOAT, &distance);
	controls.distance->set_float_limits(1, FLT_MAX);
	controls.delay = glui->add_edittext_to_panel(panel_config, "Delay: ", GLUI_EDITTEXT_FLOAT, &delay);
	controls.fire_a = glui->add_button_to_panel(panel_config, "Fire A", 0, &clicked_fire_a);

	distance = 500;
	delay = 0;
	controls.distance->set_float_val(500.0);
	controls.delay->set_float_val(0.0);

	controls.panel_a = panel_a = glui->add_panel("Afghanistan");
	panel_a->disable();
	controls.velocity_a = LWA_LabelLabel(glui, panel_a, "Velocity:");
	controls.angle_a = LWA_LabelLabel(glui, panel_a, "Angle:");


	controls.panel_b = panel_b = glui->add_panel("Boston");
	panel_b->disable();
	controls.velocity_b = LWA_LabelLabel(glui, panel_b, "Velocity:");
	controls.angle_b = LWA_LabelLabel(glui, panel_b, "Angle:");

	controls.isect_x = LWA_LabelLabel(glui, panel_b, "x[i]:");
	controls.isect_y = LWA_LabelLabel(glui, panel_b, "y[i]:");
	controls.time = LWA_LabelLabel(glui, panel_b, "t[i]:");


	temp_panel = glui->add_panel("", GLUI_PANEL_NONE);
	controls.go = glui->add_button_to_panel(temp_panel, "Go!", 0, &clicked_go);
	controls.go->disable();
	glui->add_column_to_panel(temp_panel, false);
	controls.exit = glui->add_button_to_panel(temp_panel, "Exit", 0, &clicked_exit);

	temp_panel = glui->add_panel("", GLUI_PANEL_NONE);
	controls.animation_time = LWA_LabelLabel(glui, temp_panel, "t = ");

	/* Begin processing GUI events */
	glutMainLoop();
}
