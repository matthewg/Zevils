/***************************************************************************
    connection.h

    H323Connection with time-out controls

 ***************************************************************************/

#ifndef _CONNECTION_H
#define _CONNECTION_H

#include <h323.h>
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
	~MyConnection();
	virtual void OnEstablished();
	virtual void OnUserInputIndication(const H245_UserInputIndication & pdu);
};


#endif
