<?

$cisco = 1;
require "../../include/finnegan.inc";

$wakes = get_wakes();

?>

<CiscoIPPhoneMenu>
<Title>Alarms</Title>

<?

while($wake = mysql_fetch_assoc($wakes)) {
	$time_array = time_to_user($wake["time"];
	$time = "$time_array[0] $time_array[1]";

	echo "<MenuItem>\n";
	if($wake["date"]) {
		$date = date_to_user($wake["date"]);
		echo "<Name>$time, $date</Name>\n";
	} else {
		$days = explode(",", $wake["weekdays"]);
		for($i = 0; $i < count($days); $i++) $days[$i] = ucfirst($days[$i]);
		$daytext = implode(", ", $days);

		if($wake["cal_type"] == "normal")
			$cal = "Regular";
		else if($row["cal_type"] == "holidays")
			$cal = "National Holidays";
		else if($row["cal_type"] == "Brandeis")
			$cal = "Brandeis";

		echo "<Name>$time, $weekdays, $cal</Name>\n";
	}

	echo "<URL>QueryStringParam:id=".$wake["wake_id"]."</URL>\n";
	echo "</MenuItem>\n";
}

?>

<SoftKeyItem>
<Name>Edit</Name>
<URL>mkwake.php</URL>
</SoftKeyItem>
<SoftKeyItem>
<Name>Delete</Name>
<URL>rmwake.php</URL>
</SoftKeyItem>
</CiscoIPPhoneMenu>
