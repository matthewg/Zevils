<?

header("Content-type: text/xml");
header("Expires: -1"); //Don't add pages to browser history -- otherwise, SoftKey:Exit won't work

ob_start();
db_start();

$extension = get_extension();

function get_extension() {
	$phonepage = implode("", @file("http://".$_SERVER["REMOTE_ADDR"]."/"));
	if(!$phonepage) {
		cisco_message("Invalid Extension", "Cannot find your extension: " . $_SERVER["REMOTE_ADDR"]);
	} else if(!preg_match("!Phone DN.*?<TD>[0-9]*([6-9][0-9]{4})\\b!mi", $phonepage, $matches)) {
		cisco_message("Invalid Extension", "Cannot parse extension information");
	} else {
		$check = extension_check($matches[1]);
		if($check) {
			if($check == "extension_invalid")
				cisco_message("Invalid Extension", "Your extension, $matches[1], is invalid.");
			else if($check == "extension_forbidden")
				cisco_message("Forbidden Extension", "Your extension, $matches[1], may not use this service.");
			else
				cisco_message("Unknown Extension Error", "There was an unknown problem with your extension, $matches[1].  The error was '$check'.");
		} else {
			return $matches[1];
		}
	}
}

function cisco_message($title, $msg, $url = "") {
	ob_end_clean();

	if(!$url) $url = current_url();
?>
<CiscoIPPhoneText>
<Title><? echo $title ?></Title>
<Text><? echo $msg ?></Text>
<SoftKeyItem>
<Name>OK</Name>
<URL><? echo htmlentities($url) ?></URL>
<Position>1</Position>
</SoftKeyItem>
</CiscoIPPhoneText>
<?
	exit;
}

?>
