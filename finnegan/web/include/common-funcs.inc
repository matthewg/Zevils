<?

function current_url() { return "http://" . $_SERVER["SERVER_NAME"] . $_SERVER["REQUEST_URI"]; }

function db_start() {
	global $FinneganConfig;
	global $dbh;

	$dbh = @mysql_connect($FinneganConfig->db["host"], $FinneganConfig->db["user"], $FinneganConfig->db["password"]);
	if(!$dbh) return db_error();

	if(!@mysql_select_db($FinneganConfig->db["database"], $dbh)) return "";

	return $dbh;
}

function db_error() {
	global $TEMPLATE;
	global $cisco;

	$errmsg = "Couldn't connect: " . mysql_error();
	if($cisco) {
		cisco_error("Database Error", $errmsg);
	} else {
		echo preg_replace("/__ERROR__/", "Couldn't connect: " . mysql_error(), $TEMPLATE["global"]["db_error"]);
		page_end();
	}
}

function log_ext($extension, $event, $result, $data = "") {
	if(!$data || $result == "success")
		$data = "NULL";
	else
		$data = "'$data'";

	if(!mysql_query(sprintf(
	   "INSERT INTO log_ext (extension, event, result, data, start_time, end_time, ip) VALUES ('%s', '%s', '%s', %s, NOW(), NOW(), '%s')",
	                          $extension, $event, $result, $data, getenv("REMOTE_ADDR")))) db_error();
}

function log_wake($wake_id, $extension, $event, $result, $data = "") {
	if(!$data || $result == "success")
		$data = "NULL";
	else
		$data = "'$data'";

	if(!mysql_query(sprintf(
	   "INSERT INTO log_wake (wake_id, extension, event, result, data, start_time, end_time, ip) VALUES ('%s', '%s', '%s', '%s', %s, NOW(), NOW(), '%s')",
	                          $wake_id, $extension, $event, $result, $data, getenv("REMOTE_ADDR")))) db_error();
}

function set_pin($extension, $pin) {
	if(!mysql_query(sprintf("UPDATE prefs SET pin='%s' WHERE extension='%s'", $pin, $extension))) db_error();
	log_ext($extension, "setpin", "success");
}

function get_wakes() {
	global $extension;

	$result = mysql_query("SELECT wake_id, time, message, date, weekdays, cal_type, disabled FROM wakes WHERE extension='$extension' ORDER BY time");
	if(!$result) db_error();
	return $result;
}

function set_wake($id, $time, $message, $type, $date, $days, $cal_type) {
	global $extension;

	if($type == "one-time") {
		$cols = array("weekdays", "extension", "time", "message", "date");
		$values = array("NULL", "'$extension'", "'$time'", $message, "'$date'");
	} else {
		$cols = array("date", "extension", "time", "message", "weekdays", "cal_type");
		$values = array("NULL", "'$extension'", "'$time'", $message, "'".implode(",", $days)."'", "'$cal_type'");
	}

	if(!$id) {
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

		#if(!mysql_query("UPDATE wakes SET next_trigger_time=NULL, this_trigger_time=NULL $set WHERE extension='$extension' AND wake_id=$id")) db_error();
		if(!mysql_query("UPDATE wakes SET next_trigger=NULL, trigger_date=NULL, snooze_count=0, trigger_snooze=NULL, $set WHERE extension='$extension' AND wake_id=$id")) db_error();
		$event = "edit";
	}

	log_wake($id, $extension, $event, "success");
}

function extension_check($extension) {
	global $TEMPLATE;
	global $FinneganConfig;
	if(!preg_match("/".$FinneganConfig->extension_regex."/", $extension)) {
		return "extension_invalid";
	}

	for ($i = 0; $i < sizeof($FinneganConfig->forbidden_extensions); $i++) {
		$forbid = $FinneganConfig->forbidden_extensions[$i];

		if(preg_match("/^\\//", $forbid)) { # regex
			if(preg_match($forbid, $extension)) return "extension_forbidden";
		} else if(preg_match("/([0-9]+)-([0-9]+)/", $forbid, $matches)) { # range
			if($extension >= $matches[1] && $extension <= $matches[2]) return "extension_forbidden";
		} else {
			if($extension == $forbid) return "extension_forbidden";
		}
	}

	return "";
}

function pin_syntax_check($pin) {
	global $FinneganConfig;

	if($pin && !preg_match("/".$FinneganConfig->pin_regex."/", $pin)) {
		return "pin_invalid";
	} else {
		return "";
	}
}

// 22:00:04 -> ("10:00", "PM")
function time_to_user($sql_time) {
	if(!preg_match('/^(\d\d):(\d\d):\d\d$/', $sql_time, $matches)) return "";
	$hours = $matches[1];
	$minutes = $matches[2];
	if($hours == 0) {
		return array(sprintf("%d:%02d", 12, $minutes), "AM");
	} else if($hours < 12) {
		return array(sprintf("%d:%02d", $hours, $minutes), "AM");
	} else if($hours == 12) {
		return array(sprintf("%d:%02d", $hours, $minutes), "PM");
	} else if($hours < 24) {
		$hours -= 12;
		return array(sprintf("%d:%02d", $hours, $minutes), "PM");
	} else if($hours == 24) { //24:00:00
		return array("12:00", "AM");
	} else {
		return array("", "");
	}
}

// (10:00, 'PM') -> 22:00:00
function time_to_sql($user_time, $ampm) {
	if(!preg_match('/^(\d?\d):?(\d\d)$/', $user_time, $matches)) return "";
	if($ampm != "AM" && $ampm != "PM") return "";
	$hours = $matches[1];
	$minutes = $matches[2];
	if($hours == 12 && $ampm == "AM") {
		return "00:$minutes:00";
	} else if($hours < 12 && $ampm == "AM") {
		return "$hours:$minutes:00";
	} else if($hours == 12 && $ampm == "PM") {
		return "$hours:$minutes:00";
	} else if($hours < 12 && $ampm == "PM") {
		$hours += 12;
		return "$hours:$minutes:00";
	} else { //hours > 12
		return "";
	}
}

// YYYY-01-02 -> ("3/20")
function date_to_user($sql_date) {
	global $months;
	if(!preg_match('/^\d\d\d\d-(\d\d)-(\d\d)$/', $sql_date, $matches)) return "";
	$month = 0+$matches[1];
	$day = $matches[2];
	return "$month/$day";
}

// ("Jan", 2) -> YYYY-01-02
function date_to_sql($user_date, $sql_time) {
	global $inv_months;
	if(!preg_match('/^(\d{1,2})\/(\d{1,2})$/', $user_date, $matches)) return "";
	if($matches[1] < 1 || $matches[1] > 12 || $matches[2] < 1 || $matches[2] > 31) return "";

	$year = strftime("%Y");
	$cur_time = time() - 60*60*24; //Fudge factor
	$sql_time = preg_match('/(\d+):(\d+)/', $sql_time, $time_matches);
	$user_time = mktime($time_matches[1], $time_matches[2], 0, $matches[1], $matches[2], $year);
	if($cur_time > $user_time) $year++;
	
	return sprintf("%04d-%02d-%02d", $year, $matches[1], $matches[2]);
}

?>
