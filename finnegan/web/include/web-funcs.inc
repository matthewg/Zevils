<?

$cisco = 0;

// seed with microseconds
function make_seed() {
    list($usec, $sec) = explode(' ', microtime());
    return (float) $sec + ((float) $usec * 100000);
}
srand(make_seed());

function redirect($uri) {
	ob_end_clean();
	header("Status: 303 See Other");
        header("Location: $uri");

        echo '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">'."\n";
        echo "<head><title>303 See Other</title></head><body><h1>303 See Other</h1><p>This document has moved <a href=\"$uri\">here</a>.</p></body></html>\n";
        exit;
}

function pin_check($extension, $pin, $newpin = 0) {
	global $TEMPLATE;
	global $FinneganConfig;
	global $extension_ok;

	$ok = 0;
	$error = "";

	if(pin_syntax_check($pin)) {
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
				if(!$FinneganConfig->use_cisco || !$FinneganCiscoConfig->use_xml_service) {
					for($i = 0; $i < 4; $i++) $pin .= rand(0, 9);
					if(!$row) {
						if(!mysql_query("INSERT INTO prefs (extension, pin, forgot_pin) VALUES ('$extension', '$pin', 1)")) db_error();
					} else {
						if(!mysql_query("UPDATE prefs SET pin='$pin', forgot_pin=1 WHERE extension='$extension'")) db_error();
					}

					if($FinneganConfig->nocalls) echo "<p>(Since we're not making calls, I'll just tell you that the PIN is $pin.)</p>\n";
				}
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
