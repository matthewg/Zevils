<?

$cisco = 1;
require "../../include/finnegan.inc";
require "../../include/mkwake-funcs.inc";

ini_set("session.use_cookies", 0);
session_id($extension);
session_start();


// Initialize variables for editing an existing wake
$oldvalues = array();
if(isset($_REQUEST["id"]) && $_REQUEST["id"] && preg_match('/^[0-9]+$/', $_REQUEST["id"])) {
	$id = $_REQUEST["id"];
	if(!isset($_REQUEST["prompt"])) { //We only need to load from DB the first time - afterwards, everything's in the query string
		$result = @mysql_query("SELECT * FROM wakes WHERE extension='$extension' AND wake_id=$id");
		if(!$result) db_error();
		if(!mysql_num_rows($result)) cisco_error("Invalid Alarm", "Please select a valid alarm.");
		$wake = mysql_fetch_assoc($result);

		$time_array = time_to_user($wake["time"]);
		$oldvalues["time"] = preg_replace("/:/", "", $time_array[0]);
		$oldvalues["ampm"] = $time_array[1];

		$oldvalues["date"] = preg_replace("/\\//", "", date_to_user($wake["date"]));
		if($oldvalues["date"])
			$oldvalues["type"] = "one-time";
		else
			$oldvalues["type"] = "recurring";

		$oldvalues["message"] = $wake["message"];

		$oldvalues["weekdays"] = array();
		if($wake["weekdays"]) {
			$wakedays = explode(",", $wake["weekdays"]);
			for($i = 0; $i < sizeof($wakedays); $i++) {
				$oldvalues["weekdays"][$wakedays[$i]] = 1;
			}
		}

		$oldvalues["cal_type"] = $wake["cal_type"];
	}
} else {
	$id = "";
}

// Grab variables from query string
$playmsg = isset($_REQUEST["playmsg"]) ? $_REQUEST["playmsg"] : "";
$prompt = isset($_REQUEST["prompt"]) ? $_REQUEST["prompt"] : 0;
$process = isset($_REQUEST["process"]) ? $_REQUEST["process"] : 0;

if($playmsg) redirect("Play:".$FinneganCiscoConfig->tftp_prefix."finmsg-$message");

$title = "";

// Process wake-setting state...
$prompt_start = "time";
$prompt_onetime_start = "date";
$prompt_recur_start = "weekdays";

$prompts = array(
	"time" => array(
		"next" => "ampm",
		"prev" => "",
		"validate" => create_function('$time', <<<END
			if(!preg_match('/^(\d\d?)(\d\d)$/', \$time, \$matches)) {
				return "Invalid Time";
			} else {
				\$hours = \$matches[1];
				\$minutes = \$matches[2];
				if(\$hours < 0 || \$hours > 12 || \$minutes < 0 || \$minutes > 59) {
					return "Invalid Time";
				} else {
					return "";
				}
			}
END
		)
	), "ampm" => array(
		"next" => "message",
		"prev" => "time",
		"validate" => create_function('$ampm', <<<END
			if(\$ampm != "AM" && \$ampm != "PM") {
				return "Invalid AM/PM";
			} else {
				return "";
			}
END
		)
	), "message" => array(
		"next" => "type",
		"prev" => "ampm",
		"validate" => create_function('$message', <<<END
			global \$FinneganConfig;
			if(!preg_match('/^-?[0-9]+$/', \$message) || \$message < -1 || \$message > sizeof(\$FinneganConfig->messages)) {
				return "Invalid Message";
			} else {
				return "";
			}
END
		)
	), "type" => array(
		"next" => "",
		"prev" => "message",
		"validate" => create_function('$type', <<<END
			if(\$type != "one-time" && \$type != "recurring") {
				return "Invalid Type";
			} else {
				return "";
			}
END
		)
	), "date" => array(
		"next" => "done",
		"prev" => "type",
		"validate" => create_function('$date', <<<END
			if(!preg_match('/^(\d\d?)(\d\d)$/', \$date, \$matches)) {
				return "Invalid Date";
			} else {
				\$month = \$matches[1];
				\$day = \$matches[2];
				if(\$month < 1 || \$month > 12 || \$day < 1 || \$day > 31) {
					return "Invalid Date";
				} else {
					return "";
				}
			}
END
		)
	), "weekdays" => array(
		"next" => "cal_type",
		"prev" => "type",
		"validate" => create_function('$weekdays', <<<END
			\$daycount = 0;
			while(list(\$day, \$val) = each(\$weekdays)) {
				if(\$val) \$daycount++;
			}
			if(!\$daycount) {
				return "Select Weekdays";
			} else {
				return "";
			}
END
		)
	), "cal_type" => array(
		"next" => "done",
		"prev" => "weekdays",
		"validate" => create_function('$cal_type', <<<END
			if(\$cal_type != "Brandeis" && \$cal_type != "holidays" && \$cal_type != "normal") {
				return "Invalid Calendar Type";
			} else {
				return "";
			}
END
		)
	)
);

while(list($name, $var) = each($prompts)) {
	if($name != "weekdays") {
		if(isset($_REQUEST[$name]))
			$_SESSION[$name] = $_REQUEST[$name];
		else if($id && isset($oldvalues[$name]))
			$_SESSION[$name] = $oldvalues[$name];
		else
			$_SESSION[$name] = "";
	}
		
}
reset($prompts);

$the_weekdays = array("Mon" => "Monday", "Tue" => "Tuesday", "Wed" => "Wednesday", "Thu" => "Thursday", "Fri" => "Friday", "Sat" => "Saturday", "Sun" => "Sunday");
$_SESSION["weekdays"] = array();
while(list($weekday, $val) = each($the_weekdays)) {
	if(isset($_REQUEST["weekdays"]) && isset($_REQUEST["weekdays"][$weekday]))
		$_SESSION["weekdays"][$weekday] = $_REQUEST["weekdays"][$weekday];
	else if($id && isset($oldvalues["weekdays"][$weekday]))
		$_SESSION["weekdays"][$weekday] = $oldvalues["weekdays"][$weekday];
	else
		$_SESSION["weekdays"][$weekday] = "";

	if(!isset($_SESSION["weekdays"][$weekday])) $_SESSION["weekdays"][$weekday] = "";
}
reset($the_weekdays);

if(!isset($prompt)) $prompt = "";
if($prompt && $process && $_SESSION[$prompt]) {
	$title = $prompts[$prompt]["validate"]($_SESSION[$prompt]);
	if(!$title) { //No error - advance prompt
		$prompt = $prompts[$prompt]["next"];
		if(!$prompt) {
			if($_SESSION["type"] == "one-time")
				$prompt = $prompt_onetime_start;
			else
				$prompt = $prompt_recur_start;
		}
	}
} else if(!$prompt) {
	$prompt = $prompt_start;
}
if($prompt != "done")
	$prev = $prompts[$prompt]["prev"];
else
	$prev = "";


// Database INSERT/UPDATE time?
if($prompt == "done") {
	$error = "";
	$weekday_map = array("Sun" => 1, "Mon" => 2, "Tue" => 3, "Wed" => 4, "Thu" => 5, "Fri" => 6, "Sat" => 7);

	if(preg_match('/^(\d\d?):?(\d\d)$/', $_SESSION["time"], $matches))
		$time = "$matches[1]:$matches[2]";
	else
		$error = "Invalid Time";
	if($_SESSION["ampm"] != "AM" && $_SESSION["ampm"] != "PM") $error = "Invalid Time";
	$sql_time = time_to_sql($_SESSION["time"], $_SESSION["ampm"]);

	if(!preg_match('/^-?\d+$/', $_SESSION["message"])) $error = "Invalid Message";

	if($_SESSION["type"] == "one-time") {
		if(preg_match('/^(\d\d?)\\/?(\d\d)$/', $_SESSION["date"], $matches))
			$sql_date = date_to_sql("$matches[1]/$matches[2]", $sql_time);
		else
			$error = "Invalid Date";
		$sql_cal_type = "";
		$sql_weekdays = array();
	} else {
		$sql_date = "";
		if($_SESSION["cal_type"] != "Brandeis" && $_SESSION["cal_type"] != "holidays" && $_SESSION["cal_type"] != "normal") $error = "Invalid Calendar Type";
		$sql_cal_type = $_SESSION["cal_type"];

		reset($weekdays);
		$sql_weekdays = array();
		while(list($day, $val) = each($_SESSION["weekdays"])) {
			if($val) $sql_weekdays[] = $day;
		}
	}


	if($error) {
		$title = $error;
		$prompt = "time";
	} else {
		if($_SESSION["type"] == "one-time") {
			if(!is_time_free($id, $sql_time, "", "", $sql_date)) $error = "Time Unavailable";
		} else {
			reset($_SESSION["weekdays"]);
			$baddays = array();
			while(list($name, $val) = each($_SESSION["weekdays"])) {
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
			set_wake($id, $sql_time, $_SESSION["message"], $_SESSION["type"], $sql_date, $sql_weekdays, $sql_cal_type);
			$_SESSION = array();
			session_destroy();
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

// Build URLs
$url = $FinneganCiscoConfig->url_base."/service/mkwake.php?id=$id&amp;prompt=$prompt&amp;process=1&amp;".ini_get("session.name")."=" . session_id();
if($prev)
	$prevurl = $FinneganCiscoConfig->url_base."/service/mkwake.php?id=$id&amp;prompt=$prev&amp;process=0&amp;".ini_get("session.name")."=" . session_id();
else
	$prevurl = $FinneganCiscoConfig->url_base . "/service/index.php";

/*
while(list($name, $var) = each($prompts)) {
	if($name != "weekdays") {
		if($prompt != $name) $url .= "&amp;$name=".$_SESSION[$name];
		if($prev) $prevurl .= "&amp;$name=".$_SESSION[$name];
	} else {
		reset($_SESSION["weekdays"]);
		$urlx = "";
		while(list($day, $val) = each($_SESSION["weekdays"])) {
			$urlx .= "&amp;weekdays[$day]=$val";
		}
		if($prompt != $name) $url .= $urlx;
		if($prev) $prevurl .= $urlx;
	}
}
*/



// Start building the output

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
<? if($_SESSION["time"]) echo "<DefaultValue>".$_SESSION["time"]."</DefaultValue>\n"; ?>
<InputFlags>N</InputFlags>
</InputItem>

<? } else if($prompt == "ampm") {

	if($_SESSION["ampm"]) echo "<MenuItem>\n<Name>Current Value (".$_SESSION["ampm"].")</Name>\n<URL>$url&amp;ampm=".$_SESSION["ampm"]."</URL>\n</MenuItem>\n";
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

	if($_SESSION["message"]) echo "<MenuItem>\n<Name>Current Value (".($_SESSION["message"] == -1 ? 2 : $_SESSION["message"]+2).")</Name>\n<URL>$url&amp;message=".$_SESSION["message"]."</URL>\n</MenuItem>\n";
	echo "<MenuItem>\n<Name>Random Message</Name>\n<URL>$url&amp;message=-1</URL>\n</MenuItem>\n";
	for($i = 0; $i < sizeof($FinneganConfig->messages); $i++) {
		printf("<MenuItem>\n<Name>%s</Name>\n<URL>%s</URL>\n</MenuItem>\n",
			$FinneganConfig->messages[$i]["message"],
			"$url&amp;message=".$FinneganConfig->messages[$i]["id"]
		);
	}
	echo "<SoftKeyItem>\n<Name>Preview</Name>\n<URL>QueryStringParam:playmsg=1</URL>\n<Position>2</Position></SoftKeyItem>\n";

} else if($prompt == "type") {

	if($_SESSION["type"]) echo "<MenuItem>\n<Name>Current Value (".$_SESSION["type"].")</Name>\n<URL>$url&amp;type=".$_SESSION["type"]."</URL>\n</MenuItem>\n";
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
<? if($_SESSION["date"]) echo "<DefaultValue>".$_SESSION["date"]."</DefaultValue>\n"; ?>
<InputFlags>N</InputFlags>
</InputItem>

<? } else if($prompt == "weekdays") {
	$npurl = preg_replace("/process=1/", "process=0", $url);

	while(list($weekday, $val) = each($the_weekdays)) {
		echo "<MenuItem>\n";

		echo "<Name>";
		if($_SESSION["weekdays"][$weekday])
			echo "[X] ";
		else
			echo "[ ] ";
		echo $val;
		echo "</Name>\n";

		echo "<URL>";
		echo $npurl."&amp;weekdays[$weekday]=";
		if($_SESSION["weekdays"][$weekday])
			echo "0";
		else
			echo "1";
		reset($_SESSION["weekdays"]);
		while(list($day, $val) = each($_SESSION["weekdays"])) {
			if($day != $weekday) echo "&amp;weekdays[$day]=$val";
		}
		echo "</URL>\n";

		echo "</MenuItem>\n";
	}
?>

<SoftKeyItem>
<Name>Submit</Name>
<URL><?
	echo $url;
	reset($_SESSION["weekdays"]);
	while(list($day, $val) = each($_SESSION["weekdays"])) {
		echo "&amp;weekdays[$day]=$val";
	}	
?></URL>
<Position>2</Position>
</SoftKeyItem>

<? } else if($prompt == "cal_type") {

	if($_SESSION["cal_type"]) echo "<MenuItem>\n<Name>Current Value (".$_SESSION["cal_type"].")</Name>\n<URL>$url&amp;cal_type=".$_SESSION["cal_type"]."</URL>\n</MenuItem>\n";
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

<? }

if($seltype == "CiscoIPPhoneMenu") {
	echo "<SoftKeyItem>\n<Name>Select</Name>\n<URL>SoftKey:Select</URL>\n<Position>1</Position></SoftKeyItem>\n";
} else {
	echo "<SoftKeyItem>\n<Name>Submit</Name>\n<URL>SoftKey:Submit</URL>\n<Position>1</Position></SoftKeyItem>\n";
	echo "<SoftKeyItem>\n<Name>&lt;&lt;</Name>\n<URL>SoftKey:&lt;&lt;</URL>\n<Position>2</Position></SoftKeyItem>\n";
} ?>
<SoftKeyItem>
<Name>Back</Name>
<URL><?echo $prevurl?></URL>
<Position>3</Position>
</SoftKeyItem>
<SoftKeyItem>
<Name>Help</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/wakehelp.php?prompt=<?echo $prompt?>&amp;prevurl=<?echo preg_replace("/&/", "!", current_url())?></URL>
<Position>4</Position>
</SoftKeyItem>
<? echo "</$seltype>\n"; ?>
