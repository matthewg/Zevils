#ifndef _EP_H
#define _EP_H

#include <h323.h>
#include "pconf.h"
#include "wavchan.h"
#include "finnegan-call-h323.h"
#include "connection.h"

class MyEndPoint: public H323EndPoint 
{
	PCLASSINFO(MyEndPoint, H323EndPoint)
	const ProgConf & progConf;  
	WavChannel *wavchannel;

public:
	BOOL gotDTMF;
	MyEndPoint(const ProgConf & conf);
	~MyEndPoint();
	bool Init(void); 
	PString currentCallToken;
	virtual void OnConnectionEstablished(H323Connection &connection, 
					const PString &token);
	virtual void OnConnectionCleared(H323Connection &connection,
					const PString &token);
	virtual BOOL OpenAudioChannel(H323Connection &connection,
					BOOL isEncoding, unsigned bufferSize,
					H323AudioCodec &codec);
	virtual BOOL OnConnectionForwarded(H323Connection *connection,
					const PString & forwardParty,
					const H323SignalPDU &);
	virtual BOOL OnStartLogicalChannel(H323Connection & connection,
					H323Channel & channel); 
	virtual H323Connection* CreateConnection(unsigned callReference,
					void *userData,
					H323Transport *transport,
					H323SignalPDU *setupPDU);
};


#endif
