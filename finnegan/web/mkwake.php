<?

require "finnegan-config.inc";
require "template.inc";
require "common-funcs.inc";

if(isset($_REQUEST["id"])) {
	$id = preg_replace('/[^0-9]/', "", $_REQUEST["id"]);
	$page = "mkwake_edit";
} else {
	$id = 0;
	$page = "mkwake_new";
}

ob_start();
$dbh = get_dbh();
if(!$dbh) return db_error();

echo preg_replace("/__PAGE_SCRIPT__/", $TEMPLATE["mkwake_script"], $TEMPLATE["page_start"]);
check_extension_pin();
if(!$pin) {
	$uri = "index.php";
	header("Location: $uri");

	echo '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">'."\n";
	echo "<head><title>303 See Other</title></head><body><h1>303 See Other</h1><p>This document has moved <a href=\"$uri\">here</a>.</p></body></html>\n";
	exit;
}

if($extension_ok) {
	echo preg_replace("/__ID__/", $id, $TEMPLATE[$page."_start"]);

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
			echo $TEMPLATE["type_invalid"];
		}
		if(isset($_POST["type"])) {
			$type = $_POST["type"];
			if($type == "recur")
				$recur = "checked";
			else
				$onetime = "checked";
		}

		if(!preg_match('/^(\d{1,2}):(\d\d)$/', $_POST["time"], $matches)) echo "time check";
		if(!isset($_POST["time"]) || !preg_match('/^(\d{1,2}):(\d\d)$/', $_POST["time"], $matches) || $matches[1] < 1 || $matches[1] > 12 || $matches[2] > 59) {
			$error = 1;
			echo $TEMPLATE["time_invalid"];
		}
		if(isset($_POST["time"])) $time = $_POST["time"];

		if(!isset($_POST["ampm"]) || ($_POST["ampm"] != "AM" && $_POST["ampm"] != "PM")) {
			$error = 1;
			echo $TEMPLATE["ampm_invalid"];
		}
		if(isset($_POST["ampm"])) $ampm = $_POST["ampm"];
		if($ampm == "AM")
			$am = "checked";
		else
			$pm = "checked";

		if(!isset($_POST["message"]) || !preg_match('/^-?\d+$/', $_POST["message"]) || $_POST["message"] < -1 || $_POST["message"] > 6) {
			$error = 1;
			echo $TEMPLATE["message_invalid"];
		}
		if(isset($_POST["message"])) $message = $_POST["message"];

		if($type == "one-time") {
			if(!isset($_POST["date"]) || !preg_match('/^(\d+)\/(\d+)$/', $_POST["date"], $matches) || $matches[1] < 1 || $matches[1] > 12 || $matches[2] < 1 || $matches[2] > 31) {
				$error = 1;
				echo $TEMPLATE["date_invalid"];
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
			if(!$weekdays_ct) {
				$error = 1;
				echo $TEMPLATE["weekdays_invalid"];
			}

			if(!isset($_POST["cal_type"]) || ($_POST["cal_type"] != "Brandeis" && $_POST["cal_type"] != "holidays" && $_POST["cal_type"] != "normal")) {
				$error = 1;
				echo $TEMPLATE["cal_type_invalid"];
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
				echo $TEMPLATE["too_many_wakes"];
				log_wake("0", $extension, $event, "failure", "too_many_wakes");
			}
		}

		if(!$error) {
			$sql_time = time_to_sql($time, $ampm);
			$baddays = array();
			if($date) {
				if(!is_time_free($id, $sql_time, "", "", date_to_sql($date, $sql_time))) {
					$error = 1;
					echo $TEMPLATE["time_unavailable_onetime"];
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

				if($error) echo preg_replace("/__DAYS__/", implode(", ", $baddays), $TEMPLATE["time_unavailable_recur"]);
			}
			if($error) log_wake($id ? $id : 0, $extension, $id ? "edit" : "create", "failure", "time_unavailable: $time/$date/".implode(",",$baddays));
		}

		if(!$error) {

			if($type == "one-time") {
				$cols = array("weekdays", "extension", "time", "message", "date");
				$values = array("NULL", "'$extension'", "'$sql_time'", $message, "'".date_to_sql($date, $sql_time)."'");
			} else {
				$sql_weekdays = array();
				while(list($day, $val) = each($weekdays)) {
					if($val) $sql_weekdays[] = ucfirst($day);
				}

				$cols = array("date", "extension", "time", "message", "weekdays", "cal_type");
				$values = array("NULL", "'$extension'", "'$sql_time'", $message, "'".implode(",", $sql_weekdays)."'", "'".$_POST["cal_type"]."'");
			}

			if(!$id) {
				printf("INSERT INTO wakes (%s) VALUES (%s)",
					implode(", ", $cols),
					implode(", ", $values));

				if(!mysql_query(sprintf("INSERT INTO wakes (%s) VALUES (%s)",
					implode(", ", $cols),
					implode(", ", $values)
				))) db_error();

				if(!mysql_query("SELECT LAST_INSERT_ID()")) db_error();
				$row = mysql_fetch_row($result);
				$id = $row[0];
				$event = "create";
			} else {
				$set = "$cols[0] = $values[0]";
				for($i = 1; $i < sizeof($cols); $i++) $set .= ", $cols[$i] = $values[$i]";

				if(!mysql_query("UPDATE wakes SET next_trigger=NULL, trigger_date=NULL, snooze_count=0, trigger_snooze=NULL, $set WHERE extension='$extension' AND wake_id=$id")) db_error();
				$event = "edit";
			}

			log_wake($id, $extension, $event, "success");

			#ob_clean();
			#header("Status: 303 See Other");

			#$uri = "http";
			#$port = getenv("SERVER_PORT");
			#if($port == 443) $uri .= "s";
			#$uri .= ":/";
			#$uri .= preg_replace("/mkwake.php/", "index.php", getenv("SCRIPT_NAME"));
			$uri = "index.php";
			header("Location: $uri");

			echo '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">'."\n";
			echo "<head><title>303 See Other</title></head><body><h1>303 See Other</h1><p>This document has moved <a href=\"$uri\">here</a>.</p></body></html>\n";
			exit;
		}
	} else if($id) {
		$result = mysql_query(sprintf("SELECT * FROM wakes WHERE extension='%s' AND wake_id=%d", $extension, $id));
		if(!$result) db_error();

		$row = mysql_fetch_assoc($result);
		if(!$row) {
			echo $TEMPLATE["id_invalid"];
			do_end();
		}

		$time_array = time_to_user($row["time"]);
		if(!$time_array[0]) {
			echo preg_replace("/__DATE__/", $row["time"], $TEMPLATE["date_error"]);
			do_end();
		}
		$time = $time_array[0];
		if($time_array[1] == "AM")
			$am = "checked";
		else
			$pm = "checked";

		$message = $row["message"];

		if($row["date"]) {
			$onetime = "checked";

			$date = date_to_user($row["date"]);
			if(!$date) {
				echo preg_replace("/__DATE__/", $row["date"], $TEMPLATE["date_error"]);
				do_end();
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
	}

	$message_links = "";
	$message_options = "";
	if($id && $message == 0) 
		$message_options .= preg_replace(array("/__NUM__/", "/__NAME__/", "/__SELECTED__/"), array(0, "Secret Message", "selected"), $TEMPLATE["mkwake_message_option"]);
	for($i = 0; $i < sizeof($FinneganConfig->messages); $i++) {
		$msg = $FinneganConfig->messages[$i];
		$selected = "";
		if($msg["id"] == $message) $selected = "selected";
		$message_links .= preg_replace(array("/__URL__/", "/__NAME__/"), array("messages/".$msg["mp3"], $msg["message"]), $TEMPLATE["mkwake_message_link"]);
		$message_options .= preg_replace(array("/__NUM__/", "/__NAME__/", "/__SELECTED__/"), array($msg["id"], $msg["message"], $selected), $TEMPLATE["mkwake_message_option"]);
	}
	if($message == -1)
		$selected = "selected";
	else
		$selected = "";
	$message_options .= preg_replace(array("/__NUM__/", "/__NAME__/", "/__SELECTED__/"), array(-1, "Random Message", $selected), $TEMPLATE["mkwake_message_option"]);

	echo preg_replace(array(
			"/__TIME__/",
			"/__RECUR__/", "/__ONETIME__/",
			"/__AM__/", "/__PM__/",
			"/__MESSAGE_LINKS__/", "/__MESSAGE_OPTIONS__/",
			"/__DATE__/",
			"/__MON__/", "/__TUE__/", "/__WED__/", "/__THU__/", "/__FRI__/", "/__SAT__/", "/__SUN__/",
			"/__CALTYPE_BRANDEIS__/", "/__CALTYPE_HOLIDAYS__/", "/__CALTYPE_NORMAL__/",
		), array(
			$time,
			$recur, $onetime,
			$am, $pm,
			$message_links, $message_options,
			$date,
			$weekdays["mon"], $weekdays["tue"], $weekdays["wed"], $weekdays["thu"], $weekdays["fri"], $weekdays["sat"], $weekdays["sun"],
			$caltype_brandeis, $caltype_holidays, $caltype_normal
		), $TEMPLATE["mkwake_form"]
	);

	mysql_close($dbh);	
} else {
	echo $TEMPLATE["viewcalls_start_noext"];
	echo preg_replace("/__EXTENSION__/", $extension, $TEMPLATE["get_extension"]);
	$page = "viewcalls";
}

do_end();

?>
