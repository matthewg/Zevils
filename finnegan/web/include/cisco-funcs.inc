<?

header("Content-type: text/xml");
header("Expires: -1"); //Don't add pages to browser history -- otherwise, SoftKey:Exit won't work

ob_start();
db_start();

$extension = get_extension();


function get_extension() {
	$phonepage = implode("", @file("http://".$_SERVER["REMOTE_HOST"]));
	if(!$phonepage) {
		cisco_message("Invalid Extension", "Cannot find your extension");
	} else if(!preg_match("!Phone DN.*?<TD>[0-9]*([6-9][0-9]{4})</TD>!mi", $phonepage, $matches)) {
		cisco_message("Invalid Extension", "Cannot parse extension information");
	} else {
		return $matches[1];
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
