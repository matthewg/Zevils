<?

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

	$result = mysql_query("SELECT wake_id, time, message, date, weekdays, cal_type FROM wakes WHERE extension='$extension' ORDER BY time");
	if(!$result) db_error();
	return $result;
}

function extension_check($extension) {
	global $TEMPLATE;
	global $FinneganConfig;
	if(!preg_match("/".$FinneganConfig->extension_regex."/", $extension)) {
		return "extension_invalid";
	} else if(in_array($extension, $FinneganConfig->forbidden_extensions)) {
		return "extension_forbidden";
	} else {
		return "";
	}
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
	if(!preg_match('/^(\d?\d):(\d\d)$/', $user_time, $matches)) return "";
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
	if(!preg_match('/^(\d{1,2})\/(\d\d)$/', $user_date, $matches)) return "";
	if($matches[1] < 1 || $matches[1] > 12 || $matches[2] < 1 || $matches[2] > 31) return "";

	$year = strftime("%Y");
	$cur_time = time() - 60*60*24; //Fudge factor
	$sql_time = preg_match('/(\d+):(\d+)/', $sql_time, $time_matches);
	$user_time = mktime($time_matches[1], $time_matches[2], 0, $matches[1], $matches[2], $year);
	if($cur_time > $user_time) $year++;
	
	return sprintf("%04d-%02d-%02d", $year, $matches[1], $matches[2]);
}

?>
