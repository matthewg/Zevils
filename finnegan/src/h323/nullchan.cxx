#include "nullchan.h"


// ***********************************************************************

NullChannel::NullChannel(): isOpen(true)
{
	PTRACE(1, "Creating NULL channel");
}


// ***********************************************************************

NullChannel::~NullChannel()
{
	PTRACE(1, "Deleting NULL channel");
}


// ***********************************************************************

BOOL NullChannel::Close()
{
	isOpen = false;
	return true;
}


// ***********************************************************************

BOOL NullChannel::Write(const void *buf, PINDEX len)
{
	lastWriteCount = len;
	writeDelay.Delay(len/2/8);
	return true;
}


// ***********************************************************************

BOOL NullChannel::Read(void *buf, PINDEX len)
{
	memset(buf, 0, len);
	lastReadCount = len;
	readDelay.Delay(len/2/8);
	return true;	
}


// ***********************************************************************

