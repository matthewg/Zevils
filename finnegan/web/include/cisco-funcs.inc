<?

header("Content-type: text/xml");
ob_start();
db_start();

$extension = "6000";

function cisco_error($title, $msg) { _cisco_text($title, $msg, "error"); }
function cisco_message($title, $msg, $url = "") {
	if(!$url) $url = $FinneganCiscoConfig->url_base."/service/index.php";
	_cisco_text($title, $msg, "message", $url);
}

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

?>
</SoftKeyItem>
<SoftKeyItem>
<Name>About</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/about.php</URL>
</SoftKeyItem>
</CiscoIPPhoneText>
<?
	exit;
}

?>
