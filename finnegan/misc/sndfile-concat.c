/*
** Copyright (C) 1999-2003 Erik de Castro Lopo <erikd@mega-nerd.com>
**
** This program is free software; you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation; either version 2 of the License, or
** (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software
** Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

/* 
** To compile this you will need libsndfile version 1.X.Y. This can either
** be compiled and installed from source, or installed from packages. If 
** you choose the later route, you will also need to install the associated
** libsndfile-devel package. Yuo wil also need to install pkg-config.
**
** To compile:
**
**   gcc `pkg-config --cflags --libs sndfile` sndfile-concat.c -o \
**                sndfile-concat
*/

#include	<stdio.h>
#include	<string.h>
#include	<ctype.h>

#include	<sndfile.h>

#define	 BUFFER_LEN      (1<<16)


static void concat_data_fp (SNDFILE *file2, SNDFILE *file1, int channels) ;
static void concat_data_int (SNDFILE *file2, SNDFILE *file1, int channels) ;

static void
print_usage (const char *argv0)
{	const char *progname ;

	progname = strrchr (argv0, '/') ;
	progname = progname ? progname + 1 : argv0 ;

	printf ("\nUsage : %s <file1> <file2>\n\n", progname) ;
	puts (
		"    Copy audio data from <file2> onto the end of <file1>\n\n"
		"    The joined file will be encoded in the same format as the data\n"
		"    in file1, with all the data in file2 automatically converted\n"
		"    to the correct encoding.\n\n"
		"    The only restriction is that the two files must have the same\n"
		"    number of channels.\n"
		) ;
} /* print_usage */

int
main (int argc, char *argv[])
{	char 		*file1name, *file2name ;
	SNDFILE	 	*file1, *file2 ;
	SF_INFO	 	sfinfo1, sfinfo2 ;

	if (argc != 3)
	{	print_usage (argv [0]) ;
		exit (1) ;
		} ;

	file1name = argv [argc-2] ;
	file2name = argv [argc-1] ;

	if (file1name [0] == '-')
	{	printf ("\nError : Input filename (%s) looks like an option.\n\n", file1name) ;
		print_usage (argv [0]) ;
		exit (1) ;
		} ;

	if (file2name [0] == '-')
	{	printf ("\nError : Output filename (%s) looks like an option.\n\n", file2name) ;
		print_usage (argv [0]) ;
		exit (1) ;
		} ;

	if ((file1 = sf_open (file1name, SFM_RDWR, &sfinfo1)) == NULL)
	{	printf ("\nError : Not able to open input file %s.\n", file1name) ;
		puts (sf_strerror (NULL)) ;
		exit (1) ;
		} ;

	/* Open the output file. */
	if ((file2 = sf_open (file2name, SFM_READ, &sfinfo2)) == NULL)
	{	printf ("\nError : Not able to open output file %s.\n", file2name) ;
		puts (sf_strerror (NULL)) ;
		exit (1) ;
		} ;
	
	if (sfinfo1.channels != sfinfo2.channels)
	{	printf ("\nError : Channel count mismatch. File #1 has %d channels, file #2 has %d.\n", sfinfo1.channels, sfinfo2.channels) ; ;
		exit (1) ;
		} ;

	if ((sfinfo1.format & SF_FORMAT_SUBMASK) == SF_FORMAT_DOUBLE || 
			(sfinfo1.format & SF_FORMAT_SUBMASK) == SF_FORMAT_FLOAT)
		concat_data_fp (file1, file2, sfinfo1.channels) ;
	else
		concat_data_int (file1, file2, sfinfo1.channels) ;

	sf_close (file1) ;
	sf_close (file2) ;

	return 0 ;
} /* main */

static void
concat_data_fp (SNDFILE *rwfile, SNDFILE *rofile, int channels)
{	static double	data [BUFFER_LEN] ;
	int		frames, readcount ;

	frames = BUFFER_LEN / channels ;
	readcount = frames ;
	
	sf_seek (rwfile, 0, SEEK_END) ;

	while (readcount > 0)
	{	readcount = sf_readf_double (rofile, data, frames) ;
		sf_writef_double (rwfile, data, readcount) ;
		} ;

	return ;
} /* concat_data_fp */

static void
concat_data_int (SNDFILE *rwfile, SNDFILE *rofile, int channels)
{	static int	data [BUFFER_LEN] ;
	int		frames, readcount ;

	frames = BUFFER_LEN / channels ;
	readcount = frames ;

	sf_seek (rwfile, 0, SEEK_END) ;

	while (readcount > 0)
	{	readcount = sf_readf_int (rofile, data, frames) ;
		sf_writef_int (rwfile, data, readcount) ;
		} ;

	return ;
} /* concat_data_int */

