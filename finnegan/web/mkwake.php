<?

$page = "mkwake";
require "include/finnegan.inc";
require "include/mkwake-funcs.inc";
page_start();

if(!$auth_ok) redirect("login.php");

if(isset($_REQUEST["id"])) {
	$id = preg_replace('/[^0-9]/', "", $_REQUEST["id"]);
	echo preg_replace("/__ID__/", $id, $TEMPLATE["mkwake"]["edit_start"]);
} else {
	$id = 0;
	echo $TEMPLATE["mkwake"]["new_start"];
}

if(isset($_POST["op"])) {
	$op = $_POST["op"];
} else {
	$op = "";
}

$time = "";
$recur = ""; $onetime = "";
$am = ""; $pm = "";
$message = "";
$date = "";
$weekdays = array("mon" => "", "tue" => "", "wed" => "", "thu" => "", "fri" => "", "sat" => "", "sun" => "");
$caltype_brandeis = "";
$caltype_holidays = "";
$caltype_normal = "";

if(isset($_POST["submit"])) {
	$error = 0;

	if(!isset($_POST["type"]) || ($_POST["type"] != "one-time" && $_POST["type"] != "recur")) {
		$error = 1;
		echo $TEMPLATE["mkwake"]["type_invalid"];
	}
	if(isset($_POST["type"])) {
		$type = $_POST["type"];
		if($type == "recur")
			$recur = "checked";
		else
			$onetime = "checked";
	}

	preg_match('/^(\d{1,2}):(\d\d)$/', $_POST["time"], $matches);
	if(!isset($_POST["time"]) || !preg_match('/^(\d{1,2}):(\d\d)$/', $_POST["time"], $matches) || $matches[1] < 1 || $matches[1] > 12 || $matches[2] > 59) {
		$error = 1;
		echo $TEMPLATE["mkwake"]["time_invalid"];
	}
	if(isset($_POST["time"])) $time = $_POST["time"];

	if(!isset($_POST["ampm"]) || ($_POST["ampm"] != "AM" && $_POST["ampm"] != "PM")) {
		$error = 1;
		echo $TEMPLATE["mkwake"]["ampm_invalid"];
	}
	if(isset($_POST["ampm"])) {
		$ampm = $_POST["ampm"];
		if($ampm == "AM")
			$am = "checked";
		else
			$pm = "checked";
	}

	if(!isset($_POST["message"]) || !preg_match('/^-?\d+$/', $_POST["message"]) || $_POST["message"] < -1 || $_POST["message"] > 6) {
		$error = 1;
		echo $TEMPLATE["mkwake"]["message_invalid"];
	}
	if(isset($_POST["message"])) $message = $_POST["message"];

	if(!isset($_POST["max_snooze_count"]) || !preg_match('/^\d+$/', $_POST["max_snooze_count"])) {
		$error = 1;
		echo $TEMPLATE["mkwake"]["max_snooze_count_invalid"];
	} else {
		$max_snooze_count = $_POST["max_snooze_count"];
	}

	if(!isset($_POST["type"]) || ($type != "one-time" && $type != "recur")) {
		$error = 1;
		echo $TEMPLATE["mkwake"]["type_invalid"];
	} else if($type == "one-time") {
		if(!isset($_POST["date"]) || !preg_match('/^(\d+)\/(\d+)$/', $_POST["date"], $matches) || $matches[1] < 1 || $matches[1] > 12 || $matches[2] < 1 || $matches[2] > 31) {
			$error = 1;
			echo $TEMPLATE["mkwake"]["date_invalid"];
		}
		if(isset($_POST["date"])) $date = $_POST["date"];
	} else if($type == "recur") {
		$the_weekdays = array("mon", "tue", "wed", "thu", "fri", "sat", "sun");
		$weekdays_ct = 0;
		for($i = 0; $i < sizeof($the_weekdays); $i++) {
			if(isset($_POST[$the_weekdays[$i]]) && $_POST[$the_weekdays[$i]]) {
				$weekdays[$the_weekdays[$i]] = "checked";
				$weekdays_ct++;
			}
		}
		if(!$weekdays_ct && !$id) {
			$error = 1;
			echo $TEMPLATE["mkwake"]["weekdays_invalid"];
		}

		if(!isset($_POST["cal_type"]) || ($_POST["cal_type"] != "Brandeis" && $_POST["cal_type"] != "holidays" && $_POST["cal_type"] != "normal")) {
			$error = 1;
			echo $TEMPLATE["mkwake"]["cal_type_invalid"];
		}
		if(isset($_POST["cal_type"])) {
			if($_POST["cal_type"] == "normal")
				$caltype_normal = "selected";
			else if($_POST["cal_type"] == "holidays")
				$caltype_holidays = "selected";
			else
				$caltype_brandeis = "selected";
		}
	}

	if(!$error) {
		$result = @mysql_query("SELECT COUNT(*) FROM wakes WHERE extension='$extension'");
		if(!$result) db_error();
		$row = mysql_fetch_row($result);
		$wakes = $row[0];

		if($wakes >= 10) {
			$error = 1;
			echo $TEMPLATE["mkwake"]["too_many_wakes"];
			log_wake("0", $extension, $event, "failure", "too_many_wakes");
		}

		mysql_free_result($result);
	}

	if(!$error) {
		$sql_time = time_to_sql($time, $ampm);
		$baddays = array();
		if($date) {
			if(!is_time_free($id, $sql_time, "", "", date_to_sql($date, $sql_time))) {
				$error = 1;
				echo $TEMPLATE["mkwake"]["time_unavailable_onetime"];
			}
		} else {
			$weekday_names = array("", "sun", "mon", "tue", "wed", "thu", "fri", "sat");
			for($i = 1; $i < sizeof($weekday_names); $i++) {
				if($weekdays[$weekday_names[$i]]) {
					if(!is_time_free($id, $sql_time, $i, $_POST["cal_type"])) {
						$error = 1;
						$baddays[] = ucfirst($weekday_names[$i]);
					}
				}
			}

			if($error) echo preg_replace("/__DAYS__/", implode(", ", $baddays), $TEMPLATE["mkwake"]["time_unavailable_recur"]);
		}
		if($error) log_wake($id ? $id : 0, $extension, $id ? "edit" : "create", "failure", "time_unavailable: $time/$date/".implode(",",$baddays));
	}

	if(!$error) {
		$date = date_to_sql($date, $sql_time);
		$sql_weekdays = array();
		while(list($day, $val) = each($weekdays)) {
			if($val) $sql_weekdays[] = ucfirst($day);
		}

		set_wake($id, $sql_time, $message, $type, $date, $sql_weekdays, $_POST["cal_type"], $max_snooze_count);
		redirect("wakes.php");
	}
} else if($id) {
	$result = mysql_query(sprintf("SELECT * FROM wakes WHERE extension='%s' AND wake_id=%d", $extension, $id));
	if(!$result) db_error();

	$row = mysql_fetch_assoc($result);
	if(!$row) {
		echo $TEMPLATE["mkwake"]["id_invalid"];
		page_end();
	}

	$time_array = time_to_user($row["time"]);
	if(!$time_array[0]) {
		echo preg_replace("/__DATE__/", $row["time"], $TEMPLATE["global"]["date_error"]);
		page_end();
	}
	$time = $time_array[0];
	if($time_array[1] == "AM")
		$am = "checked";
	else
		$pm = "checked";

	$message = $row["message"];
	$max_snooze_count = $row["max_snooze_count"];

	if($row["date"]) {
		$onetime = "checked";

		$date = date_to_user($row["date"]);
		if(!$date) {
			echo preg_replace("/__DATE__/", $row["date"], $TEMPLATE["global"]["date_error"]);
			page_end();
		}
	} else {
		$recur = "checked";

		$the_weekdays = explode(",", $row["weekdays"]);
		for($i = 0; $i < sizeof($the_weekdays); $i++) {
			$weekdays[strtolower($the_weekdays[$i])] = "checked";
		}

		if($row["cal_type"] == "normal")
			$caltype_normal = "selected";
		else if($row["cal_type"] == "holidays")
			$caltype_holidays = "selected";
		else
			$caltype_brandeis = "selected";
	}

	mysql_free_result($result);
}

$message_links = "";
$message_options = "";
if($id && $message == 0) 
	$message_options .= preg_replace(array("/__NUM__/", "/__NAME__/", "/__SELECTED__/"), array(0, "Secret Message", "selected"), $TEMPLATE["mkwake"]["message_option"]);
for($i = 0; $i < sizeof($FinneganConfig->messages); $i++) {
	$msg = $FinneganConfig->messages[$i];
	$selected = "";
	if($msg["id"] == $message) $selected = "checked";
	$message_links .= preg_replace(
		array("/__URL__/", "/__NAME__/", "/__NUM__/", "/__SELECTED__/"),
		array("messages/".$msg["mp3"], $msg["message"], $msg["id"], $selected),
		$TEMPLATE["mkwake"]["message_link"]
	);
	$message_options .= preg_replace(
		array("/__URL__/", "/__NAME__/", "/__NUM__/", "/__SELECTED__/"),
		array("messages/".$msg["mp3"], $msg["message"], $msg["id"], $selected),
		$TEMPLATE["mkwake"]["message_option"]
	);
}
if($message == -1)
	$selected = "selected";
else
	$selected = "";
$message_options .= preg_replace(array("/__NUM__/", "/__NAME__/", "/__SELECTED__/"), array(-1, "Random Message", $selected), $TEMPLATE["mkwake"]["message_option"]);

echo preg_replace(array(
		"/__TIME__/",
		"/__RECUR__/", "/__ONETIME__/",
		"/__AM__/", "/__PM__/",
		"/__MESSAGE_LINKS__/", "/__MESSAGE_OPTIONS__/",
		"/__MAXSNOOZE__/", "/__DATE__/",
		"/__MON__/", "/__TUE__/", "/__WED__/", "/__THU__/", "/__FRI__/", "/__SAT__/", "/__SUN__/",
		"/__CALTYPE_BRANDEIS__/", "/__CALTYPE_HOLIDAYS__/", "/__CALTYPE_NORMAL__/",
	), array(
		$time,
		$recur, $onetime,
		$am, $pm,
		$message_links, $message_options,
		isset($max_snooze_count) ? $max_snooze_count : $FinneganConfig->max_snooze_count, $date,
		$weekdays["mon"], $weekdays["tue"], $weekdays["wed"], $weekdays["thu"], $weekdays["fri"], $weekdays["sat"], $weekdays["sun"],
		$caltype_brandeis, $caltype_holidays, $caltype_normal
	), $TEMPLATE["mkwake"]["form"]
);

page_end();

?>
