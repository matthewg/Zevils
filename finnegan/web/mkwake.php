<?

require "db-connect.inc";
require "template.inc";
require "common-funcs.inc";

if(isset($_REQUEST["id"])) {
	$id = preg_replace('/[^0-9]/', "", $_REQUEST["id"]);
	$page = "mkwake_edit";
} else {
	$id = "";
	$page = "mkwake_new";
}

ob_start();
$dbh = get_dbh();
if(!$dbh) return db_error();

check_extension_pin();

echo $TEMPLATE["page_start"];

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
	$weekdays_cur = array("mon" => "", "tue" => "", "wed" => "", "thu" => "", "fri" => "", "sat" => "", "sun" => "");
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

		if(!isset($_POST["message"]) || !preg_match('/^\d+$/', $_POST["message"]) || $_POST["message"] > 2) {
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

			$the_weekdays = array("mon", "tue", "wed", "thu", "fri", "sat", "sun", "mon_cur", "tue_cur", "wed_cur", "thu_cur", "fri_cur", "sat_cur", "sun_cur");
			for($i = 0; $i < sizeof($the_weekdays); $i++) {
				if(isset($_POST[$the_weekdays[$i]]) && $_POST[$the_weekdays[$i]]) {
					$error = 1;
					echo $TEMPLATE["type_invalid"];
					break;
				}
			}
		} else if($type == "recur") {
			if(isset($_POST["date"]) && $_POST["date"]) {
				$error = 1;
				echo $TEMPLATE["type_invalid"];
			}

			$the_weekdays = array("mon", "tue", "wed", "thu", "fri", "sat", "sun");
			$the_weekdays_cur = array("mon_cur", "tue_cur", "wed_cur", "thu_cur", "fri_cur", "sat_cur", "sun_cur");
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

			$weekdays_cur_ct = 0;
			for($i = 0; $i < sizeof($the_weekdays_cur); $i++) {
				if(isset($_POST[$the_weekdays_cur[$i]]) && $_POST[$the_weekdays_cur[$i]]) {
					$weekdays_cur[$the_weekdays_cur[$i]] = "checked";
					$weekdays_cur_ct++;
				}
			}
			if(!$weekdays_cur_ct && !$id) {
				$weekdays_cur = $weekdays;
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
			$time = time_to_sql($time, $ampm);

			if($type == "one-time") {
				$cols = array("extension", "time", "message", "date");
				$values = array("'$extension'", "'$time'", $message, "'".date_to_sql($date)."'");
			} else {
				$sql_weekdays = array();
				while(list($day, $val) = each($weekdays)) {
					if($val) $sql_weekdays[] = ucfirst($day);
				}

				$sql_weekdays_cur = array();
				while(list($day, $val) = each($weekdays_cur)) {
					if($val) $sql_weekdays_cur[] = preg_replace('/_cur/', '', ucfirst($day));
				}

				$cols = array("extension", "time", "message", "std_weekdays", "cur_weekdays", "cal_type");
				$values = array("'$extension'", "'$time'", $message, "'".implode(",", $sql_weekdays)."'", "'".implode(",", $sql_weekdays_cur)."'", "'".$_POST["cal_type"]."'");
			}

			if(!$id) {
				#printf("INSERT INTO wakes (%s) VALUES (%s)",
				#	implode(", ", $cols),
				#	implode(", ", $values));

				if(!mysql_query(sprintf("INSERT INTO wakes (%s) VALUES (%s)",
					implode(", ", $cols),
					implode(", ", $values)
				))) db_error();
			} else {
				$set = "$cols[0] = $values[0]";
				for($i = 1; $i < sizeof($cols); $i++) $set .= ", $cols[$i] = $values[$i]";

				#echo "UPDATE wakes SET $set WHERE extension='$extension' AND wake_id=$id";
				if(!mysql_query("UPDATE wakes SET $set WHERE extension='$extension' AND wake_id=$id")) db_error();
			}

			ob_clean();
			header("Status: 303 See Other");

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

			$the_weekdays = explode(",", $row["std_weekdays"]);
			$the_weekdays_cur = explode(",", $row["cur_weekdays"]);
			for($i = 0; $i < sizeof($the_weekdays); $i++) {
				if(isset($_POST[$the_weekdays[$i]]) && $_POST[$the_weekdays[$i]]) {
					$weekdays[$the_weekdays[$i]] = "checked";
				}
			}
			for($i = 0; $i < sizeof($the_weekdays_cur); $i++) {
				if(isset($_POST[$the_weekdays_cur[$i]]) && $_POST[$the_weekdays_cur[$i]]) {
					$weekdays_cur[$the_weekdays_cur[$i]] = "checked";
				}
			}

			if($row["cal_type"] == "normal")
				$caltype_normal = "selected";
			else if($row["cal_type"] == "holidays")
				$caltype_holidays = "selected";
			else
				$caltype_brandeis = "selected";
		}
	}

	echo preg_replace(array(
			"/__TIME__/",
			"/__RECUR__/", "/__ONETIME__/",
			"/__AM__/", "/__PM__/",
			"/__MESSAGE__/",
			"/__DATE__/",
			"/__MON__/", "/__TUE__/", "/__WED__/", "/__THU__/", "/__FRI__/", "/__SAT__/", "/__SUN__/",
			"/__MON_CUR__/", "/__TUE_CUR__/", "/__WED_CUR__/", "/__THU_CUR__/", "/__FRI_CUR__/", "/__SAT_CUR__/", "/__SUN_CUR__/",
			"/__CALTYPE_BRANDEIS__/", "/__CALTYPE_HOLIDAYS__/", "/__CALTYPE_NORMAL__/",
		), array(
			$time,
			$recur, $onetime,
			$am, $pm,
			$message,
			$date,
			$weekdays["mon"], $weekdays["tue"], $weekdays["wed"], $weekdays["thu"], $weekdays["fri"], $weekdays["sat"], $weekdays["sun"],
			$weekdays_cur["mon"], $weekdays_cur["tue"], $weekdays_cur["wed"], $weekdays_cur["thu"], $weekdays_cur["fri"], $weekdays_cur["sat"], $weekdays_cur["sun"],
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
