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
	$_SESSION["id"] = $_REQUEST["id"];
	$id = $_SESSION["id"];
	if(!isset($_REQUEST["prompt"])) { //We only need to load from DB the first time - afterwards, everything's in the query string
		$result = @mysql_query("SELECT * FROM wakes WHERE extension='$extension' AND wake_id=$id");
		if(!$result) db_error();
		if(!mysql_num_rows($result)) cisco_message("Invalid Alarm", "Please select a valid alarm.");
		$wake = mysql_fetch_assoc($result);

		$time_array = time_to_user($wake["time"]);
		preg_match("/(\d+):(\d+)/", $time_array[0], $matches);
		$oldvalues["hr"] = $matches[1];
		$oldvalues["min"] = $matches[2];
		$oldvalues["ampm"] = $time_array[1];

		if(preg_match("/(\\d+)\\/(\\d+)/", date_to_user($wake["date"]), $matches)) {
			$oldvalues["type"] = "one-time";
			$oldvalues["mon"] = $matches[1];
			$oldvalues["day"] = $matches[2];
		} else {
			$oldvalues["type"] = "recurring";
		}

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
} else if(isset($_SESSION["id"])) {
	$id = $_SESSION["id"];
} else {
	$_SESSION["id"] = "";
	$id = "";
}

// Grab variables from query string
$playmsg = isset($_REQUEST["playmsg"]) ? $_REQUEST["playmsg"] : "";
$prompt = isset($_REQUEST["p"]) ? $_REQUEST["p"] : 0;
$process = isset($_REQUEST["do"]) ? $_REQUEST["do"] : 0;

if($playmsg) redirect($FinneganCiscoConfig->tftp_prefix."finmsg-$message");

$title = "";

// Process wake-setting state...
$prompt_start = "time";
$prompt_onetime_start = "date";
$prompt_recur_start = "weekdays";

$prompts = array(
	"time" => array(
		"next" => "ampm",
		"prev" => "",
		"values" => array("hr", "min"),
		"validate" => create_function('$values', <<<END
			\$hours = \$values[0];
			\$minutes = \$values[1];

			if(\$hours < 0 || \$hours > 12 || \$minutes < 0 || \$minutes > 59) {
				return "Invalid Time: \$hours:\$minutes";
			} else {
				return "";
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
				# Fill in a sensible default date (next time this time will come around)
				# if the user doesn't already have one
				if(\$type == "one-time" && !\$_SESSION["mon"] && !\$_SESSION["day"]) {
					\$usertime = \$_SESSION["hr"]*60*60 + \$_SESSION["min"]*60;
					\$currtime = date("G")*60*60 + date("i")*60 - 60*60*2; #Two-hour fudge factor

					\$timestamp = time(); #Timestamp on which to base the day/month to generate
					if(\$currtime > \$usertime) \$timestamp += 60*60*24;

					\$_SESSION["mon"] = date("n", \$timestamp);
					\$_SESSION["day"] = date("d", \$timestamp);
				}

				return "";
			}
END
		)
	), "date" => array(
		"next" => "done",
		"prev" => "type",
		"values" => array("mon", "day"),
		"validate" => create_function('$values', <<<END
			\$month = \$values[0];
			\$day = \$values[1];

			if(\$month < 1 || \$month > 12 || \$day < 1 || \$day > 31) {
				return "Invalid Date";
			} else {
				return "";
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
		$values = array($name);
		if(isset($var["values"])) $values = $var["values"];

		for($i = 0; $i < sizeof($values); $i++) {
			$value = $values[$i];

			if(isset($_REQUEST[$value]))
				$_SESSION[$value] = $_REQUEST[$value];
			else if($id && isset($oldvalues[$value]))
				$_SESSION[$value] = $oldvalues[$value];
			else if(!isset($_SESSION[$value]))
				$_SESSION[$value] = "";
		}
	}
		
}
reset($prompts);

$weekdays_longnames = array("Mon" => "Monday", "Tue" => "Tuesday", "Wed" => "Wednesday", "Thu" => "Thursday", "Fri" => "Friday", "Sat" => "Saturday", "Sun" => "Sunday");
$weekdays_list = array("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun");

if(isset($_REQUEST["weekdays"])) {
	$_SESSION["weekdays"] = array();
	for($i = 0; $i < sizeof($weekdays_list); $i++) {
		if($_REQUEST["weekdays"] & pow(2, $i)) {
			$_SESSION["weekdays"][$weekdays_list[$i]] = 1;
		} else {
			$_SESSION["weekdays"][$weekdays_list[$i]] = 0;
		}
	}
} else if(!isset($_SESSION["weekdays"])) {
	$_SESSION["weekdays"] = array();

	if(isset($oldvalues) && isset($oldvalues["weekdays"])) {
		while(list($day, $val) = each($oldvalues["weekdays"])) {
			$_SESSION["weekdays"][$day] = $val;
		}
	}

	for($i = 0; $i < sizeof($weekdays_list); $i++) {
		$weekday = $weekdays_list[$i];
		if(!isset($_SESSION["weekdays"][$weekday])) $_SESSION["weekdays"][$weekday] = 0;
	}
}

if(!isset($prompt)) $prompt = "";
if($prompt && $process) {
	$dome = 1;
	$values = array($prompt);
	if(isset($prompts[$prompt]["values"])) $values = $prompts[$prompt]["values"];
	if(sizeof($values) == 1) {
		$vallist = $_SESSION[$values[0]];
		if(!$vallist) $dome = 0;
	} else {
		$vallist = array();
		for($i = 0; $i < sizeof($values); $i++) {
			$vallist[$i] = $_SESSION[$values[$i]];
			if(!$vallist[$i]) $dome = 0;
		}
	}

	if($dome) {
		$title = $prompts[$prompt]["validate"]($vallist);
		if(!$title) { //No error - advance prompt
			$prompt = $prompts[$prompt]["next"];
			if(!$prompt) {
				if($_SESSION["type"] == "one-time")
					$prompt = $prompt_onetime_start;
				else
					$prompt = $prompt_recur_start;
			}
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

	if(!preg_match('/^[0-9]{1,2}$/', $_SESSION["hr"]) || !preg_match('/^[0-9]{1,2}$/', $_SESSION["min"]))
		$error = "Invalid Time";
	else
		$time = sprintf("%d:%02d", $_SESSION["hr"], $_SESSION["min"]);
	if($_SESSION["ampm"] != "AM" && $_SESSION["ampm"] != "PM") $error = "Invalid Time";
	$sql_time = time_to_sql($time, $_SESSION["ampm"]);

	if(!preg_match('/^-?\d+$/', $_SESSION["message"])) $error = "Invalid Message";

	if($_SESSION["type"] == "one-time") {
		$date = $_SESSION["mon"] . "/" . $_SESSION["day"];
		if(preg_match('/^(\d\d?)\\/?(\d\d?)$/', $date, $matches))
			$sql_date = date_to_sql($date, $sql_time);
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
$url = $FinneganCiscoConfig->url_base."/service/mkwake.php?p=$prompt&amp;do=1";
if($prev) {
	$prevurl = $FinneganCiscoConfig->url_base."/service/mkwake.php?p=$prev&amp;do=0";
} else if($id) {
	//if($PHONE_MODEL == "CP-7912G")
		$prevurl = $FinneganCiscoConfig->url_base . "/service/wakeprops.php?id=$id";
	//else
	//	$prevurl = $FinneganCiscoConfig->url_base . "/service/wakes.php";
} else {
	$prevurl = $FinneganCiscoConfig->url_base . "/service/index.php";
}


// Start building the output

if($prompt == "time" || $prompt == "date") {
	$seltype = "CiscoIPPhoneInput";
} else {
	$seltype = "CiscoIPPhoneMenu";
}


echo "<$seltype>\n<Title>$title</Title>\n";
if($prompt == "time") echo "<Prompt>AM/PM will be on next screen</Prompt>"; //Stupid schema forces Prompt to be before URL
if($seltype == "CiscoIPPhoneInput") echo "<URL>$url</URL>\n";

if($prompt == "time") {

?>

<InputItem>
<DisplayName>Hours</DisplayName>
<QueryStringParam>hr</QueryStringParam>
<InputFlags>N</InputFlags>
<DefaultValue><? if($_SESSION["hr"]) echo $_SESSION["hr"]; ?></DefaultValue>
</InputItem>

<InputItem>
<DisplayName>Minutes</DisplayName>
<QueryStringParam>min</QueryStringParam>
<InputFlags>N</InputFlags>
<DefaultValue><? if($_SESSION["min"]) echo $_SESSION["min"]; ?></DefaultValue>
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
		$messagetext = substr($FinneganConfig->messages[$i]["message"], 0, 62); //There's an undocumented limit on the length of MenuItem Names.
		if(strlen($FinneganConfig->messages[$i]["message"]) > 62) $messagetext .= chr(133); //ellipsis

		printf("<MenuItem>\n<Name>%s</Name>\n<URL>%s</URL>\n</MenuItem>\n",
			$messagetext,
			"$url&amp;message=".$FinneganConfig->messages[$i]["id"]
		);
	}
	#echo "<SoftKeyItem>\n<Name>Preview</Name>\n<URL>QueryStringParam:playmsg=1</URL>\n<Position>2</Position></SoftKeyItem>\n";

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
<DisplayName>Month</DisplayName>
<QueryStringParam>mon</QueryStringParam>
<InputFlags>N</InputFlags>
<DefaultValue><? if($_SESSION["mon"]) echo $_SESSION["mon"]; ?></DefaultValue>
</InputItem>

<InputItem>
<DisplayName>Day</DisplayName>
<QueryStringParam>day</QueryStringParam>
<InputFlags>N</InputFlags>
<DefaultValue><? if($_SESSION["day"]) echo $_SESSION["day"]; ?></DefaultValue>
</InputItem>

<? } else if($prompt == "weekdays") {
	$npurl = preg_replace("/do=1/", "do=0", $url);

	$wd = 0;
	for($i = 0; $i < sizeof($weekdays_list); $i++) {
		if($_SESSION["weekdays"][$weekdays_list[$i]]) $wd |= pow(2, $i);
	}

	for($i = 0; $i < sizeof($weekdays_list); $i++) {
		$weekday_short = $weekdays_list[$i];
		$weekday_long = $weekdays_longnames[$weekday_short];

		echo "<MenuItem>\n";

		echo "<Name>";
		if($_SESSION["weekdays"][$weekday_short])
			echo "[X] ";
		else
			echo "[ ] ";
		echo $weekday_long;
		echo "</Name>\n";

		echo "<URL>";
		echo $npurl."&amp;weekdays=";

		$this_wd = $wd;
		# Reverse state of current bit
		if($_SESSION["weekdays"][$weekday_short]) {
			$this_wd &= ~pow(2, $i);
		} else {
			$this_wd |= pow(2, $i);
		}
		echo $this_wd;

		echo "</URL>\n";

		echo "</MenuItem>\n";
	}
?>

<SoftKeyItem>
<Name>Submit</Name>
<URL><? echo "$url&amp;weekdays=$wd"; ?></URL>
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
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/wakehelp.php?p=<?echo $prompt?>&amp;x=<?echo preg_replace("/&/", "!", $FinneganCiscoConfig->url_base . "/service/mkwake.php?" . $_SERVER["QUERY_STRING"])?></URL>
<Position>4</Position>
</SoftKeyItem>
<? echo "</$seltype>\n"; ?>
