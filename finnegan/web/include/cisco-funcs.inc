<?

header("Content-type: text/xml");
ob_start();

function cisco_error($title, $errmsg) {
	ob_end_clean();

	echo <<<END
<CiscoIPPhoneText>
<Title>$title</Title>
<Text>$errmsg</Text>
</CiscoIPPhoneText>
END
;

	exit;
}

?>
