#include "finnegan-call-h323.h"
#include "pconf.h"
#include "ep.h"

#ifndef WIN32
#include <signal.h>
#endif

// ***********************************************************************

#ifndef WIN32 
void signalHandler(int sig)
{
	switch(sig)
	{
	case SIGINT:
	case SIGTERM:
		FCH::exitCode = 5;
		FCH::terminationSync.Signal();
	        break;
	default:
		break;
	}
}
#endif 


PSyncPoint FCH::terminationSync;
int FCH::exitCode;

// ***********************************************************************

PCREATE_PROCESS(FCH) 

FCH::FCH(): 
	PProcess("vt", "finnegan-call-h323", FINH323_VER_MAJOR, FINH323_VER_MINOR,
			FINH323_VER_STATUS, FINH323_VER_BUILD)
{ FCH::exitCode = 0; }


// **********************************************************************

FCH::~FCH()
{} // Nothing to do now

// ***********************************************************************

void FCH::printHelp() 
{
	PError << "Available options:\n"
			"-f <file> --file <file>       	         the name of the sound file\n"
			"-d <destination> --dest <destination>   address of party to call; [alias@][transport$]host[:port]\n"
			"-T <timeout> --timeout <timeout>        time to allow for placing a call, in seconds\n"
			"-v <extension> --voicemail <extension>  extension which indicates call has been forwarded to voicemail\n"
			"-s <file> --snoozefile <file>           the name of the sound file to play when snooze is activated\n"
			"-g <addr> --gatekeeper <addr>           the IP address or DNS name of the gatekeeper\n"
			"-G <id> --gatekeeper-id <id>            gatekeeper identifier\n"
			"-h --help                               print this message and exit\n"
			"-n --no-gatekeeper                      do not register with gatekeeper\n"
#if PTRACING
			"-o <file> --output <file>               send trace output to <file>\n"
#endif
#if PTRACING
			"-t --trace                              enable trace, use multiple times for more detail\n"
#endif
			"-u <user> --user <user>                 user name or number (can be used multiple times)\n";
} 


// ***********************************************************************

void FCH::Main() 
{
#ifndef WIN32  
	signal(SIGINT, signalHandler);
	signal(SIGTERM, signalHandler);
#endif 
	PConfigArgs args(GetArguments()); 

	args.Parse( 
			"f-file:"
			"d-destination:"
			"T-timeout:"
			"v-voicemail:"
			"s-snoozefile:"
			"g-gatekeeper:"
			"G-gatekeeper-id:"
			"h-help."
			"n-no-gatekeeper."
#if PTRACING
			"o-output:"
#endif
#if PTRACING
			"t-trace."
#endif
			"u-user:"
		);

	if (!args.HasOption('f') || !args.HasOption('d') || !args.HasOption('T') || !args.HasOption('v') || !args.HasOption('s') || args.HasOption('h')) 
	{
		printHelp();
		return;
	} 

#if PTRACING 
  PTrace::Initialise(args.GetOptionCount('t'),
		args.HasOption('o') ? (const char *)args.GetOptionString('o') : NULL,
		PTrace::Blocks | PTrace::Timestamp | PTrace::Thread | PTrace::FileAndLine);
#endif 

	ProgConf progConf; 

	progConf.gkMode = ProgConf::RegisterWithGatekeeper; 

	if (args.HasOption('n')) 
		progConf.gkMode = ProgConf::NoGatekeeper;

	if (args.HasOption('g'))
	{
		progConf.gkAddr = args.GetOptionString('g');
		progConf.gkMode = ProgConf::RegisterWithGatekeeper;
	}

	if (args.HasOption('G'))
	{
		progConf.gkId = args.GetOptionString('G');
		progConf.gkMode = ProgConf::RegisterWithGatekeeper;
	} 

	progConf.fileName = args.GetOptionString('f'); 
	progConf.voicemail = args.GetOptionString('v');
	progConf.snoozeFile = args.GetOptionString('s');
	if(sscanf(args.GetOptionString('T'), "%d", &progConf.timeout) != 1) {
		printHelp();
		return;
	}

	if (args.HasOption('u')) 
		progConf.userAliases = args.GetOptionString('u').Lines(); 

	// Allocate and initialise H.323 endpoint
	MyEndPoint endpoint(progConf); 

	if (endpoint.Init()) 
	{
		PTRACE(1, "finnegan-call-h323 running");
		endpoint.MakeCall(args.GetOptionString('d'), endpoint.currentCallToken);
		FCH::terminationSync.Wait();
	}

	PTRACE(1, "finnegan-call-h323 shutting down with code " << FCH::exitCode);
	SetTerminationValue(FCH::exitCode);
} 


// ***********************************************************************


