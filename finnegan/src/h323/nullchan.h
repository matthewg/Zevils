#ifndef _NULLCHAN_H
#define _NULLCHAN_H

#include <ptlib.h>
#include <h323.h>
#include <ptclib/pwavfile.h>
#include <ptclib/delaychan.h>


// ***********************************************************************

class NullChannel: public PIndirectChannel
{
  PCLASSINFO(NullChannel, PIndirectChannel);
	PAdaptiveDelay writeDelay;
	PAdaptiveDelay readDelay;
	bool isOpen;
public:
	NullChannel();
	~NullChannel();
	virtual BOOL Close(); 
	virtual BOOL IsOpen() const { return isOpen; };
	virtual BOOL Read(void *buf, PINDEX len);
	virtual BOOL Write(const void *buf, PINDEX len); 
};


#endif

