#include <ptlib.h>
#include "connection.h"

MyConnection::MyConnection(const ProgConf & conf, H323EndPoint & endpoint, unsigned callReference) : H323Connection::H323Connection(endpoint, callReference), progConf(conf)
{
	PTRACE(1, "connection started");
	FCH::alarmTime = progConf.timeout;
	FCH::alarmSync.Signal();
}

void MyConnection::OnEstablished()
{
	PTRACE(1, "connection established");
	FCH::alarmTime = progConf.max_time;
	FCH::alarmSync.Signal();
}

void MyConnection::OnUserInputIndication(const H245_UserInputIndication & pdu)
{
	PTRACE(1, "User input indication - pretending its DTMF");

	MyEndPoint *ep = (MyEndPoint *) &endpoint;

	ep->gotDTMF = TRUE;
	ep->wavchannel->openWavFile(PFilePath(progConf.snoozeFile), PFile::ReadOnly, FALSE);
}

BOOL MyConnection::OnReceivedSignalNotify(const H323SignalPDU & pdu)
{
	PString name;
	Q931 q931;

	q931 = pdu.GetQ931();

	PTRACE(1, "Got signal notify -- call has a (new?) destination");
	if(q931.HasIE(Q931::DisplayIE)) {
		name = q931.GetDisplayName();
		PTRACE(1, "Destination: " << name);

		if(name == progConf.voicemail) {
			PTRACE(1, "Call forwarded to voicemail.");
			FCH::exitCode = 4;
			FCH::terminationSync.Signal();
		}
	} else {
		PTRACE(1, "No display name!");
	}

	return TRUE;   
}
