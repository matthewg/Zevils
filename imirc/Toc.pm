package Toc;

use IO::Socket;
@ISA = qw(Exporter);
@EXPORT_OK = qw($err aim_strerror str2conf conf2str sflap_get sflap_put quote sflap_encode signon parseclass normalize roast_password);
%EXPORT_TAGS = (all => [@EXPORT_OK]);
$VERSION = '0.1';

sub aim_strerror($) {
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

sub quote($) {
	my $msg = shift;
	$msg =~ s/\\/\\\\/g;
	$msg =~ s/\$/\\\$/g; $msg =~ s/\[/\\\[/g; $msg =~ s/]/\\]/g;
	$msg =~ s/\(/\\(/g; $msg =~ s/\)/\\)/g; $msg =~ s/\#/\\\#/g;
	$msg =~ s/\{/\\\{/g; $msg =~ s/\}/\\\}/g; $msg =~ s/\"/\\\"/g;
	$msg =~ s/\'/\\\'/g; $msg =~ s/\`/\\\`/g;
	return $msg;
}

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

sub signon($$;&) {
	my($username, $password, $status) = @_;
	my($socket, $msg, $permtype, $groups);
	&$status("Connecting to toc.oscar.aol.com:9898") if ref $status eq "CODE";
	$socket = IO::Socket::INET->new('toc.oscar.aol.com:9898') or do { $err = "Couldn't create socket: $!"; return -1; };
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
	&$status("Got config, sending toc_init_done") if ref $status eq "CODE";
	sflap_put($socket, sflap_encode("toc_init_done")) or do { $err = "Couldn't write to socket: $!"; return -1; };
	return (0, $socket, $permtype, $groups);
}

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

sub normalize($) { $_[0] =~ tr/ //d; return lc($_[0]); }
