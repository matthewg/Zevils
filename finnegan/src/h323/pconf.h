#ifndef _PCONF_H
#define _PCONF_H

#include <ptlib.h>

struct ProgConf 
{
	enum GkMode { 
		NoGatekeeper,
		RegisterWithGatekeeper
	}; 

	GkMode       gkMode;
	PString      gkAddr;
	PString      gkId;
	PString      fileName;
	PString      voicemail;
	PString      snoozeFile;
	int          timeout;
	int          max_time;
	PStringArray userAliases;
}; 


#define FINH323_VER_MAJOR 1 
#define FINH323_VER_MINOR 0
#define FINH323_VER_STATUS ReleaseCode
#define FINH323_VER_BUILD 0

#endif
