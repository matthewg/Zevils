<?

$cisco = 1;
require "../../include/finnegan.inc";

$wakes = get_wakes();

?>

<CiscoIPPhoneMenu>
<Title>Alarms</Title>

<?

while($wake = mysql_fetch_assoc($wakes)) {
	$time_array = time_to_user($wake["time"]);
	$time = "$time_array[0] $time_array[1]";

	echo "<MenuItem>\n";
	if($wake["date"]) {
		$date = date_to_user($wake["date"]);
		echo "<Name>$time; $date</Name>\n";
	} else {
		$days = explode(",", $wake["weekdays"]);
		for($i = 0; $i < count($days); $i++) $days[$i] = ucfirst($days[$i]);
		$daytext = implode(", ", $days);

		if($wake["cal_type"] == "normal")
			$cal = "Regular";
		else if($wake["cal_type"] == "holidays")
			$cal = "National Holidays";
		else if($wake["cal_type"] == "Brandeis")
			$cal = "Brandeis";

		echo "<Name>$time; $daytext; $cal</Name>\n";
	}

	echo "<URL>QueryStringParam:id=".$wake["wake_id"]."</URL>\n";
	echo "</MenuItem>\n";
}

?>

<SoftKeyItem>
<Name>Edit</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/mkwake.php</URL>
</SoftKeyItem>
<SoftKeyItem>
<Name>Delete</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/rmwake.php</URL>
</SoftKeyItem>
<SoftKeyItem>
<Name>About</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/about.php</URL>
</SoftKeyItem>
</CiscoIPPhoneMenu>
