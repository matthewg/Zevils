#include <ptlib.h>
#include "ep.h"
#include "nullchan.h"
#include "wavchan.h"
#include "connection.h"


// ***********************************************************************

MyEndPoint::MyEndPoint(const ProgConf & conf) : progConf(conf)
{
	PTRACE(1, "endpoint constructor start");
	gotDTMF = FALSE;
	wavchannel = NULL;
	PTRACE(1, "endpoint constructor end");
}


// ***********************************************************************

MyEndPoint::~MyEndPoint() 
{}

// ***********************************************************************


H323Connection *MyEndPoint::CreateConnection(unsigned callReference,
                                        void *userData,
                                        H323Transport *transport,
                                        H323SignalPDU *setupPDU)
{
	return new MyConnection(progConf, *this, callReference);
}

// ***********************************************************************

void MyEndPoint::OnConnectionEstablished(H323Connection & connection, 
						const PString & token)
{
	PTRACE(1, "Connection established, token is " << token);
} 


// ***********************************************************************

void MyEndPoint::OnConnectionCleared(H323Connection &connection, 
						const PString &token)
{
	PTRACE(1, "Connection cleared, token is " << token);
	PTRACE(1, "Reason: " << connection.GetCallEndReason());

	if(gotDTMF) return; //Handle the case of the user sending DTMF, then hanging up

	switch(connection.GetCallEndReason()) {
		case H323Connection::EndedByRemoteUser :
			PTRACE(1, "Peer hung up");
			FCH::exitCode = 3;
			break;
		default:
			PTRACE(1, "Abnormal call termination");
			FCH::exitCode = 1;
			break;
	}

	FCH::terminationSync.Signal();
} 


// ***********************************************************************

BOOL MyEndPoint::OnConnectionForwarded(H323Connection *connection,
						const PString & forwardParty,
						const H323SignalPDU &)
{
	PTRACE(1, "Call forwarded to " << forwardParty);
	/* if it's progConf.voicemail:
		FCH::exitCode = 4;
		FCH::terminationSync.Signal();
	   else:
	*/
	if(MakeCall(forwardParty, currentCallToken)) {
		PTRACE(1, "Call forwarded successfully");
		return TRUE;
	} else {
		PTRACE(1, "Couldn't forward call");
		return FALSE;
	}
}

// ***********************************************************************

bool MyEndPoint::Init() 
{
	// Set user name
	if (!progConf.userAliases.IsEmpty()) 
	{
		SetLocalUserName(progConf.userAliases[0]); 
		for (PINDEX i=1; i<progConf.userAliases.GetSize(); i++)
			AddAliasName(progConf.userAliases[i]); 
	} 
	
	//DisableFastStart(true);	
	//DisableH245Tunneling(true);
	//DisableH245inSetup(true);	
		
	// Codecs
	SpeexNarrow3AudioCapability *speex3Cap; 
	SetCapability(0, 0, speex3Cap = new SpeexNarrow3AudioCapability());
	speex3Cap->SetTxFramesInPacket(5); // For Speex, 1 frame ~ 20 milliseconds
	H323_GSM0610Capability * gsmCap;
	SetCapability(0, 0, gsmCap = new H323_GSM0610Capability);
	gsmCap->SetTxFramesInPacket(4); // For GSM 06.10, 1 frame ~ 20 milliseconds 
	SetCapability(0, 0, new H323_G711Capability(H323_G711Capability::muLaw) );
	SetCapability(0, 0, new H323_G711Capability(H323_G711Capability::ALaw) );
	SetCapability(0, 0, new H323_LPC10Capability(*this) ); 
	
	AddAllUserInputCapabilities(0, 1); 
					
	PTRACE(1, "Capabilities:\n" << setprecision(2) << capabilities); 

	// Start H323 Listener
	/* PIPSocket::Address addr = INADDR_ANY; 
	H323ListenerTCP *listener = new H323ListenerTCP(*this, addr,
							progConf.port);
	if (listener == NULL || !StartListener(listener))
	{	PError << "Unable to start H323 Listener at port "
				<< progConf.port << endl;
		if (listener != NULL)
			delete listener;
		return false;
	} */

	// Gatekeeper registration
	bool gkResult = false; 
	switch (progConf.gkMode)
	{
	case ProgConf::NoGatekeeper: 
		gkResult = true;
		break;
	case ProgConf::RegisterWithGatekeeper:
		gkResult = UseGatekeeper(progConf.gkAddr, progConf.gkId);
		break;
	default:
		break;
	}

	if (!gkResult)
	{
		PError << "Failed to register with gatekeeper" << endl; 
		return false;
	} 
		
	return true;
} 


// ***********************************************************************

BOOL MyEndPoint::OpenAudioChannel(H323Connection &connection, 
						BOOL isEncoding,
						unsigned bufferSize, 
						H323AudioCodec &codec)
{
	//codec.SetSilenceDetectionMode(H323AudioCodec::NoSilenceDetection); 
	if (isEncoding) 
	{	// send audio direction
		PTRACE(1, "opening audio channel");
		wavchannel = new WavChannel(progConf.fileName, connection);
		PTRACE(1, "audio channel opened");
		return codec.AttachChannel(wavchannel, true); 
	}
	else
	{	// receive audio direction
		NullChannel *ch = new NullChannel();
		return codec.AttachChannel(ch, true);
	}
	
	return false;
} 


// ***********************************************************************

BOOL MyEndPoint::OnStartLogicalChannel(H323Connection & connection, 
						H323Channel & channel)
{
	PString dir;
	switch (channel.GetDirection())
	{
	case H323Channel::IsTransmitter :
		dir = "sending";
		break;
	case H323Channel::IsReceiver :
		dir = "receiving";
		break;
	default :
		break;
	}

	PTRACE(1, "Started logical channel " << dir << " " 
		<< channel.GetCapability() );
	return true;
} 


// ***********************************************************************

