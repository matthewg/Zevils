package Net::OSCAR::Callbacks;

$VERSION = 0.06;

use strict;
use vars qw($VERSION);
use warnigs;
use Carp;

use Net::OSCAR::Common qw(:all);
use Net::OSCAR::TLV;
use Net::OSCAR::Buddylist;

use constant MAJOR => 4;
use constant MINOR => 3;
use constant BUILD => 2229;

sub capabilities() {
	my $caps;

	#AIM_CAPS_CHAT
	$caps .= pack("C*", map{hex($_)} split(/[ \t\n]+/, "0x74 0x8F 0x24 0x20 0x62 0x87 0x11 0xD1 0x82 0x22 0x44 0x45 0x53 0x54 0x00 0x00"));

	return $caps;
}

sub process_snac($$) {
	my($connection, $snac) = @_;
	my($conntype, $family, $subtype, $data, $reqid) = ($connection->{conntype}, $snac->{family}, $snac->{subtype}, $snac->{data}, $snac->{reqid});
	my $session = $connection->{session};

	my %tlv;

	tie %tlv, "Net::OSCAR::TLV";

	$connection->debug_print(sprintf "Got SNAC 0x%04X/0x%04X", $snac->{family}, $snac->{subtype});

	if($conntype == CONNTYPE_LOGIN and $family == 0x17 and $subtype == 0x7) {
		$connection->debug_print("Got authentication key.");
		my $key = substr($data, 2);

		$connection->debug_print("Sending password.");

		# We pretend to be the AIM 3.5.1670/Win32.
		%tlv = (
			0x01 => $session->{screenname},
			0x25 => $connection->encode_password($connection->{auth}, $key),
			0x03 => "AOL Instant Messenger (SM), version 4.3.2229/WIN32",
			0x16 => pack("n", 0x109),
			0x17 => pack("n", MAJOR),
			0x18 => pack("n", MINOR),
			0x19 => pack("n", 0),
			0x1A => pack("n", BUILD),
			0x14 => pack("N", 0x8C),
			0x0E => "us", # country
			0x0F => "en", # lang
			0x4A => pack("C", 1),
		);
		$connection->snac_put(family => 0x17, subtype => 0x2, data => $connection->tlv_encode(\%tlv));
	} elsif($conntype == CONNTYPE_LOGIN and $family == 0x17 and $subtype == 0x3) {
		$connection->debug_print("Got authorization response.");

		%tlv = %{$connection->tlv_decode($data)};
		if($tlv{0x08}) {
			my($error) = unpack("n", $tlv{0x08});
			$session->crapout($connection, "Invalid screenname.") if $error == 0x01;
			$session->crapout($connection, "Invalid password.") if $error == 0x05;
			$session->crapout($connection, "You've been connecting too frequently.") if $error == 0x18;
			$session->crapout($connection, "Unknown error $error: $tlv{0x04}.");
		} else {
			$connection->debug_print("Login OK - connecting to BOS");
			$connection->disconnect;
			$session->{screenname} = $tlv{0x01};
			$session->{email} = $tlv{0x11};
			$session->addconn(
				$tlv{0x6},
				CONNTYPE_BOS,
				"BOS",
				$tlv{0x05}
			);
		}

	} elsif($family == 0x1 and $subtype == 0x7) {
		$connection->debug_print("Got Rate Info Resp.");
		$connection->debug_print("Sending Rate Ack.");
		$connection->snac_put(family => 0x01, subtype => 0x08, data => pack("nnnnn", 1, 2, 3, 4, 5));
		$connection->debug_print("BOS handshake complete!");

		if($conntype == CONNTYPE_BOS) {
			$connection->debug_print("Requesting personal info.");
			$connection->snac_put(family => 0x1, subtype => 0xE);

			$connection->debug_print("Doing buddylist unknown 0x2.");
			$connection->snac_put(family => 0x13, subtype => 0x2);

			$connection->debug_print("Requesting buddylist.");
			$connection->snac_put(family => 0x13, subtype => 0x4);

			$connection->debug_print("Requesting locate rights.");
			$connection->snac_put(family => 0x2, subtype => 0x2);

			$connection->debug_print("Requesting buddy rights");
			$connection->snac_put(family => 0x3, subtype => 0x2);

			$connection->debug_print("Requesting ICBM param info.");
			$connection->snac_put(family => 0x4, subtype => 0x4);

			$connection->debug_print("Requesting BOS rights.");
			$connection->snac_put(family => 0x9, subtype => 0x2);
		} elsif($conntype == CONNTYPE_CHATNAV) {
			$connection->ready();
			$session->{chatnav} = $connection;

			if($session->{chatnav_queue}) {
				foreach my $snac(@{$session->{chatnav_queue}}) {
					$connection->debug_print("Putting SNAC.");
					$connection->snac_put(%$snac);
				}
			}
			delete $session->{chatnav_queue};

		} elsif($conntype == CONNTYPE_ADMIN) {
			$session->{admin} = $connection;
			if($session->{admin_queue}) {
				foreach my $snac(@{$session->{admin_queue}}) {
					$connection->debug_print("Putting SNAC.");
					$connection->snac_put(%$snac);
				}
			}

			$connection->ready();
			delete $session->{admin_queue};
		} elsif($conntype == CONNTYPE_CHAT) {
			$connection->ready();
		}
	} elsif($subtype == 0x1) {
		$subtype = $reqid >> 16;
		my $error = "";
		$session->debug_printf("Got error on req 0x%04X/0x%08X.", $family, $reqid);
		my $reqdata = delete $connection->{reqdata}->[$family]->{pack("N", $reqid)};
		if($family == 0x4) {
			$error = "Your message to could not be sent for the following reason: ";
			delete $session->{cookies}->{$reqid};
		} else {
			$error = "Error in ".$connection->{description}.": ";
		}
		my($errno) = unpack("n", substr($data, 0, 2, ""));
		my $tlv = $connection->tlv_decode($data) if $data;
		$error .= (ERRORS)[$errno] || "unknown error $errno";
		$error .= "(".$tlv->{4}.")." if $tlv;
		$session->callback_error($connection, $error, $errno, $tlv->{4}, $reqdata, $family, $subtype);
	} elsif($family == 0x1 and $subtype == 0xf) {
		$connection->debug_print("Got user information response.");
	} elsif($family == 0x9 and $subtype == 0x3) {
		$connection->debug_print("Got BOS rights.");
	} elsif($family == 0x3 and $subtype == 0x3) {
		$connection->debug_print("Got buddylist rights.");
	} elsif($family == 0x2 and $subtype == 0x3) {
		$connection->debug_print("Got locate rights.");
	} elsif($family == 0x4 and $subtype == 0x5) {
		$connection->debug_print("Got ICBM parameters - warheads armed.");
	} elsif($family == 0x3 and $subtype == 0xB) {
		my $buddy = $session->extract_userinfo($data);
		my $screenname = $buddy->{screenname};
		$connection->debug_print("Incoming bogey - er, I mean buddy - $screenname");

		my $group = $session->findbuddy($screenname);
		$buddy->{buddyid} = $session->{buddies}->{$group}->{members}->{$screenname}->{buddyid};
		$buddy->{online} = 1;
		%{$session->{buddies}->{$group}->{members}->{$screenname}} = %$buddy;

		$session->callback_buddy_in($screenname, $group, $buddy);
	} elsif($family == 0x3 and $subtype == 0xC) {
		my ($buddy) = unpack("C/a*", $data);
		my $group = $session->findbuddy($buddy);
		$session->{buddies}->{$group}->{members}->{$buddy}->{online} = 0;
		$connection->debug_print("And so, another former ally has abandoned us.  Curse you, $buddy!");
		$session->callback_buddy_out($buddy, $group);
	} elsif($family == 0x1 and $subtype == 0x5) {
		my $tlv = $connection->tlv_decode($data);
		my($svctype) = unpack("n", $tlv->{0xD});
		my $conntype;
		my %chatdata;

		if($svctype == CONNTYPE_LOGIN) {
			$conntype = "authorizer";
		} elsif($svctype == CONNTYPE_CHATNAV) {
			$conntype = "chatnav";
		} elsif($svctype == CONNTYPE_CHAT) {
			%chatdata = %{$session->{chats}->{$reqid}};
			$conntype = "chat $chatdata{name}";
		} elsif($svctype == CONNTYPE_ADMIN) {
			$conntype = "admin";
		} elsif($svctype == CONNTYPE_BOS) {
			$conntype = "BOS";
		} else {
			$svctype = sprintf "unknown (0x%04X)", $svctype;
		}
		$connection->debug_print("Got redirect for $svctype.");

		$session->{chats}->{$reqid} = $session->addconn($tlv->{0x6}, $svctype, $conntype, $tlv->{0x5});
		if($svctype == CONNTYPE_CHAT) {
			my($key, $val);
			while(($key, $val) = each(%chatdata)) { $session->{chats}->{$reqid}->{$key} = $val; }
		}
	} elsif($family == 0xB and $subtype == 0x2) {
		$connection->debug_print("Got minimum report interval.");
	} elsif($family == 0x1 and $subtype == 0x13) {
		$connection->debug_print("Got MOTD.");
	} elsif($family == 0x1 and $subtype == 0x3) {
		$connection->debug_print("Got server ready.  Sending set versions.");

		if($connection->{conntype} == CONNTYPE_ADMIN or $connection->{conntype} == CONNTYPE_CHAT) {
			$connection->snac_put(family => 0x1, subtype => 0x17, data =>
				pack("n*", 1, 3, $connection->{conntype}, 1)
			);
		} else {
			$connection->snac_put(family => 0x1, subtype => 0x17, data =>
				pack("n*", 1, 3, 0x13, 1, 2, 1, 3, 1, 4, 1, 6, 1, 8, 1, 9, 1, 0xA, 1, 0xB, 1, 0xC, 1)
			);
		}

		$connection->debug_print("Sending Rate Info Req.");
		$connection->snac_put(family => 0x01, subtype => 0x06);
	} elsif($family == 0x4 and $subtype == 0x7) {
		$connection->debug_print("Got incoming IM.");
		my($from, $msg, $away, $chat, $chaturl) = $session->im_parse($data);
		if($chat) {
			$session->callback_chat_invite($from, $msg, $chat, $chaturl);
		} else {
			$session->callback_im_in($from, $msg, $away);
		}
	} elsif($family == 0x1 and $subtype == 0xA) {
		$connection->debug_print("Got rate change.");

		my($group, $window, $clear, $alert, $limit, $disconnect, $current, $max) = unpack("xx n N*", $data);
		my $rate = RATE_CLEAR;
		if($current >= $clear) {
			# We've been a good little boy.
		} elsif($current >= $alert) {
			$rate = RATE_ALERT;
		} elsif($current >= $limit) {
			$rate = RATE_LIMIT;
		} else {
			$rate = RATE_DISCONNECT;
		}

		$session->callback_rate_alert(RATE_ALERT, $clear, $window) unless $rate == RATE_CLEAR;

	} elsif($family == 0x1 and $subtype == 0x10) {
		$connection->debug_print("Got evil.");
		my $enemy = undef;

		my($newevil) = unpack("n", substr($data, 0, 2, ""));
		$newevil /= 10;
		$enemy = $session->extract_userinfo($data) if $data;

		$session->callback_evil($newevil, $enemy->{screenname});
	} elsif($family == 0x4 and $subtype == 0xC) {
		$connection->debug_print("Got IM ack $reqid.");
		my($reqid) = unpack("xxxx N", $data);
		delete $session->{cookies}->{$reqid};
	} elsif($family == 0x1 and $subtype == 0x1F) {
		$connection->debug_print("Got memory request.");
	} elsif($family == 0x13 and $subtype == 0x3) {
		$connection->debug_print("Got buddylist.");
		$connection->snac_put(family => 0x13, subtype => 0x7);

		$session->set_info("");

		$connection->debug_print("Setting idle.");
		$connection->snac_put(family => 0x1, subtype => 0x11, data => pack("N", 0));

		$connection->ready();

		$connection->debug_print("Adding ICBM parameters.");
		$connection->snac_put(family => 0x4, subtype => 0x2, data =>
			pack("n*", 0, 0, 3, 0x1F40, 0x3E7, 0x3E7, 0, 0)
		);

		#$connection->debug_print("Adding self to buddylist, or something like that.");
		#$connection->snac_put(family => 0x3, subtype => 0x4, data => pack("Ca*", length($session->{screenname}), $session->{screenname}));

		#$session->debug_print("Requesting chatnav.");
		#$session->svcreq(CONNTYPE_CHATNAV);
	} elsif($family == 0x13 and $subtype == 0x6) {
		$connection->debug_print("Got buddylist 0x0006.");
		my $tlvlen = 0;
		my $tlv;
		my $haspd = 0; # has permit/deny list
		my($flags, $flags2);
		my @buddyqueue;


		# This stuff was figured out more through sheer perversity
		# than by actually understanding what all the random bits do.

		$session->{visibility} = VISMODE_PERMITALL; # If we don't have p/d data, this is default.

		($flags) = unpack("xn", substr($data, 0, 3, ""));
		substr($data, 0, 6) = "" if substr($data, 0, 6) eq chr(0)x6;

		while(length($data) > 4) {
			my $type;
			while(substr($data, 0, 4) eq chr(0)x4) {
				substr($data, 0, 4) = "";
			}

			($type) = unpack("n", substr($data, 0, 2));
			if($type == 1) {
				($tlvlen) = unpack("xx n", substr($data, 0, 4, ""));
				substr($data, 0, $tlvlen) = "";
			} elsif($type == 2) {
				substr($data, 0, 4) = ""; #0x0002 0x0004?
				($tlvlen) = unpack("n", substr($data, 0, 2, ""));
				$tlv = $connection->tlv_decode(substr($data, 0, $tlvlen, ""));
				($session->{visibility}) = unpack("C", $tlv->{0xCA});
				$haspd = $tlv->{0xCB};

				if(substr($data, 0, 4) eq chr(0)x4 and $haspd and $haspd eq chr(0xFF)x4) {
					substr($data, 0, 8) = "";
					($tlvlen) = unpack("n", substr($data, 0, 2, ""));
					substr($data, 0, $tlvlen) = "";
				}
			} else {
				# Test for buddy validity
				my $addedbyte = 0;
				if(substr($data, 0, 1) ne chr(0)) {
					$addedbyte = 1;
					$data = chr(0) . $data;
				}
				my($buddy) = unpack("n/a*", $data);
				if($buddy =~ /[\x00-\x1F\x7F-\xFF]/) {
					substr($data, 0, 2+length($buddy)) = "";
					substr($data, 0, 1) = "" if $addedbyte;
					next;
				}

				$buddy = get_buddy($session, \$data);
				next unless $buddy;

				if($buddy->{buddyid}) {
					$session->debug_print("Queueing buddy $buddy->{name}.");
					push @buddyqueue, $buddy;
				} else {
					my $group = $buddy->{name};
					$session->debug_printf("Got group $group (0x%04X).", $buddy->{groupid});
					$session->{buddies}->{$group}->{groupid} = $buddy->{groupid};
					$session->{buddies}->{$group}->{members} = $session->bltie();
				}
			}
		}

		$session->debug_print("Processing queued buddies.");
		foreach my $buddy(@buddyqueue) {
			my $group = "";
			if($buddy->{pdflag}) {
				($buddy->{pdflag} == GROUP_PERMIT) ? ($group = "permit") : ($group = "deny");
				$session->{$group}->{$buddy->{name}} = { buddyid => $buddy->{buddid} };
			} else {
				if(!$buddy->{groupid}) {
					my $xgroup = (sort grep { $_ ne "permit" and $_ ne "deny" } keys %{$session->{buddies}})[0];
					$buddy->{groupid} = $session->{buddies}->{$xgroup}->{groupid};
				}
				$group = $session->findgroup($buddy->{groupid});
				#$session->debug_print("After findgroup, groups are: ", join(",", keys %{$session->{buddies}}));
				next unless $group;
				next if $session->{buddies}->{$group}->{members}->{$buddy->{name}};
				$session->{buddies}->{$group}->{members} = $session->bltie() unless exists $session->{buddies}->{$group}->{members};
				$session->{buddies}->{$group}->{members}->{$buddy->{name}} = {
					online => 0,
					buddyid => $buddy->{buddyid}
				};
			}
		}

		$session->callback_signon_done() unless $session->{sent_done}++;
	} elsif($family == 0x13 and $subtype == 0x0E) {
		$connection->debug_print("Got blmod ack.");
		$session->modgroups();
	} elsif($family == 0x1 and $subtype == 0x18) {
		$connection->debug_print("Got hostversions.");
	} elsif($family == 0x1 and $subtype == 0x1F) {
		croak "GOT SENDMEMBLK REQUEST!!";
	} elsif($family == 0x2 and $subtype == 0x6) {
		my $buddy = $session->extract_userinfo($data);
		my $screenname = $buddy->{screenname};
		$connection->debug_print("Incoming buddy info - $screenname");

		$session->callback_buddy_info($screenname, $buddy);
	} elsif($family == 0x1 and $subtype == 0x10) {
		$connection->debug_print("Somebody thinks you're evil!");

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

		$session->debug_print("ChatNav told us where to find $chat->{name}");

		# Generate a random request ID
		my($reqid) = "";
		$reqid = pack("n", 4);
		$reqid .= randchars(2);
		($reqid) = unpack("N", $reqid);

		# We can ignore the rest of this packet.
		$session->{chats}->{$reqid} = $chat;

		# And now, on a very special Chat Request...
		$session->{bos}->snac_put(family => 0x01, subtype => 0x04, reqid => $reqid, data =>
			pack("nnn nCa*n",
				CONNTYPE_CHAT, 1, 5+length($chat->{url}),
				$chat->{exchange}, length($chat->{url}), $chat->{url}, 0
			)
		);
	} elsif($family == 0x04 and $subtype == 0x0C) {
		$session->debug_print("Acknowledged.");
	} elsif($family == 0x0E and $subtype == 0x02) {
		$connection->debug_print("Got update on room info.");

		my($namelen) = unpack("xx C", substr($data, 0, 4, ""));
		substr($data, 0, $namelen - 1, "");

		substr($data, 0, 2) = "";
		my($detaillevel) = unpack("C", substr($data, 0, 1, ""));

		my($tlvcount) = unpack("n", substr($data, 0, 2, ""));
		my $tlv = $connection->tlv_decode($data);

		$session->callback_chat_joined($connection->{name}, $connection);

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
		while(substr($data, 0, 1) ne chr(0)) {
			my($emigree) = unpack("C/a*", $data);
			substr($data, 0, 1+length($emigree)) = "";
			$session->callback_chat_buddy_out($emigree, $connection);
		}
	} elsif($family == 0x0E and $subtype == 0x06) {
		substr($data, 0, 10) = "";
		my $tlv = $connection->tlv_decode($data);
		my ($sender) = unpack("C/a*", $tlv->{0x03});
		my $mtlv = $connection->tlv_decode($tlv->{0x05});
		my $message = $mtlv->{0x01};
		$session->callback_chat_im_in($sender, $connection, $message);
	} elsif($family == 0x07 and $subtype == 0x05) {
		$connection->debug_print("Admin request successful!");

		my($reqtype) = unpack("n", substr($data, 0, 2, ""));
		my $tlv = $connection->tlv_decode(substr($data, 0, 6, ""));
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
		$reqdesc ||= sprintf "unknown admin reply type 0x%04X/0x%04X", $reqtype, $subreq;

		my $errdesc = "";
		if(!exists($tlv->{1})) {
			my $tlv = $connection->tlv_decode($data);
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
		$session->debug_print("Account confirmed.");
	} else {
		$connection->debug_print("Unknown SNAC: ".hexdump($snac->{data}));
	}

	return 1;
}

sub get_buddy($\$) {
	my ($session, $data) = @_;
	confess "Bad data $data!" unless ref($data) eq "SCALAR";
	confess "Too short" if length($$data) < 10;
	if(substr($$data, 0, 2) eq pack("n", 0xC8)) { ## Sometimes we get TLV 0xC8?
		my($tlvlen) = unpack("xx n", $$data);
		substr($$data, 0, 4+$tlvlen) = "";
	}
	my($name, $groupid, $buddyid, $pdflag, $groupmembers) = unpack("n/a* n n n n", $$data);
	return undef unless $name;
	substr($$data, 0, 10+length($name)) = "";
	my(@groupmembers) = ();
	@groupmembers = unpack("n*", substr($$data, 0, $groupmembers, "")) if $groupmembers;
	if($groupmembers) {
		$session->{buddies}->{$name}->{groupid} = $groupid;
		$session->{buddies}->{$name}->{members} = $session->bltie();
	}
	return {
		name => $name,
		groupid => $groupid,
		buddyid => $buddyid,
		pdflag => $pdflag,
		groupmembers => \@groupmembers
	};
}

1;
