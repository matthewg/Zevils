<?

// seed with microseconds
function make_seed() {
    list($usec, $sec) = explode(' ', microtime());
    return (float) $sec + ((float) $usec * 100000);
}
srand(make_seed());

function db_start() {
	global $FinneganConfig;
	global $dbh;

	$dbh = @mysql_connect($FinneganConfig->db["host"], $FinneganConfig->db["user"], $FinneganConfig->db["password"]);
	if(!$dbh) return db_error();

	if(!@mysql_select_db($FinneganConfig->db["database"], $dbh)) return "";

	return $dbh;
}

function redirect($uri) {
	ob_end_clean();
	header("Status: 303 See Other");
        header("Location: $uri");

        echo '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">'."\n";
        echo "<head><title>303 See Other</title></head><body><h1>303 See Other</h1><p>This document has moved <a href=\"$uri\">here</a>.</p></body></html>\n";
        exit;
}

function db_error() {
	global $TEMPLATE;
	echo preg_replace("/__ERROR__/", "Couldn't connect: " . mysql_error(), $TEMPLATE["global"]["db_error"]);
	do_end();
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

function pin_check($extension, $pin, $newpin = 0) {
	global $TEMPLATE;
	global $FinneganConfig;
	global $extension_ok;

	$ok = 0;
	$error = "";

	if($pin && !preg_match("/".$FinneganConfig->pin_regex."/", $pin)) {
		return "pin_invalid";
	} else {
		if($newpin) {
			if($pin)
				return "";
			else
				return "pin_invalid";
		}

		$result = mysql_query(sprintf("SELECT pin FROM prefs WHERE extension='%s'", $extension));
		if(!$result) db_error();

		$row = mysql_fetch_array($result, MYSQL_NUM);
		if(!$row || !$row[0]) {
			$result = mysql_query(sprintf("SELECT COUNT(*) FROM log_ext WHERE ip='%s' AND event='auth' AND result='failure' AND data='gen_pin' AND UNIX_TIMESTAMP() - UNIX_TIMESTAMP(start_time) <= 3600", 
					getenv("REMOTE_ADDR")));
			if(!$result) db_error();
			$log_row = mysql_fetch_row($result);

			if($log_row[0] >= 3) {
				log_ext($extension, "auth", "failure", "too_many_newpins");
				return "too_many_newpins";
			} else {
				$pin = "";
				for($i = 0; $i < 4; $i++) $pin .= rand(0, 9);
				if(!$row) {
					if(!mysql_query("INSERT INTO prefs (extension, pin, forgot_pin) VALUES ('$extension', '$pin', 1)")) db_error();
				} else {
					if(!mysql_query("UPDATE prefs SET pin='$pin', forgot_pin=1 WHERE extension='$extension'")) db_error();
				}

				if($FinneganConfig->nocalls) echo "<p>(Since we're not making calls, I'll just tell you that the PIN is $pin.)</p>\n";
				log_ext($extension, "auth", "failure", "gen_pin");
				return "no_pin";
			}
			$extension_ok = 0;
			return 0;
		} else {
			if(!$pin) return "pin_invalid";

			$goodpin = $row[0];

			$result = mysql_query(sprintf("SELECT COUNT(*), extension, ip FROM log_ext WHERE (extension='%s' OR ip='%s') AND event='auth' AND result='failure' AND data='pin_error' AND UNIX_TIMESTAMP() - UNIX_TIMESTAMP(start_time) <= 3600 GROUP BY extension, ip HAVING COUNT(extension) >= 2", 
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
				log_ext($extension, "auth", "failure", "pin_bruteforce");
				return "pin_bruteforce";
			} else if($pin != $goodpin) {
				log_ext($extension, "auth", "failure", "pin_error");
				if($lockout) echo $TEMPLATE["global"]["pin_bruteforce_warn"];
				return "pin_error";
			} else {
				return "";
			}
		}
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

function page_start() {
	global $TEMPLATE;
	global $page;
	global $auth_ok;
	global $extension;

	ob_start();
	db_start();
	try_auth();

	$logged_in = "";
	$menu = "";
	$pages = array(array("Introduction", "index"), array("Help", "docs"));
	$time = date("g:ia");
	if($auth_ok) {
		$logged_in = preg_replace("/__EXTENSION__/", $extension, $TEMPLATE["global"]["logged_in"]);
		$pages[] = array("View Alarms", "wakes");
		$pages[] = array("New Alarm", "mkwake");
		$pages[] = array("Change PIN", "setpin");
		$pages[] = array("Log Out", "setpin");
	} else {
		$logged_in = $TEMPLATE["global"]["not_logged_in"];
		$pages[] = array("Log In", "login");
		$pages[] = array("Register", "login");
		$pages[] = array("Forgot PIN", "login");
	}
	$pages[] = array("Legal Info", "legal");
	for($i = 0; $i < count($pages); $i++) {
		list($name, $url) = $pages[$i];
		if($url == $page) {
			$menu .= preg_replace("/__TEXT__/", $name, $TEMPLATE["global"]["nav_menu_item_current"]);
		} else {
			$menu .= preg_replace(array("/__TEXT__/", "/__URL__/"), array($name, $url.".php"), $TEMPLATE["global"]["nav_menu_item"]);
		}
	}

	echo preg_replace(
		array("/__PAGE_SCRIPT__/", "/__PAGE_HEAD__/", "/__PAGE_TITLE__/", "/__LOGGED_IN__/", "/__TIME__/", "/__NAV_MENU__/"),
		array($TEMPLATE[$page]["script"], $TEMPLATE[$page]["head"], $TEMPLATE[$page]["title"], $logged_in, $time, $menu),
		$TEMPLATE["global"]["start"]
	);
	echo $TEMPLATE[$page]["start"];
}

function page_end() {
	global $TEMPLATE;
	global $page;
	global $extension_ok;
	global $dbh;

	if(isset($dbh)) mysql_close($dbh);
	echo $TEMPLATE[$page]["end"];
	echo $TEMPLATE["global"]["end"];
	exit;
}

function try_auth() {
	global $extension_ok;
	global $extension;
	global $pin;
	global $savepin;
	global $auth_ok;
	global $auth_error;

	$auth_ok = 0;
	$auth_error = "";
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
		setcookie("finnegan-extension", $extension, time()+60*60*24*365);
		$extension_error = extension_check($extension);
		if($extension_error) {
			$auth_error = $extension_error;
			return $extension_error;
		} else {
			$extension_ok = 1;
			$pin_error = pin_check($extension, $pin);
			if($pin_error) {
				$auth_error = $pin_error;
				return $pin_error;
			} else {
				$auth_ok = 1;

				if($savepin) {
					setcookie("finnegan-pin", $pin, time()+60*60*24*365);
					setcookie("finnegan-savepin", "1", time()+60*60*24*365);
				} else {
					setcookie("finnegan-pin", $pin);
				}

				return "";
			}
		}
	} else {
		$auth_error = "no_extension";
		return "no_extension";
	}
}

?>
