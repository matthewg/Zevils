<?

require_once "wins.php";
require_once "des.php";
require_once "strerror.php";

//http://www.snia.org/tech_activities/CIFS/CIFS-TR-1p00_FINAL.pdf

/*
	SMB_COM_NEGOTIATE		protocol negotiation
	SMB_COM_SESSION_SETUP_ANDX	send credentials
	SMB_COM_TREE_CONNECT_ANDX	send share name
	SMB_COM_OPEN_ANDX		send file name - open request
	SMB_COM_READ			read from opened file
	SMB_COM_CLOSE			close opened file
	SMB_COM_TREE_DISCONNECT		disconnect from a server
*/

function netbios_send_packet($sock, $packet, $type = 0) {
	fwrite($sock,
		chr($type) . //session request
		chr(0x00) . //flags
		pack("n", strlen($packet)) . //length
		$packet
	);
}

function netbios_get_packet($sock) {
	$packet = fread($sock, 4);
	$data = unpack("Ctype/Cflags/nlength", $packet);
	$data["data"] = fread($sock, $data["length"]);
	return $data;
}

function netbios_session_start($sock, $clientname, $servername) {
	$packet = netbios_encode_name($servername, 0x20) .
		netbios_encode_name($clientname);
	netbios_send_packet($sock, $packet, 0x81);
	$data = netbios_get_packet($sock);
	if($data["type"] != 0x82) {
		print "Bad response: " . $data["type"];
		return -1;
	} else {
		fread($sock, $data["length"]);
		return 0;
	}
}

function cifs_make_header($command, $smb = array()) {
	$extsec = 1;
	$tree_id = 0xFFFF;
	$user_id = 0;
	$unicode = 1;
	if(isset($smb["extsec"])) $extsec = $smb["extsec"];
	if(isset($smb["tree_id"])) $tree_id = $smb["tree_id"];
	if(isset($smb["user_id"])) $user_id = $smb["user_id"];
	if(isset($smb["unicode"])) $unicode = $smb["unicode"];

	$flags2 = 0x1; //long filenames
	if($extsec) $flags2 |= 0x800;
	if($unicode) $flags2 |= 0x8000;

	$packet = chr(0xFF) . "SMB";
	$packet .= chr($command);
	$packet .= pack("V", 0);
	$packet .= chr(0x8); //flags - caseless pathnames
	$packet .= pack("v", $flags2);
	for($i = 0; $i < 12; $i++) { $packet .= chr(0); } //padding
	$packet .= pack("v", $tree_id);
	$packet .= pack("v", getmypid());
	$packet .= pack("v", $user_id); 
	$packet .= pack("v", 1); // Multiplex ID
	return $packet;
}

function cifs_parse_header($packet) {
	$data = unpack("x4/Ccommand/Cerror_class/x/verror_code/Cflags/vflags2/x12/vtree_id/vprocess_id/vuser_id/vmultiplex_id/a*data", $packet);
	return $data;
}

function cifs_parse_transaction($packet) {
	$data = cifs_parse_header($packet);
	if($data["error_code"] != 0) return $data;
	$data["transaction_data"] = unpack("x7/vparam_length/vparam_offset/x2/vdata_length/vdata_offset/x7", $data["data"]);
	$data["parameters"] = substr($packet, $data["transaction_data"]["param_offset"], $data["transaction_data"]["param_length"]);
	$data["data"] = substr($packet, $data["transaction_data"]["data_offset"], $data["transaction_data"]["data_length"]);

	return $data;
}

function cifs_errcheck(&$smb) {
	$data = netbios_get_packet($smb["sock"]);
	$data = cifs_parse_header($data["data"]);
	if($data["error_code"] != 0) {
		$smb["error"] = cifs_strerror($data);
	} else {
		$smb["error"] = "";
	}
}

function cifs_negotiate($sock) {
	$packet = cifs_make_header(0x72);
	$packet .= chr(0); //no parameters

	$dialects = chr(2) . "PC NETWORK PROGRAM 1.0" . chr(0);
	$dialects .= chr(2) . "MICROSOFT NETWORKS 1.03" . chr(0);
	$dialects .= chr(2) . "MICROSOFT NETWORKS 3.0" . chr(0);
	$dialects .= chr(2) . "LANMAN1.0" . chr(0);
	$dialects .= chr(2) . "LM1.2x002" . chr(0);
	$dialects .= chr(2) . "DOS LANMAN2.1" . chr(0);
	$dialects .= chr(2) . "NT LANMAN 1.0" . chr(0);
	$dialects .= chr(2) . "NT LM 0.12" . chr(0);
	
	$packet .= pack("v", strlen($dialects));
	$packet .= $dialects;

	netbios_send_packet($sock, $packet);
	$data = netbios_get_packet($sock);
	$data = cifs_parse_header($data["data"]);
	if($data["error_code"] != 0) {
		print "Protocol negotiation error.";
		$retval = array();
		$retval["error"] = cifs_strerror($data);
		return $retval;
	}

	$smb = array();

	if($data["flags2"] & 0x8000) {
		$smb["unicode"] = 1;
	} else {
		$smb["unicode"] = 0;
	}

	$dialect = unpack("x/vdialect", $data["data"]);
	if($dialect["dialect"] < 6) {
		$smb["ntlm"] = 0;
		$smb["largeread"] = 0;
		$smb["largewrite"] = 0;
		$smb["extsec"] = 0;

		$capabilities = unpack("x3/vsecurity/x26/vkeylength", $data["data"]);
		if($capabilities["security"] & 0x2) {
			$smb["cryptpass"] = 1;
			$smb["challenge"] = substr($data["data"], 33, $capabilities["keylength"]);
		} else {
			$smb["cryptpass"] = 0;
		}
	} else {
		$smb["ntlm"] = 1;

		$capabilities = unpack("x3/Csecurity/x16/Vcapabilities/x10/Ckeylength", $data["data"]);
		if($capabilities["security"] & 2) {
			$smb["cryptpass"] = 1;
		} else {
			$smb["cryptpass"] = 0;
		}
		if($capabilities["capabilities"] & 0x4000) {
			$smb["largeread"] = 1;
		} else {
			$smb["largeread"] = 0;
		}
		if($capabilities["capabilities"] & 0x8000) {
			$smb["largewrite"] = 1;
		} else {
			$smb["largewrite"] = 0;
		}
		/*if($capabilities["capabilities"] & 0x80000000) {
			$smb["extsec"] = 1;
			$smb["challenge"] = substr($data["data"], 53);
			if(!$smb["challenge"]) { $smb["challenge"] = substr($data["data"], 37, 16); }
		} else {
			$smb["extsec"] = 0;
			$smb["challenge"] = substr($data["data"], 37, $capabilities["keylength"]);
		}*/
		$smb["extsec"] = 0;

		return $smb;
	}
}

function cifs_swab($instr) { //swap bits
	$outstr = "";
	for($i = 0; $i < strlen($instr); $i++) {
		$inb = ord(substr($instr, $i, 1));
		$outb = 0;
		if($inb & 0x01) { $outb |= 0x80; }
		if($inb & 0x02) { $outb |= 0x40; }
		if($inb & 0x04) { $outb |= 0x20; }
		if($inb & 0x08) { $outb |= 0x10; }
		if($inb & 0x10) { $outb |= 0x08; }
		if($inb & 0x20) { $outb |= 0x04; }
		if($inb & 0x40) { $outb |= 0x02; }
		if($inb & 0x80) { $outb |= 0x01; }
		$outstr .= chr($outb);
	}
	return $outstr;
}

function cifs_encrypt(&$smb) {
	//LanMan encryption
	$lanman_password = swab(pack("a14", strtoupper($smb["password"])));
	$n8 = chr(0x4B) . chr(0x47) . chr(0x53) . chr(0x21) . chr(0x40) . chr(0x23) . chr(0x24) . chr(0x25);
	$s21 =
		cifs_des(substr($lanman_password, 0, 7), $n8) .
		cifs_des(substr($lanman_password, 7, 7), $n8) .
		chr(0) . chr(0) . chr(0) . chr(0) . chr(0);
	$smb["lmpass"] =
		cifs_des(substr($s21, 0, 7), $smb["challenge"]) .
		cifs_des(substr($s21, 7, 7), $smb["challenge"]) .
		cifs_des(substr($s21, 14, 7), $smb["challenge"]);

	if($smb["ntlm"]) {
		//Convert password to null-terminated unicode
		$unipass = "";
		for($i = 0; $i < strlen($smb["password"]); $i++) {
			$unipass .= substr($smb["password"], $i, 1);
			$unipass .= chr(0);
		}
		$unipass .= chr(0) . chr(0);

		$s21 =  mhash(MHASH_MD4, $unipass) . str_repeat(chr(0), 5);
		$smb["ntpass"] =
			cifs_des(substr($s21, 0, 7), $smb["challenge"]) .
			cifs_des(substr($s21, 7, 7), $smb["challenge"]) .
			cifs_des(substr($s21, 14, 7), $smb["challenge"]);
	}
}

function cifs_authenticate(&$smb) {
	$packet = cifs_make_header(0x73, $smb);

	if(!$smb["ntlm"]) {
		$packet .= chr(10); //10 parameter words
		$packet .= chr(0xFF); //no secondary command
		$packet .= chr(0); //reserved
		$packet .= pack("v", 0); //no secondary command
		$packet .= pack("v", 4192); //maximum buffer size
		$packet .= pack("v", 2); //maximum pending requests
		$packet .= pack("v", 0); //first and only virtual circuit
		$packet .= pack("V", 0); //session key (not used - we're not doing VCs)

		//if(!$smb["cryptpass"]) {
			$encpass = $smb["password"];
		/*} else {
			cifs_encrypt($smb);
			$encpass = $smb["lmpass"];
		}*/
		$packet .= pack("v", strlen($encpass)) + 1;
		$packet .= pack("V", 0); //reserved


		$extradata .= $encpass . chr(0) .
				$smb["username"] . chr(0) .
				$smb["domain"] . chr(0) .
				"Unix" . chr(0) .
				"PHP-CIFS" . chr(0);

		$packet .= pack("v", strlen($extradata)) . $extradata;
	} else {
		/*if($smb["extsec"]) {
			$packet .= chr(12); //parameter words
			$packet .= chr(0xFF); //no secondary command
			$packet .= chr(0); //reserved
			$packet .= pack("v", 0); //no secondary command
			$packet .= pack("v", 0xFFFF); //maximum buffer size
			$packet .= pack("v", 2); //maximum pending requests
			$packet .= pack("v", 0); //first and only virtual circuit
			$packet .= pack("V", 0); //session key (not used - we're not doing VCs)

			$packet .= pack("v", 1); //one-byte security blob
			$packet .= pack("V", 0); //reserved
			$packet .= pack("V", 0x218); //flags - NT SMBs, large files

			$extradata = chr(0) . "Unix" . chr(0) . "PHP-CIFS" . chr(0);
			$packet .= pack("v", strlen($extradata)) . $extradata;
		} else {*/
			$packet .= chr(13); //parameter words
			$packet .= chr(0xFF); //no secondary command
			$packet .= chr(0); //reserved
			$packet .= pack("v", 0); //no secondary command
			$packet .= pack("v", 0xFFFF); //maximum buffer size
			$packet .= pack("v", 2); //max pending requests
			$packet .= pack("v", 0); //VC number
			$packet .= pack("V", 0); //session key (not used - we're not doing VCs)
			$packet .= pack("v", 1); //ANSI password length
			$packet .= pack("v", 2); //Unicode password length
			$packet .= pack("V", 0); //reserved
			$packet .= pack("V", 0x218); //flags - NT SMBs, large files

			$extradata = str_repeat(chr(0), 3); //passwords
			$extradata .=
				cifs_str2uni($smb, "") . //username
				cifs_str2uni($smb, "") . //workgroup
				cifs_str2uni($smb, "Unix") . //native OS
				cifs_str2uni($smb, "PHP-CIFS"); //native LanMan
			$packet .= pack("v", strlen($extradata)) . $extradata;
		//}
	}

	netbios_send_packet($smb["sock"], $packet);
	$data = netbios_get_packet($smb["sock"]);
	$data = cifs_parse_header($data["data"]);
	if($data["error_code"] != 0) {
		$smb["error"] = cifs_strerror($data);
		return;
	} else {
		$smb["error"] = "";
		$smb["user_id"] = $data["user_id"];
	}
}

function cifs_disconnect_share(&$smb) {
	$packet = cifs_make_header(0x71, $smb);
	$packet .= chr(0);
	$packet .= pack("v", 0);
	netbios_send_packet($smb["sock"], $packet);
	cifs_errcheck($smb);
	$smb["tree_id"] = 0xFFFF;
}

function cifs_connect_share(&$smb, $share) {
	if($smb["tree_id"] != 0xFFFF) cifs_disconnect_share($smb);
	$packet = cifs_make_header(0x75, $smb);
	$packet .= chr(4); //parameter count
	$packet .= chr(0xFF); //no secondary command
	$packet .= chr(0); //reserved
	$packet .= pack("v", 0); //no secondary command
	$packet .= pack("v", 0); //flags
	$packet .= pack("v", 1); //null password

	$extradata = chr(0) .
		cifs_str2uni($smb, "\\\\" . $smb["server_name"] . "\\" . $share) .
		"?????" . chr(0);
	$packet .= pack("v", strlen($extradata)) . $extradata;

	netbios_send_packet($smb["sock"], $packet);
	$data = netbios_get_packet($smb["sock"]);
	$data = cifs_parse_header($data["data"]);
	if($data["error_code"] != 0) {
		$smb["error"] = cifs_strerror($data);
		return;
	} else {
		$smb["error"] = "";
		$smb["tree_id"] = $data["tree_id"];
	}
}

//transact_ver 1 is for SMB_COM_TRANSACTION2 request.
//transact_ver 2 is for SMB_COM_NT_TRANSACT
function cifs_make_transaction(&$smb, $transact_ver, $name, $setup, $parameters, $data) {
	if($transact_ver == 1) {
		$name = cifs_str2uni($smb, $name);
	} else {
		$setup = pack("v", $setup);
	}

	if($transact_ver == 1) {
		$packet = cifs_make_header(0x25, $smb);
	} else {
		$packet = cifs_make_header(0x32, $smb);
	}
	$packet .= chr(14 + strlen($setup)/2); //parameter word count
	$packet .= pack("v", strlen($parameters)); //parameter byte count
	$packet .= pack("v", strlen($data)); //data count
	$packet .= pack("v", 64); //max parameter count
	$packet .= pack("v", 4192); //max data count
	$packet .= chr(0); //max setup count
	$packet .= chr(0); //reserved
	$packet .= pack("v", 0); //flags
	$packet .= pack("V", 0); //timeout
	$packet .= pack("v", 0); //reserved

	$paramoffset = 63 + strlen($name) + strlen($setup);
	if($transact_ver == 1) {
		if($smb["unicode"]) {
			$padlength = 1;
		} else {
			$padlength = 0;
		}
	} else {
		$padlength = 4 - ($paramoffset % 4);
	}
	$paramoffset += $padlength;
	$dataoffset = $paramoffset + strlen($parameters);
	if($transact_ver == 1) {
		$datapadlength = 0;
	} else {
		$datapadlength = 4 - (strlen($parameters) % 4);
	}
	$dataoffset += $datapadlength;

	$packet .= pack("v", strlen($parameters)); //parameter byte count this packet
	$packet .= pack("v", $paramoffset); //parameter offset (from header start)
	$packet .= pack("v", strlen($data)); //data bytes sent this buffer
	$packet .= pack("v", $dataoffset); //data offset (from header start)
	$packet .= chr(strlen($setup) / 2); //setup count (in words)
	$packet .= chr(0); //reserved
	$packet .= $setup;
	$packet .= pack("v", $padlength + strlen($name) + strlen($parameters) + $datapadlength + strlen($data)); //Count of data bytes
	$packet .= str_repeat(chr(0), $padlength);
	$packet .= $name . $parameters;
	$packet .= str_repeat(chr(0), $datapadlength);
	$packet .= $data;

	return $packet;
}

function cifs_readdir(&$smb, $path) {
	$data = pack("v", 0x37); //search attributes - include everything
	$data .= pack("v", 512); //maximum number of entries to return
	$data .= pack("v", 0x2); //flags - close search if end reached
	$data .= pack("v", 0x103); //SMB_FIND_FILE_NAMES_INFO
	$data .= pack("V", 0);
	if(substr($path, strlen($path) - 1, 1) != "\\") $path .= "\\";
	$data .= cifs_str2uni($smb, "$path*");

	$packet = cifs_make_transaction($smb, 2, "", 1, $data, "");

	netbios_send_packet($smb["sock"], $packet);
	$data = netbios_get_packet($smb["sock"]);
	$data = cifs_parse_transaction($data["data"]);
	if($data["error_code"] != 0) {
		$smb["error"] = cifs_strerror($data);
		return;
	} else {
		$smb["error"] = "";
	}

	$files = array();
	$searchdata = array();
	$first = 1;
	$id = 0;

	while(!$searchdata["end"]) {
		$dataoffset = 0;
		if($first) {
			$searchdata = unpack("vid/vcount/vend/x2/vlastname", $data["parameters"]);
			$first = 0;
			$id = $searchdata["id"];
		} else {
			$searchdata = unpack("vcount/vend/x2/vlastname", $data["parameters"]);
		}
		$dirdata = $data["data"];
		if($searchdata["lastname"]) {
			if($smb["unicode"]) {
				$terminator = chr(0).chr(0);
			} else {
				$terminator = chr(0);
			}
			$lastname = substr($dirdata, $searchdata["lastname"], strpos($dirdata, $terminator) + 1);
		} else {
			$lastname = "";
		}

		for($i = 0; $i < $searchdata["count"]; $i++) {
			$dirinfo = unpack("Vnextoffset/x4/Vnamelen", substr($dirdata, $dataoffset, 12));
			$files[] = cifs_uni2str($smb, substr($dirdata, $dataoffset+12, $dirinfo["namelen"]));
			$dataoffset += $dirinfo["nextoffset"];
		}

		if(!$searchdata["end"]) {
			$data = pack("v", $id);
			$data .= pack("v", 512); //maximum number of entries to return
			$data .= pack("v", 0x103); //SMB_FIND_FILE_NAMES_INFO
			$data .= pack("V", 0); //not using resume keys
			$data .= pack("v", 0xA); //flags - close search if end reached
			$data .= $lastname;

			$packet = cifs_make_transaction($smb, 2, "", 2, $data, "");

			netbios_send_packet($smb["sock"], $packet);
			$data = netbios_get_packet($smb["sock"]);
			$data = cifs_parse_transaction($data["data"]);
			if($data["error_code"] != 0) {
				$smb["error"] = cifs_strerror($data);
				return;
			} else {
				$smb["error"] = "";
			}
		}
	}

	return $files;
}

function cifs_pathinfo(&$smb, $path) {
	$data = pack("v", 1); //SMB_QUERY_INFO_STANDARD
	$data .= pack("V", 0); //reserved
	$data .= cifs_str2uni($smb, $path);

	$packet = cifs_make_transaction($smb, 2, "", 5, $data, "");

	netbios_send_packet($smb["sock"], $packet);
	$data = netbios_get_packet($smb["sock"]);
	$data = cifs_parse_transaction($data["data"]);
	if($data["error_code"] != 0) {
		$smb["error"] = cifs_strerror($data);
		return;
	} else {
		$smb["error"] = "";
	}

	$pathinfo = unpack("x12/Vsize/x4/vattributes", $data["data"]);

	if($pathinfo["attributes"] & 0x10) {
		$pathinfo["is_directory"] = 1;
	} else {
		$pathinfo["is_directory"] = 0;
	}


	$data = pack("v", 0x107); //SMB_QUERY_FILE_ALL_INFO
	$data .= pack("V", 0); //reserved
	$data .= cifs_str2uni($smb, $path);

	$packet = cifs_make_transaction($smb, 2, "", 5, $data, "");

	netbios_send_packet($smb["sock"], $packet);
	$data = netbios_get_packet($smb["sock"]);
	$data = cifs_parse_transaction($data["data"]);

	$temp = unpack("x58/Vinode_low/Vinode_high", $data["data"]);
	$pathinfo["inode_low"] = $temp["inode_low"];
	$pathinfo["inode_high"] = $temp["inode_high"];

	return $pathinfo;
}

function cifs_str2uni(&$smb, $str) {
	if(!$smb["unicode"]) { return $str . chr(0); }
	$out = "";
	for($i = 0; $i < strlen($str); $i++) {
		$out .= substr($str, $i, 1);
		$out .= chr(0);
	}
	return $out . chr(0) . chr(0);
}

function cifs_uni2str(&$smb, $uni) {
	if($smb["unicode"]) {
		$null = strpos($uni, chr(0) . chr(0));
		if($null !== false) {
			$uni = substr($uni, 0, $null);
		}
	} else {
		$null = strpos($uni, chr(0));
		if($null === false) {
			return $uni;
		} else {
			return substr($uni, 0, $null);
		}
	}
	$out = "";
	for($i = 0; $i < strlen($uni); $i += 2) {
		$out .= substr($uni, $i, 1);
	}
	return $out;
}

function cifs_enum_shares(&$smb) {
	cifs_connect_share($smb, "IPC\$");
	if($smb["error"]) return;

	$data = pack("v", 0); //NetShareEnum
	$data .= "WrLeh" . chr(0); //parameter descriptor
	$data .= "B13BWz" . chr(0); //return descriptor
	$data .= pack("v", 1); //detail level
	$data .= pack("v", 65504); //return buffer length

	$packet = cifs_make_transaction($smb, 1, "\\PIPE\\LANMAN", "", $data, "");


	netbios_send_packet($smb["sock"], $packet);
	$data = netbios_get_packet($smb["sock"]);
	$data = cifs_parse_header($data["data"]);
	if($data["error_code"] != 0) {
		$smb["error"] = cifs_strerror($data);
		return;
	} else {
		$smb["error"] = "";
	}

	$data["data"] = substr($data["data"], 28);
	$sharedata = unpack("ventries", $data["data"]);
	$shares = array();
	$data = substr($data["data"], 4);
	for($i = 0; $data && $i < $sharedata["entries"]; $i++) {
		$shareinfo = unpack("a13name/x/vtype", $data);
		$shares[$shareinfo["name"]] = $shareinfo["type"];
		$data = substr($data, 20);
	}

	cifs_disconnect_share($smb);

	return $shares;
}

function cifs_logout(&$smb) {
	$packet = cifs_make_header(0x74, $smb);
	$packet .= chr(2); //parameter count
	$packet .= chr(0xFF); //no secondary command
	$packet .= chr(0); //reserved
	$packet .= pack("v", 0); //no secondary command
	$packet .= pack("v", 0); //no data bytes

	netbios_send_packet($smb["sock"], $packet);
	cifs_errcheck($smb);
}

function cifs_connect($client_name, $server_name, $wins_server, $username = "", $password = "", $domainname = "") {
	$retval = array();
	$retval["error"] = 0;

	$client_name = strtoupper($client_name);
	$server_name = strtoupper($server_name);

	$address = wins_lookup($wins_server, $server_name);
	if($address == "") {
		$retval["error"] = "WINS error";
		return $retval;
	}

	$sock = fsockopen($address, 139);
	if(!$sock) {
		$retval["error"] = 1;
		return $retval;
	}

	$retval["error"] = netbios_session_start($sock, $client_name, $server_name);
	if($retval["error"]) return $retval;


	$retval = cifs_negotiate($sock);
	if($retval["error"]) return $retval;

	$retval["sock"] = $sock;
	$retval["address"] = $address;
	$retval["client_name"] = $client_name;
	$retval["server_name"] = $server_name;
	$retval["wins_server"] = $wins_server;
	$retval["tree_id"] = 0xFFFF;
	$retval["user_id"] = 0;
	$retval["username"] = $username;
	$retval["password"] = $password;

	cifs_authenticate($retval);

	return $retval;
}

?>
