#include <math.h>
#include <float.h>

#ifndef M_PI
#define M_PI            3.14159265358979323846
#define M_TWOPI         (M_PI * 2.0)
#define M_PI_2          1.57079632679489661923
#define M_PI_4          0.78539816339744830962
#endif

#define GRAVITY 9.80665

/* Angle conversions */
double deg2rad(double deg) { return (deg/180)*M_PI; }
double rad2deg(double rad) { return (rad/M_PI)*180; }

double vector_x(double radangle, double magnitude) { return magnitude*cos(radangle); }
double vector_y(double radangle, double magnitude) { return magnitude*sin(radangle); }


double parabola_x_to_y(double x, double radangle, double velocity) {
	return (x*sin(radangle)/cos(radangle) -
		GRAVITY/2 * pow(x/(velocity*cos(radangle)), 2));
}

