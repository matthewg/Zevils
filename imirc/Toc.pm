package Toc;

use IO::Socket;
@ISA = qw(Exporter);
@EXPORT_OK = qw($err aim_strerror str2conf conf2str sflap_get sflap_put quote sflap_encode signon parseclass normalize roast_password add_buddy);
%EXPORT_TAGS = (all => [@EXPORT_OK]);
$VERSION = '0.75';

=pod
=item getconfig(NICK)
Returns a config-hash of the type returned by signon for NICK.
=cut

sub getconfig($) { return $config{$_[0]}{groups}; }

=pod
=item strerror(ERRNO)
Takes a Toc error number and returns a string describing the error.
Error messages are taken from PROTOCOL.
=cut

sub strerror($) {
	my($errno, $params) = shift;
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
	my($handle) = shift;
	my($buff, $len, $connection);
	#get 6 chars
	$err = "Undefined handle";
	return -1 unless $handle;
	$err = undef;
	$handle->read($buff, 6) or $err = "Couldn't read: $!";
	#decode the SFLAP header

	#get $len chars
	$len = (unpack("CCnn", $buff))[3];
	$handle->read($buff, $len) or $err = "Couldn't read: $!";
	chomp $buff;
	if($err) {
		$handle->close if $handle;
		return -1;
	}
	return $buff;
}

=pod
=item signon(NICK, PASSWORD[, STATUS])
Returns an array consisting of a return value (0 for success, -1 for failure), an IO::Socket::INET object
the Toc permit type, and a group configuration hash.  $Net::Toc::err will be set to the error message if there
is an error.

The IO::Socket::INET object returned by this function is a bit special, so if you plan on using your own IO::Handle
object with the Net::Toc functions, pay attention.  The IO::Socket object is based around a globref.  What that means,
without going into too many technical details, is that there's a hash (and a scalar and an array) hiding behind every
IO::Handle.  You can store things in that hash just like any other hash.  This is documented in perldoc IO::Handle, and
IO::Socket makes use of it.  We store the username in the hash in key net_toc_username, so make sure that you do that for
any IO::Handle's you try to use with Net::Toc.

The Toc permit type is documented in PROTOCOL.  1 is Permit All, 2 is Deny All, 3 is Permit Some, and 4 is Deny Some.

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
	my($socket, $msg, $permtype, $groups);
	&$status("Connecting to toc.oscar.aol.com:9898") if ref $status eq "CODE";
	$socket = IO::Socket::INET->new('toc.oscar.aol.com:9898') or do { $err = "Couldn't create socket: $!"; return -1; };
	${*$socket}{'net_toc_username'} = $username;
	&$status("Connected, switching to FLAP encoding") if ref $status eq "CODE";
	$socket->print("FLAPON\r\n\r\n") or do { $err = "Couldn't write to socket: $!"; return -1; };
	&$status("Switching to SFLAP protocol") if ref $status eq "CODE";
	$msg = sflap_get($socket);
	if($err) {
		return -1;
	}
	if($msg =~ /^ERROR:(.+):(.*)/) {
		$err = "Error $1: " . aim_strerror($2);
		return -1;
	}
	&$status("We are now in flap mode, signing on") if ref $status eq "CODE";
	sflap_put($socket, sflap_encode($username, 1)) or do { $err = "Couldn't write to socket: $!"; return -1; };
	&$status("Sent login packet, doing toc_signon") if ref $status eq "CODE";
	$msg = quote("toc_signon login.oscar.aol.com 1234 $username " . roast_password($password) . " english ") . "\"aimirc $VERSION\"";
	sflap_put($socket, sflap_encode($msg, 0, 1)) or do { $err = "Couldn't write to socket: $!"; return -1; };
	&$status("Sent toc_signon, getting config") if ref $status eq "CODE";
	$msg = sflap_get($socket);
	if($err) {
		return -1;
	}
	if($msg =~ /^ERROR:(.+):(.*)/) {
		$err = "Error $1: " . aim_strerror($2);
		return -1;
	}
	$msg = sflap_get($socket);
	return -1 if $err;
	if($msg =~ /^ERROR:(.+):(.*)/) {
		$err = "Error $1: " . aim_strerror($2);
		return -1;
	}
	($permtype, $groups) = str2conf($msg);
	$config{$username}{permtype} = $permtype;
	$config{$username}{groups} = %$groups;
	&$status("Got config, sending toc_init_done") if ref $status eq "CODE";
	sflap_put($socket, sflap_encode("toc_init_done")) or do { $err = "Couldn't write to socket: $!"; return -1; };
	return (0, $socket, $permtype, $groups);
}

=pod
=item add_buddy(HANDLE, NICK[, GROUP])
Add NICK to the buddy list.  This automatically does a set_config so that the change is saved.
The optional parameter GROUP specifies which group to place the buddy in.  Returns the result of set_config.
=cut

sub add_buddy($$;$) {
	my($handle, $nick, $group) = @_;
	$group ||= "Buddies";
	sflap_do($handle, "toc_add_buddy $nick");
	$config{_hnick($handle)}{Buddies}{$nick}{group} = $group;
	$config{_hnick($handle)}{Buddies}{$nick}{online} ||= 0;
	set_config($handle, $config{_hnick($handle)});	
}

=pod
=item add_permit(HANDLE, NICK)
Add NICK to the permit list.  Returns the result of set_config.
=cut

sub add_permit($$) {
	my($handle, $nick) = @_;
	sflap_do($handle, "toc_add_permit $nick");
	delete $config{_hnick($handle)}{groups}{deny}{$nick};
	$config{_hnick($handle)}{groups}{permit}{$nick} = 1;
	set_config($handle, $config{_hnick($handle)});
}

=pod
=item add_deny(HANDLE, NICK)
Add NICK to the deny list.  Returns the result of set_config.
=cut

sub add_deny($$) {
	my($handle, $nick) = @_;
	sflap_do($handle, "toc_add_deny $nick");
	delete $config{_hnick($handle)}{groups}{permit}{$nick};
	$config{_hnick($handle)}{groups}{deny}{$nick} = 1;
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
	sflap_do($_handle, $msg);
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
	sflap_do($handle, conf2str($config));
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
	my($handle, $msg) = @_; #msg must already be encoded

	$err = "Undefined handle";
	return -1 unless $handle;
	$err = undef;

	my($seqno) = ++${*$handle}{'net_toc_seqno'};
	my @hdr = unpack("CCnn", substr($msg, 0, 6));
	$hdr[2] = $seqno;
	substr($msg, 0, 6) = pack("CCnn", @hdr);

	$handle->print($msg) or $err = "Couldn't write: $!";
	if($err) {
		$handle->close if $handle;
		return -1;
	}
	return 1;
}	

=pod
=item conf2str(CONFIG-HASHREF, PERMTYPE)
Takes a hashref to a config-hash (in the same format returned by signon) and a permit
type (the same one that signon returns) and makes a string of the type that Toc wants for
the toc_set_config command.  You almost definately should not be calling this directly, but
instead calling set_config.  Returns the toc_set_config-format string.
=cut

sub conf2str(\%$) {
	my($groups, $permtype) = @_;
	my($msg, %groups, $group, $buddy);
	$msg = "m $permtype\n";
	foreach $buddy (keys %{$groups->{Buddies}}) {
		push @{$groups{$groups->{Buddies}{$buddy}{group}}}, $buddy;
	}
	foreach $group (keys %$groups) {
		next if $group eq "permit" or $group eq "deny";
		$msg .= "g $group\n";
		foreach $buddy (@{$groups{$group}}) {
			$msg .= "b $buddy\n";
		}
	}
	foreach $buddy (keys %{$groups->{permit}}) {
		$msg .= "p $buddy\n";
	}
	foreach $buddy (keys %{$groups->{deny}}) {
		$msg .= "d $buddy\n";
	}
	$msg = "toc_set_config {" . quote($msg) . "}";
	#warn "$msg\n";
	return $msg;
}

=pod
=item str2conf(STRING)
Takes a string in the format that toc_set_config wants and that the signon process
produces and returns an array consisting of a permit type and a config-hash of the type returned by signon.
You almost definately should not be calling this directly - let signon handle things.  Actually, I suppose you
would use str2conf/conf2str to export and import a Toc configuration.
=cut

sub str2conf($) {
	my($confstr) = shift;
	my($line, $type, $val, $groups, $permtype, $currgroup);
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
			$groups->{Buddies}{$val}{group} = $currgroup;
			$groups->{Buddies}{$val}{online} = 0;
		} elsif($type eq "p") {
			#warn "$val added to permit list\n";
			$val = lc($val);
			$groups->{permit}{$val} = 1;
		} elsif($type eq "d") {
			#warn "$val added to deny list\n";
			$val = lc($val);
			$groups->{deny}{$val} = 1;
		} elsif($type eq "m") {
			$permtype = $val;
		}
	}
	return ($permtype, $groups);
}

sub _hnick($) { return ${*$socket}{'net_toc_username'}; }
