<?

header("Content-type: text/xml");
ob_start();
db_start();

$extension = "92896";

function cisco_error($title, $msg) { _cisco_text($title, $msg, "error"); }
function cisco_message($title, $msg, $url = "index.xml") { _cisco_text($title, $msg, "message", $url); }

function _cisco_text($title, $msg, $type, $url = "") {
	ob_end_clean();

	
	echo <<<END
<CiscoIPPhoneText>
<Title>$title</Title>
<Text>$msg</Text>
<SoftKeyItem>
END
;

	if($type == "error") {
		echo "<Name>Back</Name>\n<URL>SoftKey:Back</URL>\n";
	} else {
		echo "<Name>OK</Name>\n<URL>$url</URL>\n";
	}

	echo "</SoftKeyItem>\n</CiscoIPPhoneText>\n";
	exit;
}

?>
