<?

header("Content-type: text/xml");
header("Expires: -1"); //Don't add pages to browser history -- otherwise, SoftKey:Exit won't work

ob_start();
db_start();

$extension = "70002";

function cisco_error($title, $msg, $url = "") { _cisco_text($title, $msg, "error", $url); }
function cisco_message($title, $msg, $url = "") {
	global $FinneganCiscoConfig;
	_cisco_text($title, $msg, "message", $url);
}

function _cisco_text($title, $msg, $type, $url = "") {
	global $FinneganCiscoConfig;
	ob_end_clean();

	if(!$url) $url = current_url();
	echo <<<END
<CiscoIPPhoneText>
<Title>$title</Title>
<Text>$msg</Text>
<SoftKeyItem>
<Position>1</Position>
END
;

	if($type == "error") {
		echo "<Name>Back</Name>\n<URL>".htmlentities($url)."</URL>\n";
	} else {
		echo "<Name>OK</Name>\n<URL>".htmlentities($url)."</URL>\n";
	}

?>
</SoftKeyItem>
</CiscoIPPhoneText>
<?
	exit;
}

?>
