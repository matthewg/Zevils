#ifndef _WAVCHAN_H
#define _WAVCHAN_H

#include <ptlib.h>
#include <h323.h>
#include <ptclib/pwavfile.h>
#include <ptclib/delaychan.h>


// ***********************************************************************

class WavChannel: public PIndirectChannel 
{
  PCLASSINFO(WavChannel, PIndirectChannel);
	H323Connection &myConnection;
	PWAVFile *wavFile;
	PAdaptiveDelay writeDelay;
	PAdaptiveDelay readDelay;
	BOOL loop;

public:
	WavChannel(const PString & aFileName, H323Connection & aConnection);
	~WavChannel();
	virtual void openWavFile(const PFilePath & aFileName, PFile::OpenMode mode, BOOL doLoop);
	virtual BOOL Close(); 
	virtual BOOL IsOpen() const;
	virtual BOOL Read(void *buf, PINDEX len);
	virtual BOOL Write(const void *buf, PINDEX len); 
};


#endif

