package Net::OSCAR::Callbacks;

$VERSION = '0.62';

use strict;
use vars qw($VERSION);
use Carp;

use Net::OSCAR::Common qw(:all);
use Net::OSCAR::TLV;
use Net::OSCAR::Buddylist;
use Net::OSCAR::_BLInternal;
use Net::OSCAR::OldPerl;

sub process_snac($$) {
	my($connection, $snac) = @_;
	my($conntype, $family, $subtype, $data, $reqid) = ($connection->{conntype}, $snac->{family}, $snac->{subtype}, $snac->{data}, $snac->{reqid});

	my $reqdata = delete $connection->{reqdata}->[$family]->{pack("N", $reqid)};
	my $session = $connection->{session};

	$connection->log_printf(OSCAR_DBG_DEBUG, "Got SNAC 0x%04X/0x%04X", $snac->{family}, $snac->{subtype});


	if($conntype == CONNTYPE_LOGIN and $family == 0x17 and $subtype == 0x7) {
		$connection->log_print(OSCAR_DBG_SIGNON, "Got authentication key.");
		my($key) = unpack("n/a*", $data);

		if(defined($connection->{auth})) {
			$connection->log_print(OSCAR_DBG_SIGNON, "Sending password.");
			$connection->snac_put(family => 0x17, subtype => 0x2, data => tlv_encode(signon_tlv($session, $connection->{auth}, $key)));
		} else {
			$connection->log_print(OSCAR_DBG_SIGNON, "Giving client authentication challenge.");
			$session->callback_auth_challenge($key, "AOL Instant Messenger (SM)");
		}
	} elsif($conntype == CONNTYPE_LOGIN and $family == 0x17 and $subtype == 0x3) {
		$connection->log_print(OSCAR_DBG_SIGNON, "Got authorization response.");

		my $tlv = tlv_decode($data);
		if($tlv->{0x08}) {
			my($error) = unpack("n", $tlv->{0x08});
			$session->crapout($connection, "Invalid screenname.") if $error == 0x01;
			$session->crapout($connection, "Invalid password.") if $error == 0x05;
			$session->crapout($connection, "You've been connecting too frequently.") if $error == 0x18;
			my($errstr) = ((ERRORS)[$error]) || "unknown error";
			$errstr .= " ($tlv->{0x04})" if $tlv->{0x04};
			$session->crapout($connection, $errstr, $error);
			return 0;
		} else {
			$connection->log_print(OSCAR_DBG_SIGNON, "Login OK - connecting to BOS");
			$connection->{closing} = 1;
			$connection->disconnect;
			$session->{screenname} = $tlv->{0x01};
			$session->{email} = $tlv->{0x11};
			$session->addconn(
				$tlv->{0x6},
				CONNTYPE_BOS,
				"basic OSCAR service",
				$tlv->{0x05}
			);
		}
	} elsif($family == 0x1 and $subtype == 0x7) {
		$connection->log_print(OSCAR_DBG_NOTICE, "Got Rate Info Resp.");
		$connection->log_print(OSCAR_DBG_NOTICE, "Sending Rate Ack.");
		$connection->snac_put(family => 0x01, subtype => 0x08, data => pack("nnnnn", 1, 2, 3, 4, 5));
		$connection->log_print(OSCAR_DBG_NOTICE, "BOS handshake complete!");

		if($conntype == CONNTYPE_BOS) {
			$connection->log_print(OSCAR_DBG_SIGNON, "Signon BOS handshake complete!");

			$connection->log_print(OSCAR_DBG_DEBUG, "Requesting personal info.");
			$connection->snac_put(family => 0x1, subtype => 0xE);

			$connection->log_print(OSCAR_DBG_DEBUG, "Doing buddylist unknown 0x2.");
			$connection->snac_put(family => 0x13, subtype => 0x2);

			$connection->log_print(OSCAR_DBG_DEBUG, "Requesting buddy list.");
			$connection->snac_put(family => 0x13, subtype => 0x4);

			$connection->log_print(OSCAR_DBG_DEBUG, "Requesting locate rights.");
			$connection->snac_put(family => 0x2, subtype => 0x2);

			$connection->log_print(OSCAR_DBG_DEBUG, "Requesting buddy rights");
			$connection->snac_put(family => 0x3, subtype => 0x2);

			$connection->log_print(OSCAR_DBG_DEBUG, "Requesting ICBM param info.");
			$connection->snac_put(family => 0x4, subtype => 0x4);

			$connection->log_print(OSCAR_DBG_DEBUG, "Requesting BOS rights.");
			$connection->snac_put(family => 0x9, subtype => 0x2);
		} elsif($conntype == CONNTYPE_CHAT) {
			$connection->ready();

			$session->callback_chat_joined($connection->name, $connection) unless $connection->{sent_joined}++;
		} else {
			$session->{services}->{$conntype} = $connection;

			if($session->{svcqueues}->{$conntype}) {
				foreach my $snac(@{$session->{svcqueues}->{$conntype}}) {
					$connection->log_print(OSCAR_DBG_DEBUG, "Putting SNAC.");
					$connection->snac_put(%$snac);
				}
			}

			$connection->ready();
			delete $session->{svcqueues}->{$conntype};
		}
	} elsif($family == 0x1 and $subtype == 0x21) {
		my($infotype, $flags, $len) = unpack("nCC", substr($data, 0, 4, ""));
		$connection->log_print(OSCAR_DBG_DEBUG, "Got extended information message $infotype/$flags.");

		if($infotype == 0 or $infotype == 1) { # Buddy icon upload request
			if($session->{icon} and $session->{is_on}) {
				my $md5 = substr($data, 0, $len, "");
				if($flags == 0x41) {
					$connection->log_print(OSCAR_DBG_INFO, "Uploading buddy icon.");
					$session->svcdo(CONNTYPE_ICON, family => 0x10, subtype => 0x02, data => pack("nna*", 1, length($session->{icon}), $session->{icon}));
				} elsif($flags == 0x81) {
					$connection->log_print(OSCAR_DBG_WARN, "Got icon resend request!");
					$session->set_icon($session->{icon});
				} else {
					$connection->log_print(OSCAR_DBG_WARN, "Unknown extended info request: $infotype/$flags");
				}
			}
		} elsif($infotype == 2) { # Extended status update
			my($message) = unpack("n/a*", $data);
			substr($data, 0, length($message) + 2) = "";
			$session->callback_extended_status($message);
		} else {
			$connection->log_print(OSCAR_DBG_WARN, "Unknown extended info request: $infotype/$flags");
		}
	} elsif($subtype == 0x1) {
		$subtype = $reqid >> 16;
		my $error = "";
		if($family == 0x4) {
			$error = "Your message could not be sent for the following reason: ";
		} else {
			$error = "Error in ".$connection->{description}.": ";
		}
		my($errno) = unpack("n", substr($data, 0, 2, ""));
		$session->log_printf(OSCAR_DBG_DEBUG, "Got error %d on req 0x%04X/0x%08X.", $errno, $family, $reqid);
		return if $errno == 0;
		my $tlv = tlv_decode($data) if $data;
		$error .= (ERRORS)[$errno] || "unknown error";
		$error .= " (".$tlv->{4}.")." if $tlv and $tlv->{4};
		send_error($session, $connection, $errno, $error, 0, $reqdata);
	} elsif($family == 0x1 and $subtype == 0xf) {
		$connection->log_print(OSCAR_DBG_NOTICE, "Got user information response.");
	} elsif($family == 0x9 and $subtype == 0x3) {
		$connection->log_print(OSCAR_DBG_NOTICE, "Got BOS rights.  Setting user info.");
		$session->set_info("");
	} elsif($family == 0x3 and $subtype == 0x3) {
		$connection->log_print(OSCAR_DBG_NOTICE, "Got buddylist rights.");
	} elsif($family == 0x2 and $subtype == 0x3) {
		$connection->log_print(OSCAR_DBG_NOTICE, "Got locate rights.");
	} elsif($family == 0x4 and $subtype == 0x5) {
		$connection->log_print(OSCAR_DBG_NOTICE, "Got ICBM parameters - warheads armed.");
	} elsif($family == 0x3 and $subtype == 0xB) {
		my $buddy = $session->extract_userinfo($data);
		my $screenname = $buddy->{screenname};
		$connection->log_print(OSCAR_DBG_DEBUG, "Incoming bogey - er, I mean buddy - $screenname");

		my $group = $session->findbuddy($screenname);
		return unless $group; # Without this, remove_buddy screws things up until signoff/signon
		$buddy->{buddyid} = $session->{buddies}->{$group}->{members}->{$screenname}->{buddyid};
		$buddy->{online} = 1;
		foreach my $key(keys %$buddy) {
			$session->{buddies}->{$group}->{members}->{$screenname}->{$key} = $buddy->{$key};
		}

		# Sync $session->{userinfo}->{$foo} with buddylist entry
		if($session->{userinfo}->{$screenname}) {
			if(!$session->{userinfo}->{$screenname}->{online}) {
				foreach my $key(keys %{$session->{userinfo}->{$screenname}}) {
					$session->{buddies}->{$group}->{members}->{$screenname}->{$key} = $session->{userinfo}->{$screenname}->{$key};
				}
				delete $session->{userinfo}->{$screenname};
				$session->{userinfo}->{$screenname} = $session->{buddies}->{$group}->{members}->{$screenname};
			}
		} else {
			$session->{userinfo}->{$screenname} = $session->{buddies}->{$group}->{members}->{$screenname};
		}

		$session->callback_buddy_in($screenname, $group, $session->{buddies}->{$group}->{members}->{$screenname});
	} elsif($family == 0x3 and $subtype == 0xC) {
		my ($buddy) = new Net::OSCAR::Screenname(unpack("C/a*", $data));
		my $group = $session->findbuddy($buddy);
		$session->{buddies}->{$group}->{members}->{$buddy}->{online} = 0;
		$connection->log_print(OSCAR_DBG_DEBUG, "And so, another former ally has abandoned us.  Curse you, $buddy!");
		$session->callback_buddy_out($buddy, $group);
	} elsif($family == 0x1 and $subtype == 0x5) {
		my $tlv = tlv_decode($data);
		my($svctype) = unpack("n", $tlv->{0xD});
		my $conntype;
		my %chatdata;


		my $svcmap = tlv;
		$svcmap->{$_} = $_ foreach (CONNTYPE_LOGIN, CONNTYPE_CHATNAV, CONNTYPE_CHAT, CONNTYPE_ADMIN, CONNTYPE_BOS, CONNTYPE_ICON);
		$conntype = $svcmap->{$svctype} || sprintf("unknown (0x%04X)", $svctype);
		if($svctype == CONNTYPE_CHAT) {
			%chatdata = %{$session->{chats}->{$reqid}};
			$conntype = "chat $chatdata{name}";
		}

		$connection->log_print(OSCAR_DBG_NOTICE, "Got redirect for $svctype.");

		my $newconn = $session->addconn($tlv->{0x6}, $svctype, $conntype, $tlv->{0x5});
		if($svctype == CONNTYPE_CHAT) {
			$session->{chats}->{$reqid} = $newconn;
			my($key, $val);
			while(($key, $val) = each(%chatdata)) { $session->{chats}->{$reqid}->{$key} = $val; }
		}
	} elsif($family == 0xB and $subtype == 0x2) {
		$connection->log_print(OSCAR_DBG_NOTICE, "Got minimum report interval.");
	} elsif($family == 0x1 and $subtype == 0x13) {
		$connection->log_print(OSCAR_DBG_NOTICE, "Got MOTD.");
	} elsif($family == 0x1 and $subtype == 0x3) {
		$connection->log_print($connection->{conntype} == CONNTYPE_BOS ? OSCAR_DBG_SIGNON : OSCAR_DBG_NOTICE, "Got server ready.  Sending set versions.");

		my $conntype = $connection->{conntype};
		if($conntype != CONNTYPE_BOS) {
			$connection->snac_put(family => 0x1, subtype => 0x17, data => pack("n*",
				1, OSCAR_TOOLDATA()->{1}->{version},
				$conntype, OSCAR_TOOLDATA()->{$conntype}->{version},
			));
		} else {
			my $data = "";
			$data .= pack("n*", $_, OSCAR_TOOLDATA()->{$_}->{version}) foreach sort {$b <=> $a} grep {not OSCAR_TOOLDATA()->{$_}->{nobos}} keys %{OSCAR_TOOLDATA()};
			$connection->snac_put(family => 0x1, subtype => 0x17, data => $data);
		}

		$connection->log_print(OSCAR_DBG_NOTICE, "Sending Rate Info Req.");
		$connection->snac_put(family => 0x01, subtype => 0x06);
	} elsif($family == 0x4 and $subtype == 0x7) {
		$connection->log_print(OSCAR_DBG_DEBUG, "Got incoming IM.");
		my($from, $msg, $away, $chat, $chaturl) = $session->im_parse($data);
		if($from) {
			# Ignore invites for chats that we're already in
			if($chat and not
				grep { $_->{url} eq $chaturl }
					 grep { $_->{conntype} == CONNTYPE_CHAT }
						@{$session->{connections}}
			) {
				$session->callback_chat_invite($from, $msg, $chat, $chaturl);
			} elsif(!$chat) {
				$session->callback_im_in($from, $msg, $away);
			}
		}
	} elsif($family == 0x4 and $subtype == 0x14) {
		$connection->log_print(OSCAR_DBG_DEBUG, "Got typing notification.");

		my ($unknown1, $unknown2, $type1, $sn, $type2 ) = unpack("N2nC/a*n", $data);
		$session->callback_typing_status($sn, $type2);
	} elsif($family == 0x1 and $subtype == 0xA) {
		$connection->log_print(OSCAR_DBG_NOTICE, "Got rate change.");

		my($group, $window, $clear, $alert, $limit, $disconnect, $current, $max) = unpack("xx n N*", $data);
		my($rate, $worrisome);

		if($current <= $disconnect) {
			$rate = RATE_DISCONNECT;
			$worrisome = 1;
		} elsif($current <= $limit) {
			$rate = RATE_LIMIT;
			$worrisome = 1;
		} elsif($current <= $alert) {
			$rate = RATE_ALERT;
			if($current - $limit < 500) {
				$worrisome = 1;
			} else {
				$worrisome = 0;
			}
		} else { # We're clear
			$rate = RATE_CLEAR;
			$worrisome = 0;
		}

		$session->callback_rate_alert($rate, $clear, $window, $worrisome);
	} elsif($family == 0x1 and $subtype == 0x10) {
		$connection->log_print(OSCAR_DBG_DEBUG, "Got evil.");
		my $enemy = undef;

		my($newevil) = unpack("n", substr($data, 0, 2, ""));
		$newevil /= 10;
		$enemy = $session->extract_userinfo($data) if $data;

		$session->callback_evil($newevil, $enemy->{screenname});
	} elsif($family == 0x4 and $subtype == 0xC) {
		$connection->log_print(OSCAR_DBG_DEBUG, "Got IM ack $reqid.");
		$session->callback_im_ok($reqdata, $reqid);
	} elsif($family == 0x1 and $subtype == 0x1F) {
		$connection->log_print(OSCAR_DBG_SIGNON, "Got memory request.");
	} elsif($family == 0x13 and $subtype == 0x3) {
		$connection->log_print(OSCAR_DBG_NOTICE, "Got buddylist 0x0003.");	
		$session->{gotbl} = 1;
	} elsif($family == 0x13 and $subtype == 0x6) {
		$connection->log_print(OSCAR_DBG_SIGNON, "Got buddylist.");

		$session->{blarray} = [] unless exists($session->{blarray});
		substr($data, 0, 3) = "";
		substr($data, -4, 4) = "" if $snac->{flags2};
		$session->{blarray}->[$snac->{flags2}] = $data;

		if($snac->{flags2}) {
			$connection->log_print(OSCAR_DBG_SIGNON, "Got buddylist part - need $snac->{flags2} more parts.");
		} else {
			delete $session->{gotbl};

			return unless Net::OSCAR::_BLInternal::blparse($session, join("", reverse @{$session->{blarray}}));
			delete $session->{blarray};
			got_buddylist($session, $connection);
		}
	} elsif($family == 0x13 and $subtype == 0x0E) {
		$connection->log_print(OSCAR_DBG_DEBUG, "Got blmod ack (", scalar(@{$session->{budmods}}), " left).");
		my(@errors) = unpack("n*", $data);

		my @reqdata = @$reqdata;
		foreach my $error(reverse @errors) {
			my($errdata) = shift @reqdata;
			last unless $errdata;
			if($error != 0) {
				$session->{buderrors} = 1;
				my($type, $gid, $bid) = ($errdata->{type}, $errdata->{gid}, $errdata->{bid});
				if(exists($session->{blold}->{$type}) and exists($session->{blold}->{$type}->{$gid}) and exists($session->{blold}->{$type}->{$gid}->{$bid})) {
					$session->{blinternal}->{$type}->{$gid}->{$bid} = $session->{blold}->{$type}->{$gid}->{$bid};
				} else {
					delete $session->{blinternal}->{$type} unless exists($session->{blold}->{$type});
					delete $session->{blinternal}->{$type}->{$gid} unless exists($session->{blold}->{$type}) and exists($session->{blold}->{$type}->{$gid});
					delete $session->{blinternal}->{$type}->{$gid}->{$bid} unless exists($session->{blold}->{$type}) and exists($session->{blold}->{$type}->{$gid}) and exists($session->{blold}->{$type}->{$gid}->{$bid});
				}

				$connection->snac_put(%{pop @{$session->{budmods}}}); # Stop making changes
				$session->callback_buddylist_error($error, $errdata->{desc});
				last;
			}
		}

		if($session->{buderrors}) {
			Net::OSCAR::_BLInternal::BLI_to_NO($session) if $session->{buderrors};
			delete $session->{qw(blold buderrors budmods)};
		} else {
			$connection->snac_put(%{shift @{$session->{budmods}}});
			$session->callback_buddylist_ok if !@{$session->{budmods}};
		}
	} elsif($family == 0x13 and $subtype == 0x0F) {
		if($session->{gotbl}) {
			delete $session->{gotbl};
			$connection->log_print(OSCAR_DBG_WARN, "Couldn't get your buddylist - probably because you don't have one.");
			got_buddylist($session, $connection);			
		} else {
			$connection->log_print(OSCAR_DBG_INFO, "Buddylist error:", hexdump($data));
		}
	} elsif($family == 0x1 and $subtype == 0x18) {
		$connection->log_print(OSCAR_DBG_DEBUG, "Got hostversions.");
	} elsif($family == 0x1 and $subtype == 0x1F) {
		croak "GOT SENDMEMBLK REQUEST!!";
	} elsif($family == 0x2 and $subtype == 0x6) {
		my $buddy = $session->extract_userinfo($data);
		my $screenname = $buddy->{screenname};
		$connection->log_print(OSCAR_DBG_DEBUG, "Incoming buddy info - $screenname");

		$session->callback_buddy_info($screenname, $buddy);
	} elsif($family == 0x1 and $subtype == 0x10) {
		$connection->log_print(OSCAR_DBG_DEBUG, "Somebody thinks you're evil!");

		my($evil) = unpack("n", substr($data, 0, 2, ""));
		$evil /= 10;
		my $eviller = "";
		if($data) {
			$eviller = $session->extract_userinfo($data);
		}
		$session->callback_evil($evil, $eviller);
	} elsif($family == 0xD and $subtype == 9) {
		my $chat;
		substr($data, 0, 4) = "";
		($chat->{exchange}) = unpack("n", substr($data, 0, 2, ""));
		my($namelen) = unpack("C", substr($data, 0, 1, ""));
		$chat->{url} = substr($data, 0, $namelen, "");

		substr($data, 0, 21) = ""; # 0 2 15 66 2 0 68 4 0 0 6A
		($chat->{name}) = unpack("n/a*", $data);
		substr($data, 0, length($chat->{name})+2) = "";

		$session->log_print(OSCAR_DBG_DEBUG, "ChatNav told us where to find $chat->{name}");

		# Generate a random request ID
		my($reqid) = "";
		$reqid = pack("n", 4);
		$reqid .= randchars(2);
		($reqid) = unpack("N", $reqid);

		# We can ignore the rest of this packet.
		$session->{chats}->{$reqid} = $chat;

		# And now, on a very special Chat Request...
		$session->svcdo(CONNTYPE_BOS, family => 0x01, subtype => 0x04, reqid => $reqid, data =>
			pack("nnn nCa*n",
				CONNTYPE_CHAT, 1, 5+length($chat->{url}),
				$chat->{exchange}, length($chat->{url}), $chat->{url}, 0
			)
		);
	} elsif($family == 0x04 and $subtype == 0x0C) {
		$session->log_print(OSCAR_DBG_DEBUG, "Acknowledged.");
	} elsif($family == 0x0E and $subtype == 0x02) {
		$connection->log_print(OSCAR_DBG_DEBUG, "Got update on room info.");

		my($namelen) = unpack("xx C", substr($data, 0, 4, ""));
		substr($data, 0, $namelen - 1, "");

		substr($data, 0, 2) = "";
		my($detaillevel) = unpack("C", substr($data, 0, 1, ""));

		my($tlvcount) = unpack("n", substr($data, 0, 2, ""));
		my $tlv = tlv_decode($data);

		$session->callback_chat_joined($connection->{name}, $connection) unless $connection->{sent_joined}++;

		my $occupants = 0;
		($occupants) = unpack("n", $tlv->{0x6F}) if $tlv->{0x6F};
		for(my $i = 0; $i < $occupants; $i++) {
			my($occupant, $occlen) = $session->extract_userinfo($tlv->{0x73});
			substr($data, 0, $occlen) = "";
			$session->callback_chat_buddy_in($occupant->{screenname}, $connection);
		}
	} elsif($family == 0x0E and $subtype == 0x03) {
		while($data) {
			my($occupant, $chainlen) = $session->extract_userinfo($data);
			substr($data, 0, $chainlen) = "";
			$session->callback_chat_buddy_in($occupant->{screenname}, $connection, $occupant);
		}
	} elsif($family == 0x0E and $subtype == 0x04) {
		while($data and substr($data, 0, 1) ne chr(0)) {
			my($emigree) = unpack("C/a*", $data);
			substr($data, 0, 1+length($emigree)) = "";
			$session->callback_chat_buddy_out($emigree, $connection);
		}
	} elsif($family == 0x0E and $subtype == 0x06) {
		substr($data, 0, 10) = "";
		my $tlv = tlv_decode($data);
		my ($sender) = unpack("C/a*", $tlv->{0x03});
		my $mtlv = tlv_decode($tlv->{0x05});
		my $message = $mtlv->{0x01};
		$session->callback_chat_im_in($sender, $connection, $message);
	} elsif($family == 0x07 and $subtype == 0x05) {
		$connection->log_print(OSCAR_DBG_DEBUG, "Admin request successful!");

		my($reqtype) = unpack("n", substr($data, 0, 2, ""));
		my $tlv = tlv_decode(substr($data, 0, 6, ""));
		my $reqdesc = "";
		my($subreq) = unpack("n", $tlv->{0x3}) if $tlv->{0x3};
		$subreq ||= 0;
		if($reqtype == 2) {
			$reqdesc = ADMIN_TYPE_PASSWORD_CHANGE;
		} elsif($reqtype == 3) {
			if($subreq == 0x11) {
				$reqdesc = ADMIN_TYPE_EMAIL_CHANGE;
			} else {
				$reqdesc = ADMIN_TYPE_SCREENNAME_FORMAT;
			}
		} elsif($reqtype == 0x1E) {
			$reqdesc = ADMIN_TYPE_ACCOUNT_CONFIRM;
		}
		delete $session->{adminreq}->{0+$reqdesc} if $reqdesc;
		$reqdesc ||= sprintf "unknown admin reply type 0x%04X/0x%04X", $reqtype, $subreq;

		my $errdesc = "";
		if(!exists($tlv->{1})) {
			$tlv = tlv_decode($data);
			if($reqdesc eq "account confirm") {
				$errdesc = "Your account is already confirmed.";
			} else {
				my($result) = unpack("n", $tlv->{0x08});
				if($result == 2) {
					$errdesc = ADMIN_ERROR_BADPASS;
				} elsif($result == 6) {
					$errdesc = ADMIN_ERROR_BADINPUT;
				} elsif($result == 0xB or $result == 0xC) {
					$errdesc = ADMIN_ERROR_BADLENGTH;
				} elsif($result == 0x13) {
					$errdesc = ADMIN_ERROR_TRYLATER;
				} elsif($result == 0x1D) {
					$errdesc = ADMIN_ERROR_REQPENDING;
				} else {
					$errdesc = sprintf "Unknown error 0x%04X.", $result;
				}
			}
			$session->callback_admin_error($reqdesc, $errdesc, $tlv->{4});
		} else {
			if($reqdesc eq "screenname format") {
				$session->{screenname} = $data;
			}
			$session->callback_admin_ok($reqdesc);
		}
	} elsif($family == 0x07 and $subtype == 0x05) {
		$session->log_print(OSCAR_DBG_DEBUG, "Account confirmed.");
		$session->callback_admin_ok(ADMIN_TYPE_ACCOUNT_CONFIRM);
	} elsif($family == 0x09 and $subtype == 0x02) {
		$session->crapout($connection, "A session using this screenname has been opened in another location.");
	} elsif($family == 0x10 and $subtype == 0x03) {
		$session->log_print(OSCAR_DBG_INFO, "Buddy icon uploaded.");
		$session->callback_buddy_icon_uploaded();
	} elsif($family == 0x10 and $subtype == 0x05) {
		my($screenname, $flags, $number, $checksum, $icon) = unpack("C/a*nCC/a*n/a*", $data);
		$session->log_print(OSCAR_DBG_INFO, "Buddy icon downloaded for $screenname.");
		$session->{userinfo}->{$screenname} ||= {};
		$session->{userinfo}->{icon_checksum} = $checksum;
		$session->{userinfo}->{icon} = $icon;
		$session->callback_buddy_icon($screenname, $icon);
	} else {
		$connection->log_print(OSCAR_DBG_NOTICE, "Unknown SNAC: ".hexdump($snac->{data}));
	}

	return 1;
}

sub got_buddylist($$) {
	my($session, $connection) = @_;

	my $icbm_parm = 0;
	$icbm_parm = 0xB;

	$connection->log_print(OSCAR_DBG_DEBUG, "Adding ICBM parameters.");
	$connection->snac_put(family => 0x4, subtype => 0x2, data =>
		pack("n*", 0, 0, $icbm_parm, 0x1F40, 0x3E7, 0x3E7, 0, 0)
	);

	$connection->ready();

	$session->set_extended_status("") if $session->{capabilities}->{extended_status};

	$connection->log_print(OSCAR_DBG_DEBUG, "Setting idle.");
	$connection->snac_put(family => 0x1, subtype => 0x11, data => pack("N", 0));

	$connection->snac_put(family => 0x13, subtype => 0x7);

	$session->{is_on} = 1;
	$session->callback_signon_done() unless $session->{sent_done}++;
}

1;

