/***************************************************************************
    connection.h

    H323Connection with time-out controls

 ***************************************************************************/

#ifndef _CONNECTION_H
#define _CONNECTION_H

#include <h323.h>
#include <h323pdu.h>
#include <q931.h>
#include "pconf.h"
#include "wavchan.h"
#include "finnegan-call-h323.h"
#include "ep.h"

class MyConnection: public H323Connection
{
	PCLASSINFO(MyConnection, H323Connection)
	const ProgConf & progConf;

public:
	MyConnection(const ProgConf & conf, H323EndPoint & thePoint, unsigned callReference);
	virtual void OnEstablished();
	virtual void OnUserInputIndication(const H245_UserInputIndication & pdu);
	virtual BOOL OnReceivedSignalNotify(const H323SignalPDU & pdu);
};


#endif
