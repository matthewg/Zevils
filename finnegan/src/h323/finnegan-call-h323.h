#ifndef _FCH323_H
#define _FCH323_H

#include <ptlib.h>

// ***********************************************************************

class FCH: public PProcess  
{
	PCLASSINFO(FCH, PProcess) 
public:
	FCH();
	~FCH();

	virtual void Main(); 
	void printHelp();  
	static int exitCode;
	static PSyncPoint terminationSync;
};  


#endif
