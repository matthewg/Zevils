package Toc;

use Carp qw(cluck);
use Data::Dumper;
use IO::Socket;
use HTML::FormatText;
use HTML::Parse;
@ISA = qw(Exporter);
@EXPORT_OK = qw($err set_directory remove_permit remove_deny update_config signoff update_buddy get_config aim_strerror sflap_get signon chat_join chat_accept chat_invite chat_leave set_away get_info set_info get_directory directory_search message add_buddy remove_buddy add_permit add_deny evil permtype chat_send chat_whisper normalize set_config parseclass roast_password sflap_do quote sflap_encode sflap_put conf2str str2conf txt2html);
%EXPORT_TAGS = (all => [@EXPORT_OK]);
$VERSION = '0.80';

=pod

=head1 NAME

Toc - Do stuff with AOL's Toc protocol, which is what AOL Instant Messenger and its ilk users.
AOL, AOL Instant Messenger, AIM, and Toc are probably registered trademarks of America Online.

=item update_config(HANDLE, CONF)

Call this when you get a toc CONFIG message.

=cut

sub update_config($$) {
	my($handle, $conf) = @_;
	
	(undef, $config{_hnick($handle)}) = str2conf($conf);
	
}

=pod

=item signoff(HANDLE)

Signoff from AIM.

=cut

sub signoff($) {
	my($handle) = shift;
	delete $config{_hnick($handle)};
	$handle->close if $handle;
}

=pod

=item update_buddy(AIM_SCREENNAME, NICK, CLASS, EVIL_LEVEL, SIGNON_TIME, IDLE_TIME, ONLINE?)

Call this when you get an UPDATE_BUDDY from TOC.  It's not really necessary - it just stored the info in the user's config-hash as maintained internally by Toc.pm and returned via get_config.

=cut

sub update_buddy($$$$$$$) {
	my($sn, $nick, $class, $evil, $signon, $idle, $online) = @_;

	if($online) {
		$config{$sn}->{Buddies}{$nick}{class} = $class;
		$config{$sn}->{Buddies}{$nick}{evil} = $evil;
		$config{$sn}->{Buddies}{$nick}{signon} = $signon;
		$config{$sn}->{Buddies}{$nick}{idle} = $idle;
	} else {
		delete $config{$sn}->{Buddies}{$nick}{class};
		delete $config{$sn}->{Buddies}{$nick}{evil};
		delete $config{$sn}->{Buddies}{$nick}{signon};
		delete $config{$sn}->{Buddies}{$nick}{idle};
	}
	$config{$sn}->{Buddies}{$nick}{online} = $online;
}

=item get_config(NICK)
Returns a config-hash of the type returned by signon for NICK.

=cut

sub get_config($) { return $config{$_[0]}; }

=pod

=item aim_strerror(ERRNO, PARAMS)

Takes a Toc error number and returns a string describing the error.
Error messages are taken from PROTOCOL.

=cut

sub aim_strerror($$) {
	my($errno, $params) = @_;
	if($errno == 901) {
		return "$params not currently available";
	} elsif($errno == 902) {
		return "Warning of $params not currently available";
	} elsif($errno == 903) {
		return "A message has been dropped, you are exceeding the server speed limit";
	} elsif($errno == 950) {
		return "Chat in $params is unavailable.";
	} elsif($errno == 960) {
		return "You are sending message too fast to $params";
	} elsif($errno == 961) {
		return "You missed an im from $params because it was too big.";
	} elsif($errno == 962) {
		return "You missed an im from $params because it was sent too fast.";
	} elsif($errno == 970) {
		return "Directory failure";
	} elsif($errno == 971) {
		return "Directory error: Too many matches";
	} elsif($errno == 972) {
		return "Directory error: need more qualifiers";
	} elsif($errno == 973) {
		return "Directory service temporarily unavailable";
	} elsif($errno == 974) {
		return "Email lookup restricted";
	} elsif($errno == 975) {
		return "Keyword ignored";
	} elsif($errno == 976) {
		return "No keywords";
	} elsif($errno == 977) {
		return "Person has no directory info";
	} elsif($errno == 978) {
		return "Country not supported";
	} elsif($errno == 979) {
		return "Failure unknown to $params";
	} elsif($errno == 980) {
		return "Incorrect nickname or password.";
	} elsif($errno == 981) {
		return "The service is temporarily unavailable.";
	} elsif($errno == 982) {
		return "Your warning level is currently too high to sign on.";
	} elsif($errno == 983) {
		return "You have been connecting and disconnecting too frequently.  Wait 10 minutes and try again.  If you continue to try, you will need to wait even longer.";
	} elsif($errno == 989) {
		return "An unknown signon error has occured $params";
	} else {
		return "Unknown error $errno:$params";
	}
}

=pod

=item sflap_get(HANDLE)

Gets an SFLAP-encoded message from HANDLE.  Returns the message.

=cut

sub sflap_get($) {
	my($handle, $type, @hdr, @signon_hdr) = shift;
	my($buff, $len, $connection);
	#get 6 chars
	$err = "Undefined handle";
	return -1 unless $handle;
	$err = undef;
	$handle->read($buff, 6) or $err = "Couldn't read: $!";
	#decode the SFLAP header

	#get $len chars
	@hdr = unpack("CCnn", $buff);

	if($hdr[1] == 1) {
		$type = "signon";
	} elsif($hdr[1] == 2) {
		$type = "data";
	} else { $type = $hdr[1];
	}
	debug_print("sflap_get: ast=$hdr[0] type=$type seqno=$hdr[2] len=$hdr[3]\n", "sflap", 1);
	if($type eq "signon") {
		@signon_hdr = unpack("NnnA*", $buff);
		debug_print("\tsignon: ver=$signon_hdr[0] tag=$signon_hdr[1], namelen=$signon_hdr[2], name=$signon_hdr[3]\n", "sflap", 2);
	}

	$len = $hdr[3];
	$handle->read($buff, $len) or $err = "Couldn't read: $!";
	chomp $buff;

	debug_print("\tdata: $buff\n", "sflap", 2) if $type ne "signon";

	if($err) {
		$handle->close if $handle;
		return -1;
	}
	return $buff;
}

=pod

=item signon(NICK, PASSWORD[, STATUS])

Returns an array consisting of a return value (0 for success, -1 for failure), an IO::Socket::INET object, 
and a group configuration hash.  $Net::Toc::err will be set to the error message if there
is an error.

The IO::Socket::INET object returned by this function is a bit special, so if you plan on using your own IO::Handle
object with the Net::Toc functions, pay attention.  The IO::Socket object is based around a globref.  What that means,
without going into too many technical details, is that there's a hash (and a scalar and an array) hiding behind every
IO::Handle.  You can store things in that hash just like any other hash.  This is documented in perldoc IO::Handle, and
IO::Socket makes use of it.  We store the username in the hash in key net_toc_username, so make sure that you do that for
any IO::Handle's you try to use with Net::Toc.

The group configuration hash has three keys, Buddies, permit, and deny.
permit and deny are hashes whose keys are the members of the permit and deny lists.
Buddies is a hash whose keys are themselves hashes (dizzy yet? ;P)
The keys for those hashes are group and online.  group is 0 if the buddy is offline and 0 if the buddy is online.  It will
always be 0 upon returning from signon.  group is the group the buddy is in, which defaults to Buddies.

The third (optional) parameter, status, is a CODE-ref (a reference to a subroutine, ie \&func, or an anonymous subroutine,
ie sub { BLOCK }).  Whenever signon wishes to pass the user a message, such as "Connecting to Toc", the code will be called
with $_[0] set to the text of the message.

=cut

sub signon($$;&) {
	my($username, $password, $status) = @_;
	my($socket, $msg, $config, $buddy);

	unless($username and $password) {
		$err = "You must provide a username and password!";
		return -1;
	}

	debug_print("$username is trying to sign on", "signon", 1);

	&$status("Connecting to toc.oscar.aol.com:9898") if ref $status eq "CODE";
	$socket = IO::Socket::INET->new('toc.oscar.aol.com:9898') or do {
		debug_print("$username couldn't switch to SFLAP mode: $@", "signon", 1);
		$err = "Couldn't create socket: $@";
		return -1;
	};

	debug_print("$username has established a connection to toc.oscar.aol.com", "signon", 2);

	${*$socket}{'net_toc_username'} = $username;
	&$status("Connected, switching to FLAP encoding") if ref $status eq "CODE";
	$socket->print("FLAPON\r\n\r\n") or do {
		debug_print("$username couldn't switch to SFLAP mode: $@", "signon", 1);
		$err = "Couldn't write to socket: $@";
		return -1;
	};

	debug_print("$username is now in SFLAP mode", "signon", 2);

	&$status("Switching to SFLAP protocol") if ref $status eq "CODE";
	$msg = sflap_get($socket);
	if($err) {
		return -1;
	}
	if($msg =~ /^ERROR:(.+):?(.*)/) {
		debug_print("$username had an error after switching into SFLAP: $1 (" . aim_strerror($1, $2) . ")", "signon", 1);
		$err = "Error $1: " . aim_strerror($1, $2);
		return -1;
	}
	&$status("We are now in flap mode, signing on") if ref $status eq "CODE";
	sflap_put($socket, sflap_encode($username, 1)) or do {
		debug_print("$username had an error while trying to sign on", "signon", 1);
		$err = "Couldn't write to socket: $@";
		return -1;
	};

	debug_print("$username has sent the signon packet", "signon", 2);

	&$status("Sent login packet, doing toc_signon") if ref $status eq "CODE";
	$msg = quote("toc_signon login.oscar.aol.com 1234 $username  " . roast_password($password) . " english ") . "\"AIMIRC:\\\$Rev" . "ision: ${VERSION} \\\$\"";
	sflap_put($socket, sflap_encode($msg, 0, 1)) or do {
		debug_print("$username had an error while trying to toc_signon: $@", "signon", 1);
		$err = "Couldn't write to socket: $@";
		return -1;
	};

	debug_print("$username has sent toc_signon", "signon", 2);

	&$status("Sent toc_signon, getting config") if ref $status eq "CODE";
	$msg = sflap_get($socket);
	if($err) {
		return -1;
	}
	if($msg =~ /^ERROR:(.+):?(.*)/) {
		$err = "Error $1: " . aim_strerror($1, $2);
		debug_print("$username had an error after toc_signon: $err", "signon", 1);
		return -1;
	}
	$msg = sflap_get($socket);
	return -1 if $err;
	if($msg =~ /^ERROR:(.+):?(.*)/) {
		$err = "Error $1: " . aim_strerror($1, $2);
		debug_print("$username had an error after toc_signon and get: $err", "signon", 1);
		return -1;
	}
	$config = str2conf($msg);
	$config{$username} = $config;
	$config{$username}{permtype} = $permtype;

	sflap_do($socket, "toc_init_done");

	_setup($socket);
	debug_print(_hnick($socket) . " has succesfully signed on", "signon", 1);

	return (0, $socket, $config);
}

=pod

=item chat_join(HANDLE, NAME)

Join/create chat NAME.  Don't use this to reply to an invite - use chat_accept instead

=cut

sub chat_join($$) {
	my($handle, $chatname, $msg) = @_;
	debug_print(_hnick($handle) . " is joining $chatname", "chat", 1);
	$msg = quote("toc_chat_join 4 ") . "\"" . quote($chatname) . "\"";
	sflap_put($handle, sflap_encode($msg, 0, 1));
}

=pod

=item chat_accept(HANDLE, CHAT_ID)

Accept an invitation to chat CHAT_ID

=cut

sub chat_accept($$) {
	my($handle, $chatid) = @_;
	debug_print(_hnick($handle) . " is accepting an invite to $chatid", "chat", 1);
	sflap_do($handle, "toc_chat_accept $chatid");
}

=pod

=item chat_invite(HANDLE, CHAT_ID, MESSAGE, BUDDIES)

Invite BUDDIES [a list - so you can do chat_invite($handle, $chat, $msg, "buddy1", "buddy2", ...)] into CHAT_ID with message MESSAGE.

=cut

sub chat_invite($$$@) {
	my($handle, $chat, $text, @buddies) = @_;
	my($msg);

	debug_print(_hnick($handle) . " is inviting " . join(" ", @buddies) . " into chat $chat. Reason: $text.", "chat", 2);
	$msg = quote("toc_chat_invite $chat ") . "\"" . quote(txt2html($text)) . "\"" . quote(" ") . quote(join(" ", @buddies));
	sflap_put($handle, sflap_encode($msg, 0, 1));
}

=pod

=item chat_leave(HANDLE, CHAT_ID)

Leave chat CHAT_ID

=cut

sub chat_leave($$) {
	my($handle, $chat) = @_;

	debug_print(_hnick($handle) . " is leaving chat $chat", "chat", 2);
	sflap_do($handle, "toc_chat_leave $chat");
}

=pod

=item set_away(HANDLE[, MESSAGE])

Set away message to MESSAGE.  If MESSAGE is not given, the away message is cleared.

=cut

sub set_away($;$) {
	my($handle, $message) = @_;
	my($msg);

	$msg = quote("toc_set_away");
	if($message) {
		$msg .= " \"" . quote(txt2html($message)) . "\"";
	}

	sflap_put($handle, sflap_encode($msg, 0, 1));
}

=pod

=item get_info(HANDLE, NICK)

Tell TOC that you want the info for NICK.  TOC will give you a URL to go to to get the info.

=cut

sub get_info($$) {
	my($handle, $nick) = @_;

	sflap_do($handle, "toc_get_info $nick");
}

=pod

=item set_info(HANDLE, INFO)

Set info for the user connected to AIM via HANDLE. 

=cut

sub set_info($$) {
	my($handle, $info) = @_;

	sflap_put($handle, sflap_encode(quote("toc_set_info ") . "\"" . quote(txt2html($info)) . "\"", 0, 1));
}

=pod

=item get_directory(HANDLE, NICK)

Tell TOC that you want the directory info for NICK.  TOC will give you a URL to go to to get the info.

=cut

sub get_directory($$) {
	my($handle, $nick) = @_;
	sflap_do($handle, "toc_get_dir $nick");
}

=pod

=item set_directory(HANDLE, HASH)

Sets directory info for user connected via HANDLE.
Valid keys for HASH:
	first_name
	middle_name
	last_name
	maiden_name
	city
	state
	country
	allow_web_searches
If allow_web_searches is true, directory info can be retrieved over the web, not just via TOC.

=cut

sub set_directory($%) {
	my($handle, %info) = @_;
	my($msg, $elem);

	$msg = quote(join(":", $info{first_name}, $info{middle_name}, $info{last_name}, $info{maiden_name}, $info{city}, $info{state}, $info{country}, $info{allow_web_searches} ? "Y" : ""));
	$msg = "toc_set_dir $msg";
	sflap_put($handle, sflap_encode($msg, 0, 1));
}

=pod

=item directory_search(HANDLE, HASH)

Search the directory.
This is very similar to set_directory.

=cut

sub directory_search($%) {
	my($handle, %info) = @_;
	my($msg, $elem);

	$msg = quote(join(":", $info{first_name}, $info{middle_name}, $info{last_name}, $info{maiden_name}, $info{city}, $info{city}, $info{state}, $info{country}, $info{allow_web_searches} ? "Y" : ""));
	$msg = "toc_dir_search $msg";
	sflap_put($handle, sflap_encode($msg, 0, 1));
}

=pod

=item message(HANDLE, NICK, MESSAGE[, AUTO?])

Send an IM to NICK.  If AUTO, the message is an automated reply.

=cut

sub message($$$;$) {
	my($handle, $target, $text, $auto) = @_;
	my($msg);

	$auto ||= 0;

	debug_print(_hnick($handle) . " is sending an IM to $target: $text", "IM", 2);
	$msg = quote("toc_send_im $target ") . "\"" . quote(txt2html($text)) . "\"";
	$msg .= " auto" if $auto;
	sflap_put($handle, sflap_encode($msg, 0, 1));
}

=pod

=item add_buddy(HANDLE, NICK[, GROUP[, NO_SET_CONFIG]])

Add NICK to the buddy list.  This automatically does a set_config so that the change is saved.
The optional parameter GROUP specifies which group to place the buddy in.  Returns the result of set_config.

If the NO_SET_CONFIG parameter is present, the user's configuration will not be resent to the Toc server.
This is very useful for when you've just gotten a config from Toc, such as upon signon.

=cut

sub add_buddy($$;$$) {
	my($handle, $nick, $group, $noconfig) = @_;
	$group ||= "Buddies";
	debug_print(_hnick($handle) . " is adding $nick to buddylist", "buddies", 1);
	delete $config{_hnick($handle)}->{deny}{$nick};
	sflap_do($handle, "toc_add_buddy $nick");
	$config{_hnick($handle)}->{Buddies}{$nick}{group} = $group;
	$config{_hnick($handle)}->{Buddies}{$nick}{online} ||= 0;
	set_config($handle, $config{_hnick($handle)}) unless $noconfig;
}

=pod

=item remove_buddy(HANDLE, NICK)

Remove NICK from the buddy list.

=cut

sub remove_buddy($$) {
	my($handle, $nick) = @_;
	debug_print(_hnick($handle) . " is removing $nick from the buddylist", "buddies", 1);
	sflap_do($handle, "toc_remove_buddy $nick");
	delete $config{_hnick($handle)}->{Buddies}{$nick};
	set_config($handle, $config{_hnick($handle)});
}

=pod

=item add_permit(HANDLE, NICK[, NO_SET_CONFIG])

Add NICK to the permit list.  Returns the result of set_config.
See add_buddy for information about NO_SET_CONFIG.

=cut

sub add_permit($$;$) {
	my($handle, $nick, $noconfig) = @_;
	debug_print(_hnick($handle) . " is adding $nick to permit list", "buddies", 1);
	sflap_do($handle, "toc_add_permit $nick");
	delete $config{_hnick($handle)}->{deny}{$nick};
	$config{_hnick($handle)}->{permit}{$nick} = 1;
	set_config($handle, $config{_hnick($handle)}) unless $noconfig;
}

=pod

=item remove_permit(HANDLE, NICK)

Remove NICK from the permit list.

=cut

sub remove_permit($$) {
	my($handle, $nick) = @_;
	debug_print(_hnick($handle) . " is removing $nick from permit list", "buddies", 1);
	delete $config{_hnick($handle)}->{permit}{$nick};
	set_config($handle, $config{_hnick($handle)});
}

=pod

=item add_deny(HANDLE, NICK[, NO_SET_CONFIG])

Add NICK to the deny list.  Returns the result of set_config.
See add_buddy for information about NO_SET_CONFIG.

=cut

sub add_deny($$;$) {
	my($handle, $nick, $noconfig) = @_;
	debug_print(_hnick($handle) . " is adding $nick to deny list", "buddies", 1);
	sflap_do($handle, "toc_add_deny $nick");
	delete $config{_hnick($handle)}->{permit}{$nick};
	$config{_hnick($handle)}->{deny}{$nick} = 1;
	set_config($handle, $config{_hnick($handle)}) unless $noconfig;
}


=item remove_deny(HANDLE, NICK)

Remove NICK from the deny list.

=cut

sub remove_deny($$) {
	my($handle, $nick) = @_;
	debug_print(_hnick($handle) . " is removing $nick from deny list", "buddies", 1);
	delete $config{_hnick($handle)}->{deny}{$nick};
	set_config($handle, $config{_hnick($handle)});
}

=pod

=item evil(HANDLE, NICK[, ANONYMOUS?])

Warns (aka "evils") NICK, optionally anonymously.

=cut

sub evil($$;$) {
	my($handle, $nick, $anon, $msg) = @_;
	$msg = "toc_evil $nick ";
	if($anon) {
		$msg .= "anon";
	} else {
		$msg .= "norm";
	}
	sflap_do($handle, $msg);
}

=pod

=item permtype(HANDLE[, PERMTYPE])

If no PERMTYPE is given, gets current PERMTYPE.
If you do give a PERMTYPE, sets the current PERMTYPE.
PERMTYPE is the Toc permit type.

=cut

sub permtype($;$) {
	my($handle, $permtype) = @_;
	if($permtype) {
		$config{_hnick($handle)}->{permtype} = $permtype;
		set_config($handle, $config{_hnick($handle)});
		return $permtype;
	} else {
		return $config{_hnick($handle)}->{permtype} || 4;
	}
}

=pod

=item chat_send(HANDLE, CHAT_ID, TEXT)

Send TEXT to chat CHAT_ID.  The AIM user connected via HANDLE must already have joined CHAT_ID.

=cut

sub chat_send($$$) {
	my($handle, $chat, $text) = @_;
	my($msg);

	debug_print(_hnick($handle) . " is telling chat $chat: $text", "chat", 2);
	$msg = quote("toc_chat_send $chat ") . "\"" . quote(txt2html($text)) . "\"";
	sflap_put($handle, sflap_encode($msg, 0, 1));
}

=pod

=item chat_whisper(HANDLE, CHAT_ID, USER, TEXT)

Send a whisper to USER in CHAT_ID.

=cut

sub chat_whisper($$$$) {
	my($handle, $chat, $user, $text) = @_;
	my($msg);

	debug_print(_hnick($handle) . " is whispering to $user in chat $chat: $text", "chat", 2);
	$msg = quote("toc_chat_whisper $chat $user ") . "\"" . quote(txt2html($text)) . "\"";
	sflap_put($handle, sflap_encode($msg, 0, 1));
}

=pod

=item normalize(STRING)

Strips spaces from STRING and convert to lowercase.  Nicknames should be normalized before being sent to Toc.  You shouldn't need to call this directly.
Returns the normalized string.

=cut

sub normalize($) { $_[0] =~ tr/ //d; return lc($_[0]); }

=pod

=item set_config(HANDLE, CONFIG)

Sets configuration from the config-hash (in the format that you get from get_config) CONFIG.
You shouldn't need to call this unless you are directly accessing the config-hash.
In all other cases, it is called automatically when needed.  Returns the result of sflap_do.

=cut

sub set_config($$) {
	my($handle, $config) = @_;
	$config{_hnick($handle)} = $config;

	sflap_put($handle, sflap_encode(conf2str($config), 0, 1));
	_setup($handle);
}
sub _setup($) { 
	my $handle = shift;
	my($ppl, $msg, $buddy, $config);

	$config = $config{_hnick($handle)};

	$msg = "toc_add_buddy";
	foreach $buddy(keys %{$config->{Buddies}}) { $buddy = normalize($buddy); $msg .= " $buddy"; }
	sflap_do($handle, $msg);

	if($config{_hnick($handle)}->{permtype} == 3 or $config{_hnick($handle)}->{permtype} == 1) {
		sflap_do($handle, "toc_add_permit");
	} else {
		sflap_do($handle, "toc_add_deny");
	}

	$msg = "toc_add_permit";
	foreach $buddy(keys %{$config->{permit}}) { $buddy = normalize($buddy); $msg .= " $buddy"; }
	sflap_do($handle, $msg);

	$msg = "toc_add_deny";
	foreach $buddy(keys %{$config->{deny}}) { $buddy = normalize($buddy); $msg .= " $buddy"; }
	sflap_do($handle, $msg);

}

=pod

=item parseclass(STRING)

Parse Toc class string.  You shouldn't need to call this directly.
Returns the parsed string.

=cut

sub parseclass($) {
	my($class) = shift;
	my($ret);
	$ret = "On AOL, " if substr($class, 0, 1) eq "A";
	$ret .= "Oscar Admin, " if substr($class, 1, 1) eq "A";
	$ret .= "Oscar Trial, " if substr($class, 1, 1) eq "U";
	$ret .= "Oscar, " if substr($class, 1, 1) eq "O";
	$ret .= "Unavailable, " if substr($class, 2, 1) eq "U";
	chop $ret; chop $ret; return $ret;
}

=pod

=item roast_password(STRING)

Roast Toc password STRING.  Toc passwords must be roasted before being sent to Toc.
Roasting performs trivial encryption.  It's easily reversable, but hey, it's better than nothing!
You shouldn't need to call this directly.  Returns the roasted password.

=cut

sub roast_password($) {
	my $pass = shift;
	$roast = "Tic/Toc";
	$pos = 2;
	$rp = "0x";
	for($x = 0; ($x < 150) && ($x < length($pass)); $x++) {
		substr($rp, $pos, 1) = sprintf("%02x", ord(substr($pass, $x, 1)) ^ ord(substr($roast, $x % length($roast), 1)));
		$pos += length(sprintf("%02x", ord(substr($pass, $x, 1)) ^ ord(substr($roast, $x % length($roast), 1))));
	}
	return $rp;
}


=pod

=item sflap_do(HANDLE, STRING)

sflap-encode STRING and send it to Toc via HANDLE.
You should use this instead of sflap_encode and $handle->print since it incrememnts the
handle's sequence number properly.  But you probably shouldn't be talking directly to Toc
anyway - that's what this module is for!  Returns the result of sflap_put.

=cut

sub sflap_do($$) {
	my($handle, $string) = @_;
	sflap_put($handle, sflap_encode($string));
}

=pod

=item quote(STRING)

Performs quoting on STRING as described in the "Client -> TOC" section of PROTOCOL.
\, $, [, ], (, ), #, {, }, ", ', and ` all have backslashes (\) placed before them.
You probably don't need to call this directly.  Returns the quoted string.

=cut

sub quote($) {
	my $msg = shift;
	$msg =~ s/\\/\\\\/g;
	$msg =~ s/\$/\\\$/g; $msg =~ s/\[/\\\[/g; $msg =~ s/]/\\]/g;
	$msg =~ s/\(/\\(/g; $msg =~ s/\)/\\)/g; $msg =~ s/\#/\\\#/g;
	$msg =~ s/\{/\\\{/g; $msg =~ s/\}/\\\}/g; $msg =~ s/\"/\\\"/g;
	$msg =~ s/\'/\\\'/g; $msg =~ s/\`/\\\`/g;
	return $msg;
}

=pod

=item sflap_encode(MESSAGE[, SIGNON?[, NOQUOTE?]])

SFLAP-encodes MESSAGE.  If signon is true, message is the Toc username and it will be encoded
as a special SIGNON packet.  Otherwise it is encoded as a DATA packet.  If noquote is true, the
message is presumed to have already been escaped (ala the quote function).  Otherwise, the message
will be passed through the quote function.  You probably don't need to call this directly.
Returns the encoded message.

=cut

sub sflap_encode($;$$) {
	my($msg, $signon, $noquote) = @_;
	my($ret, $so);
	$signon ||= 0;
	$msg = quote $msg unless $noquote;

	#We set the true sequence number in sflap_put.

	if($signon) {
		$so = pack("Nnn", 1, 1, length($msg));
		$ret = pack("CCnn", ord("*"), 1, 0, length($so) + length($msg));
		$ret .= $so;
	} else {
		$msg .= chr(0);
		$ret = pack("CCnn", ord("*"), 2, 0, length($msg));
	}
	return $ret . $msg;
}

=pod

=item sflap_put(HANDLE, MESSAGE)

Sends a message (which must already be SFLAP-encoded) to Toc
via HANDLE.  You probably don't need to call this directly.
Returns 1 if successfull, -1 if there's an error.  An error message
will be stored in $Net::Toc::err if an error occurs.

=cut

sub sflap_put($$) {
	my($handle, $msg, $type, @signon_hdr) = @_; #msg must already be encoded

	$err = "Undefined handle";
	return -1 unless $handle;
	$err = undef;

	my($seqno) = ++${*$handle}{'net_toc_seqno'};
	my @hdr = unpack("CCnn", substr($msg, 0, 6));
	$hdr[2] = $seqno;

	if($hdr[1] == 1) {
		$type = "signon";
	} elsif($hdr[1] == 2) {
		$type = "data";
	} else { $type = $hdr[1];
	}
	debug_print("sflap_put: ast=$hdr[0] type=$type seqno=$hdr[2] len=$hdr[3]\n", "sflap", 1);
	$foo = $msg;
	substr($foo, 0, 6) = "";
	if($type eq "signon") {
		@signon_hdr = unpack("NnnA*", $foo);
		debug_print("\tsignon: ver=$signon_hdr[0] tag=$signon_hdr[1], namelen=$signon_hdr[2], name=$signon_hdr[3]\n", "sflap", 2);
	} else {
		debug_print("\tdata: $foo\n", "sflap", 2);
	}

	substr($msg, 0, 6) = pack("CCnn", @hdr);

	$handle->print($msg) or $err = "Couldn't write: $!";
	if($err) {
		$handle->close if $handle;
		return -1;
	}
	return 1;
}	

=pod

=item conf2str(CONFIG-HASHREF)

Takes a hashref to a config-hash (in the same format returned by signon) and a permit
type (the same one that signon returns) and makes a string of the type that Toc wants for
the toc_set_config command.  You almost definately should not be calling this directly, but
instead calling set_config.  Returns the toc_set_config-format string.

=cut

sub conf2str(\%) {
	my($config) = @_;
	my($msg, %config, $group, $buddy, $permtype, %groups);
	$permtype = $config->{permtype};
	$permtype ||= 4;
	$msg = "m $permtype\n";
	foreach $buddy (keys %{$config->{Buddies}}) {
		$group = $config->{Buddies}{$buddy}{group};
		push @{$groups{$group}}, $buddy;
	}
	foreach $group (sort keys %groups) {
		next if $group eq "permit" or $group eq "deny" or $group eq "permtype";
		next if $group eq "permtype" or $group eq "groups";
		$msg .= "g $group\n";
		foreach $buddy (sort @{$groups{$group}}) {
			$msg .= "b $buddy\n";
		}
	}
	foreach $buddy (keys %{$config->{permit}}) {
		$msg .= "p $buddy\n";
	}
	foreach $buddy (keys %{$config->{deny}}) {
		$msg .= "d $buddy\n";
	}
	$msg = "toc_set_config {" . quote($msg) . "}";
	#warn "$msg\n";
	debug_print("conf2str: " . Dumper($config), "config", 2);
	return $msg;
}

=pod

=item str2conf(STRING)

Takes a string in the format that toc_set_config wants and that the signon process
produces and returns a config-hashref of the type returned by signon.
You almost definately should not be calling this directly - let signon handle things.  Actually, I suppose you
would use str2conf/conf2str to export and import a Toc configuration.

=cut

sub str2conf($) {
	my($confstr) = shift;
	my($line, $type, $val, $config, $permtype, $currgroup);
	#warn "Confstr: $confstr\n";
	my @lines = split(/\n/, $confstr);
	$lines[0] =~ s/^CONFIG://;
	foreach $line(@lines) {
		chomp $line;
		#warn "Got $line\n";
		$line =~ /^(.) (.+)/;
		$type = $1; $val = $2;
		#warn "Type $type, val $val\n";
		if($type eq "g") {
			$currgroup = $val;
		} elsif($type eq "b") {
			#warn "$val added to group $currgroup\n";
			$val = lc($val);
			$config->{Buddies}{$val}{group} = $currgroup;
			$config->{Buddies}{$val}{online} ||= 0;
		} elsif($type eq "p") {
			#warn "$val added to permit list\n";
			$val = lc($val);
			$config->{permit}{$val} = 1;
		} elsif($type eq "d") {
			#warn "$val added to deny list\n";
			$val = lc($val);
			$config->{deny}{$val} = 1;
		} elsif($type eq "m") {
			$config->{permtype} = $val;
			$permtype = $val;
		}
	}
	debug_print("str2conf: " . Dumper($config), "config", 2);
	return $config;
}

sub _hnick($) { my $socket = shift; return ${*$socket}{'net_toc_username'} if $socket and UNIVERSAL::isa($socket, "IO::Socket::INET"); }

=pod

=item debug_print(TEXT, TYPE, LEVEL)

If you want to be able to debug this thing, you must provide a debug_print function.
The first parameter is the text of the debug message.
The second is the type (valid types are chat, signon, buddies, config, and IM)
The third parameter is the level.  i.e. 1 for basic messages, 2 for nitty-gritty stuff.

=cut

# sub debug_print($$$) { return; }

=pod

=item txt2html(MESSAGE)

Convert plaintext into HTML.  Just puts a <FONT COLOR="#000000" around it.
It also handles IRC bold, italic, and underline codes.
Returns the HTML.

=cut

sub txt2html($) {
	my($msg) = shift;
	my($bold, $italic, $underline, $color) = (chr(2), chr(oct(26)), chr(oct(37)), chr(3));
	my($inbold, $initalic, $inunderline) = (0, 0, 0);

	$msg = "<FONT COLOR=\"#000000\">$msg</FONT>";
	while($msg =~ /($bold|$italic|$underline)/g) {
		if($1 eq $bold) {
			if($inbold) {
				$msg = $` . "</b>" . $';
				$inbold = 0;
			} else {
				$msg = $` . "<b>" . $';
				$inbold = 1;
			}
		} elsif($1 eq $italic) {
			if($initalic) {
				$msg = $` . "</i>" . $';
				$initalic = 0;
			} else {
				$msg = $` . "<i>" . $';
				$initalic = 1;
			}
		} else { #underlined
			if($inunderline) {
				$msg = $` . "</u>" . $';
				$inunderline = 0;
			} else {
				$msg = $` . "<u>" . $';
				$inunderline = 1;
			}
		}
	}
	return $msg;
}

1;
