<?

require "finnegan-config.inc";
require "template.inc";
require "common-funcs.inc";

$page = "viewcalls";

ob_start();
$dbh = get_dbh();
if(!$dbh) db_error();

echo $TEMPLATE["page_start"];

if(isset($_POST["op"]) && $_POST["op"] == "Forgot PIN" && isset($_POST["extension"]) && extension_ok($_POST["extension"])) {
	echo $TEMPLATE["viewcalls_start_noext"];

	if(!mysql_query("UPDATE prefs SET forgot_pin=1 WHERE extension='$extension'")) db_error();
	if(mysql_affected_rows() != 1)
		echo $TEMPLATE["pin_not_found"];
	else
		echo $TEMPLATE["pin_sent"];
}

$force_auth_ok = 0;
if($FinneganConfig->testmode) {
	if((isset($_POST["force_auth_ok"]) && $_POST["force_auth_ok"]) || (isset($_COOKIE["finnegan-force-auth-ok"]) && $_COOKIE["finnegan-force-auth-ok"])) {
		$force_auth_ok = 1;
		setcookie("finnegan-force-auth-ok", 1);
	}
}

check_extension_pin();
if($FinneganConfig->testmode && $force_auth_ok) $extension_ok = 1;

if(isset($_POST["op"]) && $_POST["op"] == "Log Out") {
	unset($_COOKIE["finnegan-extension"]);
	unset($_COOKIE["finnegan-pin"]);
	unset($_POST["extension"]);
	unset($_POST["pin"]);
	setcookie("finnegan-extension", "", time()-3600);
	setcookie("finnegan-pin", "", time()-3600);
	setcookie("finnegan-savepin", "", time()-3600);
	setcookie("finnegan-force-auth-ok", "", time()-3600);

	log_ext($extension, "delcookie", "success");
	$extension = "";
	$extension_ok = 0;
}

if($extension_ok) {
	log_ext($extension, "getwakes", "success");
	echo $TEMPLATE["viewcalls_start"];

	if(isset($_POST["op"])) {
		$op = $_POST["op"];
		if(isset($_POST["pin1"]) && $op == "Set PIN") {
			$oldpin = isset($_POST["oldpin"]) ? $_POST["oldpin"] : "";
			$pin1 = isset($_POST["pin1"]) ? $_POST["pin1"] : "";
			$pin2 = isset($_POST["pin2"]) ? $_POST["pin2"] : "";
			$error = "";
			if($oldpin != $pin) {
				echo $TEMPLATE["pin_set_old_error"];
				$error = "pin_set_old_error";
			} else if($pin1 != $pin2) {
				echo $TEMPLATE["pin_set_new_mismatch"];
				$error = "pin_set_new_mismatch";
			} else if(!pin_ok($extension, $pin1, 1)) {
				$error = "pin_set_new_invalid";
			} else {
				$result = mysql_query(sprintf("SELECT COUNT(*) FROM prefs WHERE extension='%s'",
						$extension));
				if(!$result) db_error();

				$row = mysql_fetch_array($result, MYSQL_NUM);
				$has_pref = $row[0];

				if($has_pref) {
					if(!mysql_query(sprintf("UPDATE prefs SET pin='%s' WHERE extension='%s'",
						$pin1, $extension))) db_error();
				} else {
					if(!mysql_query(sprintf("INSERT INTO prefs (extension, pin) VALUES ('%s', '%s')",
						$extension, $pin1))) db_error();
				}

				if($savepin) {
					setcookie("finnegan-pin", $pin1, time()+60*60*24*365);
				} else {
					setcookie("finnegan-pin", $pin1);
				}

				echo $TEMPLATE["pin_set_ok"];
			}

			log_ext($extension, "setpin", $error ? "failure" : "success", $error);
			if($error && !$pin) {
				$extension_ok = 0;
				echo $TEMPLATE["no_pin"];
				do_end();
			}
		} else if($op == "Confirm Deletion" && isset($_POST["id"])) {
			while(list($id, $value) = each($_POST["id"])) {
				if(!preg_match('/^[0-9]+$/', $id)) unset($_POST["id"]);
			}
			$keys = implode(", ", array_keys($_POST["id"]));

			if(!mysql_query(sprintf("DELETE FROM wakes WHERE extension='%s' AND wake_id IN (%s)", $extension, $keys))) db_error();

			while(list($id, $value) = each($_POST["id"])) {
				log_wake($id, $extension, "delete", "success");
			}
		}
	}


	$result = mysql_query("SELECT wake_id, time, message, date, weekdays, cal_type FROM wakes WHERE extension='$extension' ORDER BY time");
	if(!$result) db_error();

	$count = mysql_num_rows($result);
	echo preg_replace("/__COUNT__/", $count, $TEMPLATE["wake_list_start"]);
	while($count && ($row = mysql_fetch_assoc($result))) {
		$delete = "";
		$delete_class = "";
		if(isset($_POST["op"]) && $_POST["op"] == "Delete marked wake-up calls" && isset($_POST["id"][$row["wake_id"]])) {
			$delete = "checked";
			$delete_class = 'class="wake-deleted"';
		}

		$time_array = time_to_user($row["time"]);
		if(!$time_array[0]) {
			echo preg_replace("/__DATE__/", $row["time"], $TEMPLATE["date_error"]);
			do_end();
		}
		$time = "$time_array[0] $time_array[1]";

		if($row["date"]) {
			$date = date_to_user($row["date"]);
			if(!$date) {
				echo preg_replace("/__DATE__/", $row["date"], $TEMPLATE["date_error"]);
				do_end();
			}

			echo preg_replace(
				array("/__DELETE_CLASS__/",
				      "/__ID__/",
				      "/__DELETE__/",
				      "/__TIME__/",
				      "/__MESSAGE__/",
				      "/__DATE__/"),
				array($delete_class,
				      $row["wake_id"],
				      $delete,
				      $time,
				      $row["message"],
				      $date),
				$TEMPLATE["wake_list_item_once"]
			);
		} else {
			$days = explode(",", $row["weekdays"]);
			for($i = 0; $i < count($days); $i++) $days[$i] = ucfirst($days[$i]);
			$daytext = implode(", ", $days);

			if($row["cal_type"] == "normal")
				$cal = "Regular";
			else if($row["cal_type"] == "holidays")
				$cal = "National Holidays";
			else if($row["cal_type"] == "Brandeis")
				$cal = "Brandeis";

			echo preg_replace(
				array("/__DELETE_CLASS__/",
				      "/__ID__/",
				      "/__DELETE__/",
				      "/__TIME__/",
				      "/__MESSAGE__/",
				      "/__DAYS__/",
				      "/__CAL__/"),
				array($delete_class,
				      $row["wake_id"],
				      $delete,
				      $time,
				      $row["message"],
				      $daytext,
				      $cal),
				$TEMPLATE["wake_list_item_recur"]
			);
		}
		if($delete) echo "</span>";
	}
	echo $TEMPLATE["wake_list_end"];
	if(isset($_POST["op"]) && $_POST["op"] == "Delete marked wake-up calls") echo $TEMPLATE["delete_confirm"];

	mysql_close($dbh);	
} else {
	echo $TEMPLATE["viewcalls_start_noext"];
	echo preg_replace("/__EXTENSION__/", $extension, $TEMPLATE["get_extension"]);
}

do_end();

?>
