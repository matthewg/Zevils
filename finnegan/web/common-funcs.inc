<?

function db_error() {
	global $TEMPLATE;
	echo preg_replace("/__ERROR__/", "Couldn't connect: " . mysql_error(), $TEMPLATE["db_error"]);
	do_end();
}

function log_ext($extension, $event, $result, $data = "") {
	if(!$data)
		$data = "NULL";
	else
		$data = "'$data'";

	if(!mysql_query(sprintf(
	   "INSERT INTO log_ext (extension, event, result, data, time, ip) VALUES ('%s', '%s', '%s', %s, NOW(), '%s')",
	                          $extension, $event, $result, $data, getenv("REMOTE_ADDR")))) db_error();
}

function log_wake($wake_id, $extension, $event, $result, $data = "") {
	if(!$data)
		$data = "NULL";
	else
		$data = "'$data'";

	if(!mysql_query(sprintf(
	   "INSERT INTO log_wake (wake_id, extension, event, result, data, start_time, end_time, ip) VALUES ('%s', '%s', '%s', '%s', %s, NOW(), NOW(), '%s')",
	                          $wake_id, $extension, $event, $result, $data, getenv("REMOTE_ADDR")))) db_error();
}

function extension_ok($extension) {
	global $TEMPLATE;
	if(!preg_match('/^[69][0-9]{4}$/', $extension)) {
		echo $TEMPLATE["extension_invalid"];
		return 0;
	} else if(in_array($extension, array(
		'62000', '62222', '63000', '63333', '65000'
	))) {
		echo $TEMPLATE["extension_forbidden"];
		return 0;
	} else {
		return 1;
	}
}

function pin_ok($extension, $pin, $newpin = 0) {
	global $TEMPLATE;
	if(!extension_ok($extension)) return 0;
	$ok = 0;
	$error = "";

	if(!preg_match('/^[0-9]{0,4}$/', $pin)) {
		if(!$newpin) {
			echo $TEMPLATE["pin_invalid"];
			$error = "pin_invalid";
		} else {
			echo $TEMPLATE["pin_set_new_invalid"];
			return 0;
		}
	} else {
		if($newpin) return 1;
		$result = mysql_query(sprintf("SELECT pin FROM prefs WHERE extension='%s'", $extension));
		if(!$result) db_error();

		$row = mysql_fetch_array($result, MYSQL_NUM);
		if(!$row || !$row[0]) {			
			if($pin) {
				echo $TEMPLATE["pin_empty"];
				$error = "pin_empty";
			} else {
				$ok = 1;
			}
		} else {
			$goodpin = $row[0];

			if($pin) {
				$result = mysql_query(sprintf("SELECT COUNT(*), extension, ip FROM log_ext WHERE (extension='%s' OR ip='%s') AND event='getwakes' AND result='failure' AND data='pin_error' AND UNIX_TIMESTAMP() - UNIX_TIMESTAMP(time) <= 3600 GROUP BY extension, ip HAVING COUNT(extension) >= 2", 
						$extension, getenv("REMOTE_ADDR")));
				if(!$result) db_error();

				$count = 0;
				$lockout = 0;
				while($row = mysql_fetch_array($result, MYSQL_NUM)) {
					if($row[0] >= 3) {
						$count++;
						if($row[1] == $extension && $row[2] == getenv("REMOTE_ADDR")) {
							$lockout = 2;
							break;
						}
					} else if($row[0] == 2) {
						$lockout = 1;
					}
				}

				if($count > 1) $lockout = 2;

				if($lockout == 2) {
					echo $TEMPLATE["pin_bruteforce"];
					$error = "pin_bruteforce";
				} else if($pin != $goodpin) {
					if($lockout) echo $TEMPLATE["pin_bruteforce_warn"];
					echo $TEMPLATE["pin_error"];
					$error = "pin_error";
				} else {
					$ok = 1;
				}
			} else {
				$ok = 1;
			}
		}
	}

	if($ok) {
		if(!mysql_query(sprintf("INSERT INTO log_ext (extension, event, result, time, ip) VALUES ('%s', '%s', '%s', NOW(), '%s')",
			$extension, "getwakes", "success", getenv("REMOTE_ADDR")))) db_error();
	} else {
		if(!mysql_query(sprintf("INSERT INTO log_ext (extension, event, result, time, data, ip) VALUES ('%s', '%s', '%s', NOW(), '%s', '%s')",
				$extension, "getwakes", "failure", $error, getenv("REMOTE_ADDR")))) db_error();
	}

	return $ok;
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
function date_to_sql($user_date) {
	global $inv_months;
	if(!preg_match('/^(\d{1,2})\/(\d\d)$/', $user_date, $matches)) return "";
	if($matches[1] < 1 || $matches[1] > 12 || $matches[2] < 1 || $matches[2] > 31) return "";

	return sprintf("1984-%02d-%02d", $matches[1], $matches[2]);
}

function do_end() {
	global $TEMPLATE;
	global $page;
	global $extension_ok;
	if($extension_ok) {
		echo $TEMPLATE[$page."_end"];
	} else {
		echo $TEMPLATE["viewcalls_end_noext"];
	}
	echo $TEMPLATE["page_end"];
	exit;
}

function check_extension_pin() {
	global $extension_ok;
	global $extension;
	global $pin;
	global $savepin;

	$extension_ok = 0;
	$extension = "";
	$pin = "";
	$savepin = 0;

	if(isset($_COOKIE["finnegan-extension"])) $extension = $_COOKIE["finnegan-extension"];
	if(isset($_POST["extension"])) $extension = $_POST["extension"];

	if(isset($_COOKIE["finnegan-pin"])) $pin = $_COOKIE["finnegan-pin"];
	if(isset($_POST["pin"])) $pin = $_POST["pin"];

	if(isset($_COOKIE["finnegan-savepin"]) && $_COOKIE["finnegan-savepin"] == 1) $savepin = 1;
	if(isset($_POST["savepin"]) && $_POST["savepin"] == 1) $savepin = 1;

	if($extension) {
		if(pin_ok($extension, $pin)) {
			$extension_ok = 1;
			setcookie("finnegan-extension", $extension, time()+60*60*24*365);

			if($savepin) {
				setcookie("finnegan-pin", $pin, time()+60*60*24*365);
				setcookie("finnegan-savepin", "1", time()+60*60*24*365);
			} else {
				setcookie("finnegan-pin", $pin);
			}
		}
	}
}

?>
