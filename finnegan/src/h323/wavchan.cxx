#include "wavchan.h"
#include "finnegan-call-h323.h"

// ***********************************************************************

WavChannel::WavChannel(const PString & aFileName, H323Connection & aConnection): 
	myConnection(aConnection)
{
	PTRACE(1, "Creating WAV channel");
	loop = TRUE;
	wavFile = NULL;
	openWavFile(aFileName, PFile::ReadOnly, TRUE);
	PTRACE(1, "Created WAV channel for file " << aFileName);
} 


// ***********************************************************************

WavChannel::~WavChannel() 
{
	if(wavFile != NULL) {
		PTRACE(1, "Deleting WAV channel for file " << wavFile->GetName());
		delete wavFile;
		wavFile = NULL;
	}
} 


// ***********************************************************************

void WavChannel::openWavFile(const PFilePath & aFileName, PFile::OpenMode mode, BOOL doLoop)
{
	loop = doLoop;
	PTRACE(1, "Opening WAV file " << aFileName);
	if(wavFile != NULL) {
		wavFile->Close();
		delete wavFile;
	}
	wavFile = new PWAVFile(aFileName, mode);
	PTRACE(1, "File opened");

	if (!wavFile->IsOpen()) 
	{
		PError << "Failed to open WAV file " << aFileName << endl;
		myConnection.ClearCall();
		return;
	} 
	if (wavFile->GetFormat() != PWAVFile::fmt_PCM 
		|| wavFile->GetChannels() != 1
		|| wavFile->GetSampleRate() != 8000
		|| wavFile->GetSampleSize() != 16)
	{
		PError << "WAV file " << aFileName << " has wrong format." << endl;
		wavFile->Close();
		delete wavFile;
		wavFile = NULL;
		myConnection.ClearCall();
		return;
	} 
	PTRACE(1, "Done opening WAV file");
}


// ***********************************************************************

BOOL WavChannel::Close() 
{
	BOOL ret;

	if(wavFile != NULL) {
		ret = wavFile->Close();
		delete wavFile;
		wavFile = NULL;
		return ret;
	} else {
		return FALSE;
	}
} 


// ***********************************************************************

BOOL WavChannel::IsOpen() const 
{
	PTRACE(1, "WavChannnel::IsOpen(): " << wavFile->IsOpen());
	return wavFile->IsOpen();
} 


// ***********************************************************************

BOOL WavChannel::Write(const void *buf, PINDEX len) 
{
	PTRACE(2, "WavChannel::Write():" << len);
	lastWriteCount = len; 
	writeDelay.Delay(len/2/8); 
	return true;
} 


// ***********************************************************************

BOOL WavChannel::Read(void *buf, PINDEX len) 
{
	if (!myConnection.IsEstablished()) 
	{
		PTRACE(2, "WavChannel::Read(): Connection not yet established");
		memset(buf, 0, len);
		lastReadCount = len; 
		readDelay.Delay(lastReadCount/2/8); 
		return true; 
	} 
	
	if (!wavFile->Read(buf, len)) 
		return false;
		
	lastReadCount = wavFile->GetLastReadCount(); 
	readDelay.Delay(lastReadCount/2/8);
	
	if (lastReadCount < len) 
	{
		PTRACE(1, "WavChannel::Read(): end of file reached");
		if(loop) {
			PTRACE(1, "Looping.  Got " << lastReadCount << ", want " << len << " ; reading " << (len-lastReadCount));
			wavFile->SetPosition(0, PFile::Start);
			if(!wavFile->read(((char *)buf)+lastReadCount, len-lastReadCount)) return false;
			lastReadCount = len;
			readDelay.Delay(lastReadCount/2/8);
		} else {
			PTRACE(1, "Not looping - shutting down...");
			myConnection.ClearCall();
			FCH::terminationSync.Signal();
		}
	} 

	return lastReadCount > 0; 
} 


// ***********************************************************************
