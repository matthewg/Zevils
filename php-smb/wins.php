<?
/* From RFC 1001:
 *   The 16 byte NetBIOS name is mapped into a 32 byte wide field using a
 *   reversible, half-ASCII, biased encoding.  Each half-octet of the
 *   NetBIOS name is encoded into one byte of the 32 byte field.  The
 *   first half octet is encoded into the first byte, the second half-
 *   octet into the second byte, etc.
 *
 *   Each 4-bit, half-octet of the NetBIOS name is treated as an 8-bit,
 *   right-adjusted, zero-filled binary number.  This number is added to
 *   value of the ASCII character 'A' (hexidecimal 41).  
*/

$netbios_transaction_id = 0;

// Borrowed from SAMBA...
function netbios_get_transaction_id() {
	if($netbios_transaction_id == 0) { //seed it
		$netbios_transaction_id = (time() % 0x7FFF) + (getmypid() % 100);
	}
	$netbios_transaction_id = ($netbios_transaction_id + 1) % 0x7FFF;
	return $netbios_transaction_id;
}

function netbios_encode_name($instr, $type = 0) {
	$outstr = "";
	$instr = strtoupper($instr);
	while(strlen($instr) < 15) { $instr .= " "; }
	$instr .= chr($type);
	for($i = 0; $i < strlen($instr); $i++) {
		$char = ord(substr($instr, $i, 1));
		$char_low = chr(($char & 0xF) + ord('A'));
		$char_high = chr((($char >> 4) & 0xF) + ord('A'));
		$outstr .= $char_high . $char_low;
	}
	return chr(strlen($outstr)) . $outstr . chr(0);
}

function wins_lookup($server, $name) {
	$packet = pack("nnnnnn",
		netbios_get_transaction_id(),
		0x140, //flags - recursion desired
		1, //questions
		0, //answers
		0, //authoritative name servers
		0  //additional resource records
	);
	$packet .= netbios_encode_name($name);
	$packet .= pack("nn",
		0x20, // NetBIOS Name request
		1 //Internet class
	);

	$sock = fsockopen("udp://$server", 137, $wins_errno, $wins_errstr);
	if(!$sock) {
		echo "ERROR: $wins_errno - $wins_errstr<br>\n";
		return "";
	}

	if(!fwrite($sock, $packet)) {
		echo "Couldn't write.<br>\n";
		return "";
	}

	if(!($packet = fread($sock, 4))) {
		echo "Couldn't read.<br>\n";
		return "";
	}

	$data = unpack("ntransaction_id/nflags", $packet);
	$retcode = $data["flags"] & 0xF;
	if($retcode != 0) {
		echo "Error $retcode from server<br>\n";
		return "";
	}

	if(!($packet = fread($sock, 8))) {
		echo "Couldn't read again.<br>\n";
		return "";
	}
	$data = unpack("nquestions/nanswers/nauthoritative/nadditional", $packet);

	if($data["answers"] != 1) {
		echo "No response (" . $data["answers"] . ") answers<br>\n";
		return "";
	}

	$answer = substr($packet, 12);

	//Strip out the NetBIOS name
	$nodelength = 1;
	while($nodelength != 0) {
		$packet = fread($sock, 1);
		$nodelength = ord($packet);
		fread($sock, $nodelength);
	}

	fread($sock, 8); //Skip type, class, and TTL
	$packet = fread($sock, 2);
	$data = unpack("nlength", $packet);
	$packet = fread($sock, $data["length"]);
	$address_binary = substr($packet, 2); //skip flags

	$address_text = ord(substr($address_binary, 0, 1)) . "." .
			ord(substr($address_binary, 1, 1)) . "." .
			ord(substr($address_binary, 2, 1)) . "." .
			ord(substr($address_binary, 3, 1));
	

	fclose($sock);

	return $address_text;
}
