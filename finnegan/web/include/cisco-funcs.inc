<?

header("Content-type: text/xml");

//THIS BREAKS 7940/7960!  Alas, this means no SoftKey:Exit.
//header("Expires: -1"); //Don't add pages to browser history -- otherwise, SoftKey:Exit won't work

ob_start("nlstrip");
db_start();

$extension = get_extension();

function nlstrip($contents) {
	return str_replace("\n", "", $contents);
}

function get_extension() {
	global $PHONE_MODEL;

	return "92896"; //if($_SERVER["REMOTE_ADDR"] == "127.0.0.1") return "92896";

	# Cache phone webpages, otherwise phones hate us
	$extension = "";
	$is_cached = 0;
	$fp = @fopen("/tmp/extmap.". $_SERVER["REMOTE_ADDR"], "r");
	if($fp) {
		$extension = @fgets($fp);
		$is_cached = 1;
	}
	@fclose($fp);

	if(!$is_cached) {
		$phonepage = implode("", @file("http://".$_SERVER["REMOTE_ADDR"]."/"));

		if(!$phonepage) {
			cisco_message("Invalid Extension", "Cannot find your extension: " . $_SERVER["REMOTE_ADDR"]);
		} else if(!preg_match("!Phone DN.*?<TD>(?:<[^>]*>)*[0-9]*([0-9]{5})\\b!si", $phonepage, $matches)) {
			cisco_message("Invalid Extension", "Cannot parse extension information");
		} else {
			$extension = $matches[1];
		}
	}

	$check = extension_check($extension);
	if($check) {
		if($check == "extension_invalid")
			cisco_message("Invalid Extension", "Your extension, $matches[1], is invalid.");
		else if($check == "extension_forbidden")
			cisco_message("Forbidden Extension", "Your extension, $matches[1], may not use this service.");
		else
			cisco_message("Unknown Extension Error", "There was an unknown problem with your extension, $matches[1].  The error was '$check'.");
	} else {
		if(preg_match("!Product ID.*?<TD>(.*)!mi", $phonepage, $matches))
			$PHONE_MODEL = $matches[1];
		else
			$PHONE_MODEL = "";

		if(!$is_cached) {
			$fp = @fopen("/tmp/extmap.". $_SERVER["REMOTE_ADDR"], "w");
			if($fp) fwrite($fp, "$extension");
			@fclose($fp);
		}
		return $extension;
	}
}

function cisco_message($title, $msg, $url = "") {
	ob_clean();

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
