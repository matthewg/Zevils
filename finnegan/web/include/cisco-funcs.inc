<?

header("Content-type: text/xml");
header("Expires: -1"); //Don't add pages to browser history -- otherwise, SoftKey:Exit won't work

ob_start();
db_start();

$extension = get_extension();

function get_extension() {
	global $PHONE_MODEL;

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
			$extension = $matches[1];

			if(preg_match("!Product ID.*?<TD>(.*)!mi", $phonepage, $matches))
				$PHONE_MODEL = $matches[1];
			else
				$PHONE_MODEL = "";

			return $extension;
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

function format_wake($wake) {
	$time_array = time_to_user($wake["time"]);
	$time = "$time_array[0] $time_array[1]";

	if($wake["disabled"])
		$x = "[OFF] ";
	else
		$x = "[ON]  ";

	if($wake["date"]) {
		$date = date_to_user($wake["date"]);
                return "$x$time; $date";
	} else {
		$days = explode(",", $wake["weekdays"]);
		for($i = 0; $i < count($days); $i++) $days[$i] = ucfirst($days[$i]);
		$daytext = implode(", ", $days);

		if($wake["cal_type"] == "normal")
			$cal = "Regular";
		else if($wake["cal_type"] == "holidays")
			$cal = "National Holidays";
		else if($wake["cal_type"] == "Brandeis")
			$cal = "Brandeis";

		return "$x$time; $daytext; $cal";
        }
}

?>
