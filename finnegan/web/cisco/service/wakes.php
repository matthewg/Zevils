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

	if($wake["disabled"])
		$x = "[OFF] ";
	else
		$x = "[ON]  ";

	echo "<MenuItem>\n";
	if($wake["date"]) {
		$date = date_to_user($wake["date"]);
		echo "<Name>$x$time; $date</Name>\n";
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

		echo "<Name>$x$time; $daytext; $cal</Name>\n";
	}

	echo "<URL>QueryStringParam:id=".$wake["wake_id"]."</URL>\n";
	echo "</MenuItem>\n";
}

?>

<SoftKeyItem>
<Name>Edit</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/mkwake.php</URL>
<Position>1</Position>
</SoftKeyItem>
<SoftKeyItem>
<Name>Delete</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/rmwake.php</URL>
<Position>2</Position>
</SoftKeyItem>
<SoftKeyItem>
<Name>On/Off</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/togglewake.php</URL>
<Position>3</Position>
</SoftKeyItem>
<SoftKeyItem>
<Name>Back</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/index.php</URL>
<Position>4</Position>
</SoftKeyItem>
</CiscoIPPhoneMenu>
