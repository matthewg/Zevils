<?

$cisco = 1;
require "../../include/finnegan.inc";

$weekdays = array("Mon" => "", "Tue" => "", "Wed" => "", "Thu" => "", "Fri" => "", "Sat" => "", "Sun" => "");

if(isset($_REQUEST["id"]) && $_REQUEST["id"] && preg_match('/^[0-9]+$/', $_REQUEST["id"])) {
	$id = $_REQUEST["id"];
	$result = @mysql_query("SELECT * FROM wakes WHERE extension='$extension' AND wake_id=$id");
	if(!$result) db_error();
	if(!mysql_num_rows()) cisco_error("Invalid Alarm", "Please select a valid alarm.");
	$wake = mysql_fetch_assoc($result);

	$time_array = time_to_user($wake["time"]);
	$time = "$time_array[0] $time_array[1]";

	$date = date_to_user($wake["date"]);
	if($date)
		$type = "onetime";
	else
		$type = "recur";

	$message = $wake["message"];

	$wakedays = explode(",", $wake["weekdays"]);
	for($i = 0; $i < sizeof($wakedays); $i++) $weekdays[$wakedays[$i]] = 1;
} else {
	$id = "";
}

$prompt = isset($_REQUEST["prompt"]) ? $_REQUEST["prompt"] : "time";
$time = isset($_REQUEST["time"]) ? $_REQUEST["time"] : "";
$ampm = isset($_REQUEST["ampm"]) ? $_REQUEST["ampm"] : "";
$message = isset($_REQUEST["message"]) ? $_REQUEST["message"] : "";
$type = isset($_REQUEST["type"]) ? $_REQUEST["type"] : "";
$date = isset($_REQUEST["date"]) ? $_REQUEST["date"] : "";
$weekdays["Mon"] = isset($_REQUEST["mon"]) ? $_REQUEST["mon"] : "";
$weekdays["Tue"] = isset($_REQUEST["tue"]) ? $_REQUEST["tue"] : "";
$weekdays["Wed"] = isset($_REQUEST["wed"]) ? $_REQUEST["wed"] : "";
$weekdays["Thu"] = isset($_REQUEST["thu"]) ? $_REQUEST["thu"] : "";
$weekdays["Fri"] = isset($_REQUEST["fri"]) ? $_REQUEST["fri"] : "";
$weekdays["Sat"] = isset($_REQUEST["sat"]) ? $_REQUEST["sat"] : "";
$weekdays["Sun"] = isset($_REQUEST["sun"]) ? $_REQUEST["sun"] : "";
$cal_type = isset($_REQUEST["cal_type"]) ? $_REQUEST["cal_type"] : "";

$title = "";

if($prompt == "time" && $time) {
	if(!preg_match('/^(\d\d?)(\d\d)$/', $time, $matches)) {
		$title = "Invalid Time";
	} else {
		$hours = $matches[1];
		$minutes = $matches[2];
		if($hours < 0 || $hours > 12 || $minutes < 0 || $minutes > 59) {
			$title = "Invalid Time";
		} else {
			$prompt = "ampm";
		}
	}
} else if($prompt == "ampm" && $ampm) {
	if($ampm != "AM" && $ampm != "PM") {
		$title = "Invalid AM/PM";
	} else {
		$prompt = "message";
	}
} else if($prompt == "message" && $message) {
	if(!preg_match('/^[0-9]+$/', $message) || $message < 0 || $message > sizeof($FinneganConfig->messages) {
		$title = "Invalid Message";
	} else {
		$prompt = "type";
	}
} else if($prompt == "type" && $type) {
	if($type != "onetime" && $type != "recur") {
		$title = "Invalid Type";
	} else if($type == "onetime") {
		$prompt = "date";
	} else {
		$prompt = "weekdays";
	}
} else if($prompt == "date" && $date) {
	if(!preg_match('/^(\d\d?)(\d\d)$/', $date, $matches)) {
		$title = "Invalid Date";
	} else {
		$month = $matches[1];
		$day = $matches[2];
		if($month < 1 || $month > 12 || $day < 1 || $day > 31) {
			$title = "Invalid Date";
		} else {
			$prompt = "done";
		}
	}
} else if($prompt == "weekdays" && $weekdays) {
	$daycount = 0;
	while(list($day, $val) = each($weekdays)) {
		if($val) $daycount++;
	}
	if(!$daycount) {
		$title = "Select Weekdays";
	} else {
		$prompt = "cal_type";
	}
} else if($prompt == "cal_type" && $cal_type) {
	if($caltype != "Brandeis" && $caltype != "holidays" && $caltype != "normal") {
		$title = "Invalid Calendar Type";
	} else {
		$prompt = "done";
	}
}

if(!$title) {
	if($prompt == "time")
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


$url = "setwake.php?id=$id;prompt=$prompt";
if($prompt != "time") $url .= ";time=$time";
if($prompt != "ampm") $url .= ";ampm=$ampm";
if($prompt != "message") $url .= ";message=$message";
if($prompt != "type") $url .= ";type=$type";
if($prompt != "date") $url .= ";date=$date";
if($prompt != "weekdays") $url .= sprintf(";mon=%s;tue=%s;wed=%s;thu=%s;fri=%s;sat=%s;sun=%s", $weekdays["Mon"], $weekdays["Tue"], $weekdays["Wed"], $weekdays["Thu"], $weekdays["Fri"], $weekdays["Sat"], $weekdays["Sun"]);
if($prompt != "cal_type") $url .= "cal_type=$cal_type";

if($prompt == "time" || $prompt == "date") {
	$seltype = "CiscoIPPhoneInput";
} else {
	$seltype = "CiscoIPPhoneMenu";
}


echo "<$seltype>\n<Title>$title</Title>\n";
if($seltype == "CiscoIPPhoneInput") echo "<URL>$url</URL>\n";

if($prompt == "time") {
?>
<InputItem>
<DisplayName>Time (8:06 AM = '806')</DisplayName>
<QueryStringParam>time</QueryStringParam>
<? if($time) echo "<DefaultValue>$time</DefaultValue>\n"; ?>
<InputFlags>N</InputFlags>
</InputItem>
<? } else if($prompt == "ampm") { ?>
<MenuItem>
<Name>AM</Name>
<URL><?echo "$url;ampm=AM" ?></URL>
</MenuItem>
<? } else if($prompt == "message") {
for($i = 0; $i < sizeof($FinneganConfig->messages); $i++) {
	printf("<MenuItem>\n<Name>%s</Name>\n<URL>%s</URL>\n</MenuItem>\n",
		$FinneganConfig->messages[$i]["message"],
		"$url;message=".$FinneganConfig->messages[$i]["id"]
	);
}
echo "<SoftKeyItem>\n<Name>__</Name>\n<URL>$url;message=0</URL>\n</SoftKeyItem>\n";
} else if($prompt == "type") {

                $prompt = "type";
                $prompt = "date";
                $prompt = "weekdays";
                        $prompt = "done";
                $prompt = "cal_type";

<SoftKeyItem>
<Name>Help</Name>
<URL>wakehelp.php?prompt=<?echo $prompt?></URL>
</SoftKeyItem>
<? echo "</$seltype>\n"; ?>
