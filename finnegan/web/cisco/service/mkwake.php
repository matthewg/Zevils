<?

$cisco = 1;
require "../../include/finnegan.inc";
require "../../include/mkwake-funcs.inc";

// Initialize variables for editing an existing wake
if(isset($_REQUEST["id"]) && $_REQUEST["id"] && preg_match('/^[0-9]+$/', $_REQUEST["id"])) {
	$id = $_REQUEST["id"];
	if(!isset($_REQUEST["prompt"])) { //We only need to load from DB the first time - afterwards, everything's in the query string
		$result = @mysql_query("SELECT * FROM wakes WHERE extension='$extension' AND wake_id=$id");
		if(!$result) db_error();
		if(!mysql_num_rows($result)) cisco_error("Invalid Alarm", "Please select a valid alarm.");
		$wake = mysql_fetch_assoc($result);

		$time_array = time_to_user($wake["time"]);
		$time = preg_replace("/:/", "", $time_array[0]);
		$ampm = $time_array[1];

		$date = preg_replace("/\\//", "", date_to_user($wake["date"]));
		if($date)
			$type = "one-time";
		else
			$type = "recurring";

		$message = $wake["message"];

		if($wake["weekdays"]) {
			$wakedays = explode(",", $wake["weekdays"]);
			for($i = 0; $i < sizeof($wakedays); $i++) {
				$weekdays[$wakedays[$i]] = 1;
			}
		} else {
			$weekdays = array();
		}

		$cal_type = $wake["cal_type"];
	}
} else {
	$id = "";
	$weekdays = array();
}

// Grab variables from query string
$playmsg = isset($_REQUEST["playmsg"]) ? $_REQUEST["playmsg"] : "";
$prompt = isset($_REQUEST["prompt"]) ? $_REQUEST["prompt"] : "init";
if(isset($_REQUEST["weekdays"])) $weekdays = $_REQUEST["weekdays"];

if($id) {
	if(isset($_REQUEST["time"])) $time = $_REQUEST["time"];
	if(isset($_REQUEST["ampm"])) $ampm = $_REQUEST["ampm"];
	if(isset($_REQUEST["message"])) $message = $_REQUEST["message"];
	if(isset($_REQUEST["type"])) $type = $_REQUEST["type"];
	if(isset($_REQUEST["date"])) $date = $_REQUEST["date"];
	if(isset($_REQUEST["cal_type"])) $cal_type = $_REQUEST["cal_type"];
} else {
	$playmsg = isset($_REQUEST["playmsg"]) ? $_REQUEST["playmsg"] : "";
	$prompt = isset($_REQUEST["prompt"]) ? $_REQUEST["prompt"] : "init";
	$time = isset($_REQUEST["time"]) ? $_REQUEST["time"] : "";
	$ampm = isset($_REQUEST["ampm"]) ? $_REQUEST["ampm"] : "";
	$message = isset($_REQUEST["message"]) ? $_REQUEST["message"] : "";
	$type = isset($_REQUEST["type"]) ? $_REQUEST["type"] : "";
	$date = isset($_REQUEST["date"]) ? $_REQUEST["date"] : "";
	if(isset($_REQUEST["weekdays"])) $weekdays = $_REQUEST["weekdays"];
	$cal_type = isset($_REQUEST["cal_type"]) ? $_REQUEST["cal_type"] : "";
}


$the_weekdays = array("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun");
for($i = 0; $i < sizeof($the_weekdays); $i++) {
	if(!isset($weekdays[$the_weekdays[$i]])) $weekdays[$the_weekdays[$i]] = "";
}



if($playmsg) {
	cisco_error("Message Playing", "Playing message...", "Play:".$FinneganCiscoConfig->tftp_prefix."finmsg-$message");
}


$title = "";

// Do error-checking on whichever setting we're up to
if($prompt == "time" && $time) {
	if(!preg_match('/^(\d\d?)(\d\d)$/', $time, $matches)) {
		$title = "Invalid Time";
	} else {
		$hours = $matches[1];
		$minutes = $matches[2];
		if($hours < 0 || $hours > 12 || $minutes < 0 || $minutes > 59) {
			$title = "Invalid Time";
		} else {
			$prompt = "ampm";
		}
	}
} else if($prompt == "ampm" && $ampm) {
	if($ampm != "AM" && $ampm != "PM") {
		$title = "Invalid AM/PM";
		$ampm = "";
	} else {
		$prompt = "message";
	}
} else if($prompt == "message" && $message) {
	if(!preg_match('/^[0-9]+$/', $message) || $message < -1 || $message > sizeof($FinneganConfig->messages)) {
		$title = "Invalid Message";
		$message = "";
	} else {
		$prompt = "type";
	}
} else if($prompt == "type" && $type) {
	if($type != "one-time" && $type != "recurring") {
		$title = "Invalid Type";
	} else if($type == "one-time") {
		$prompt = "date";
	} else {
		$prompt = "weekdays";
	}
} else if($prompt == "date" && $date) {
	if(!preg_match('/^(\d\d?)(\d\d)$/', $date, $matches)) {
		$title = "Invalid Date";
	} else {
		$month = $matches[1];
		$day = $matches[2];
		if($month < 1 || $month > 12 || $day < 1 || $day > 31) {
			$title = "Invalid Date";
		} else {
			$prompt = "done";
		}
	}
} else if($prompt == "weekdays" && $weekdays) {
	$daycount = 0;
	while(list($day, $val) = each($weekdays)) {
		if($val) $daycount++;
	}
	if(!$daycount) {
		$title = "Select Weekdays";
	} else {
		$prompt = "cal_type";
	}
} else if($prompt == "cal_type" && $cal_type) {
	if($cal_type != "Brandeis" && $cal_type != "holidays" && $cal_type != "normal") {
		$title = "Invalid Calendar Type";
		$cal_type = "";
	} else {
		$prompt = "done";
	}
}


// Database INSERT/UPDATE time?
if($prompt == "done") {
	$error = "";
	$weekday_map = array("Sun" => 1, "Mon" => 2, "Tue" => 3, "Wed" => 4, "Thu" => 5, "Fri" => 6, "Sat" => 7);

	if(preg_match('/^(\d\d?):?(\d\d)$/', $time, $matches))
		$time = "$matches[1]:$matches[2]";
	else
		$error = "Invalid Time";
	if($ampm != "AM" && $ampm != "PM") $error = "Invalid Time";
	$sql_time = time_to_sql($time, $ampm);

	if(!preg_match('/^\d+$/', $message)) $error = "Invalid Message";

	if($type == "one-time") {
		if(preg_match('/^(\d\d?)\\/?(\d\d)$/', $date, $matches))
			$sql_date = date_to_sql("$matches[1]/$matches[2]", $sql_time);
		else
			$error = "Invalid Date";
		$sql_cal_type = "";
		$sql_weekdays = array();
	} else {
		$sql_date = "";
		if($cal_type != "Brandeis" && $cal_type != "holidays" && $cal_type != "normal") $error = "Invalid Calendar Type";
		$sql_cal_type = $cal_type;

		reset($weekdays);
		$sql_weekdays = array();
		while(list($day, $val) = each($weekdays)) {
			if($val) $sql_weekdays[] = $day;
		}
	}


	if($error) {
		$title = $error;
		$prompt = "time";
	} else {
		if($type == "one-time") {
			if(!is_time_free($id, $sql_time, "", "", $sql_date)) $error = "Time Unavailable";
		} else {
			reset($weekdays);
			$baddays = array();
			while(list($name, $val) = each($weekdays)) {
				if($val && !is_time_free($id, $sql_time, $weekday_map[$name], $sql_cal_type)) {
					$baddays[] = $name;
				}
			}
			if(sizeof($baddays) > 0) $error = "Time Unavailable on " . implode(", ", $baddays);
		}

		if($error) {
			$title = $error;
			$prompt = "time";
		} else {
			set_wake($id, $sql_time, $message, $type, $sql_date, $sql_weekdays, $sql_cal_type);
			if($id) {
				cisco_message("Alarm Modified", "Your alarm was modified.", $FinneganCiscoConfig->url_base."/service/wakes.php");
			} else {
				cisco_message("Alarm Created", "Your alarm was created.", $FinneganCiscoConfig->url_base."/service/wakes.php");
			}
		}
	}
}



if(!$title) {
	if($prompt == "time" || $prompt == "init")
		$title = "Enter Time";
	else if($prompt == "ampm")
		$title = "AM or PM?";
	else if($prompt == "message")
		$title = "Select Wake-up Message";
	else if($prompt == "type")
		$title = "Select Alarm Type";
	else if($prompt == "date")
		$title = "Enter Date";
	else if($prompt == "weekdays")
		$title = "Select Alarm Days";
	else if($prompt == "cal_type")
		$title = "Select Calendar Type";

}

if($prompt == "init") $prompt = "time";

$url = $FinneganCiscoConfig->url_base."/service/mkwake.php?id=$id&amp;prompt=$prompt";
if($prompt != "time") $url .= "&amp;time=$time";
if($prompt != "ampm") $url .= "&amp;ampm=$ampm";
if($prompt != "message") $url .= "&amp;message=$message";
if($prompt != "type") $url .= "&amp;type=$type";
if($prompt != "date") $url .= "&amp;date=$date";
if($prompt != "weekdays") {
	reset($weekdays);
	while(list($day, $val) = each($weekdays)) {
		$url .= "&amp;weekdays[$day]=$val";
	}
}
if($prompt != "cal_type") $url .= "&amp;cal_type=$cal_type";

if($prompt == "time" || $prompt == "date") {
	$seltype = "CiscoIPPhoneInput";
} else {
	$seltype = "CiscoIPPhoneMenu";
}


echo "<$seltype>\n<Title>$title</Title>\n";
if($seltype == "CiscoIPPhoneInput") echo "<URL>$url</URL>\n";

if($prompt == "time") {

?>
<InputItem>
<DisplayName>Time (8:06 AM = '806')</DisplayName>
<QueryStringParam>time</QueryStringParam>
<? if($time) echo "<DefaultValue>$time</DefaultValue>\n"; ?>
<InputFlags>N</InputFlags>
</InputItem>

<? } else if($prompt == "ampm") {

	if($ampm) echo "<MenuItem>\n<Name>Current Value ($ampm)</Name>\n<URL>$url&amp;ampm=$ampm</URL>\n</MenuItem>\n";
?>
<MenuItem>
<Name>AM</Name>
<URL><?echo "$url&amp;ampm=AM" ?></URL>
</MenuItem>
<MenuItem>
<Name>PM</Name>
<URL><?echo "$url&amp;ampm=PM" ?></URL>
</MenuItem>

<? } else if($prompt == "message") {

	if($message) echo "<MenuItem>\n<Name>Current Value (".($message+1).")</Name>\n<URL>$url&amp;message=$message</URL>\n</MenuItem>\n";
	for($i = 0; $i < sizeof($FinneganConfig->messages); $i++) {
		printf("<MenuItem>\n<Name>%s</Name>\n<URL>%s</URL>\n</MenuItem>\n",
			$FinneganConfig->messages[$i]["message"],
			"$url&amp;message=".$FinneganConfig->messages[$i]["id"]
		);
	}
	echo "<MenuItem>\n<Name>Random Message</Name>\n<URL>$url$amp;message=-1</URL>\n</MenuItem>\n";
	echo "<SoftKeyItem>\n<Name>Preview</Name>\n<URL>QueryStringParam:playmsg=1</URL>\n</SoftKeyItem>\n";
	echo "<SoftKeyItem>\n<Name>__</Name>\n<URL>$url&amp;message=0</URL>\n</SoftKeyItem>\n";

} else if($prompt == "type") {

	if($type) echo "<MenuItem>\n<Name>Current Value ($type)</Name>\n<URL>$url&amp;type=$type</URL>\n</MenuItem>\n";
?>
<MenuItem>
<Name>One-Time (a specific date)</Name>
<URL><?echo "$url&amp;type=one-time" ?></URL>
</MenuItem>
<MenuItem>
<Name>Recurring (every day on specific days of the week)</Name>
<URL><?echo "$url&amp;type=recurring" ?></URL>
</MenuItem>

<? } else if($prompt == "date") { ?>

<InputItem>
<DisplayName>Date (Jan. 2nd = '102')</DisplayName>
<QueryStringParam>date</QueryStringParam>
<? if($date) echo "<DefaultValue>$date</DefaultValue>\n"; ?>
<InputFlags>N</InputFlags>
</InputItem>

<? } else if($prompt == "weekdays") {
	if($weekdays["Mon"] || $weekdays["Tue"] || $weekdays["Wed"] || $weekdays["Thu"] || $weekdays["Fri"] || $weekdays["Sat"] || $weekdays["Sun"]) {
		reset($weekdays);
		echo "<MenuItem>\n<Name>Current Value (";
		$days = array();
		while(list($day, $val) = each($weekdays)) {
			if($val) $days[] = $day;
		}
		echo implode(", ", $days) . ")</Name>\n<URL>$url";

		reset($weekdays);
		while(list($day, $val) = each($weekdays)) {
			echo "&amp;weekdays[$day]=$val";
		}
		echo "</URL>\n</MenuItem>\n";
	}
?>

<MenuItem>
<Name>Monday</Name>
<URL>QueryStringParam:weekdays[Mon]=1</URL>
</MenuItem>

<MenuItem>
<Name>Tuesday</Name>
<URL>QueryStringParam:weekdays[Tue]=1</URL>
</MenuItem>

<MenuItem>
<Name>Wednesday</Name>
<URL>QueryStringParam:weekdays[Wed]=1</URL>
</MenuItem>

<MenuItem>
<Name>Thursday</Name>
<URL>QueryStringParam:weekdays[Thu]=1</URL>
</MenuItem>

<MenuItem>
<Name>Friday</Name>
<URL>QueryStringParam:weekdays[Fri]=1</URL>
</MenuItem>

<MenuItem>
<Name>Saturday</Name>
<URL>QueryStringParam:weekdays[Sat]=1</URL>
</MenuItem>

<MenuItem>
<Name>Sunday</Name>
<URL>QueryStringParam:weekdays[Sun]=1</URL>
</MenuItem>

<SoftKeyItem>
<Name>Select</Name>
<URL>SoftKey:Select</URL>
</SoftKeyItem>
<SoftKeyItem>
<Name>Submit</Name>
<URL><?echo $url?></URL>
</SoftKeyItem>

<? } else if($prompt == "cal_type") {

	if($cal_type) echo "<MenuItem>\n<Name>Current Value ($cal_type)</Name>\n<URL>$url&amp;cal_type=$cal_type</URL>\n</MenuItem>\n";
?>
<MenuItem>
<Name>Brandeis</Name>
<URL><?echo "$url&amp;cal_type=Brandeis" ?></URL>
</MenuItem>
<MenuItem>
<Name>National Holidays</Name>
<URL><?echo "$url&amp;cal_type=holidays" ?></URL>
</MenuItem>
<MenuItem>
<Name>Normal</Name>
<URL><?echo "$url&amp;cal_type=normal" ?></URL>
</MenuItem>

<? } ?>

<SoftKeyItem>
<Name>Help</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/wakehelp.php?prompt=<?echo $prompt?></URL>
</SoftKeyItem>
<SoftKeyItem>
<Name>About</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/about.php</URL>
</SoftKeyItem>
<? echo "</$seltype>\n"; ?>
