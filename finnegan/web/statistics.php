<?

$page = "statistics";
require "include/finnegan.inc";
page_start();

echo $TEMPLATE["statistics"]["body"];

# We cache this page for one hour
$cache_stat = @stat("statistics.html");
if(!$cache_stat || isset($_REQUEST["nocache"]) || $cache_stat["mtime"] < (time() - 60*60)) {

	$cache = fopen("statistics.html", "w");

	# System stats
	fwrite($cache, preg_replace("/__TITLE__/", "System Statistics", $TEMPLATE["statistics"]["group_start"]));

	$stats = mysql_query("SELECT count(*) FROM prefs");
	$row = mysql_fetch_row($stats);
	$users = $row[0];
	fwrite($cache, preg_replace(array("/__NAME__/", "/__VALUE__/"), array("Registered Users", $users), $TEMPLATE["statistics"]["stat"]));

	$stats = mysql_query("SELECT count(distinct extension) FROM wakes");
	$row = mysql_fetch_row($stats);
	$users = $row[0];
	fwrite($cache, preg_replace(array("/__NAME__/", "/__VALUE__/"), array("Active Users", $users), $TEMPLATE["statistics"]["stat"]));

	fwrite($cache, preg_replace("/__TITLE__/", "System Statistics", $TEMPLATE["statistics"]["group_end"]));


	# Wake stats
	fwrite($cache, preg_replace("/__TITLE__/", "Alarm Statistics", $TEMPLATE["statistics"]["group_start"]));

	$stats = mysql_query("SELECT disabled, count(*) AS 'count' FROM wakes GROUP BY disabled ORDER BY disabled");
	$row = mysql_fetch_row($stats);
	$wake_counts[$row[0]] = $row[1];

	$row = @mysql_fetch_row($stats); # We may not have any disabled wakes
	if($row) {
		$wake_counts[$row[0]] = $row[1];
	} else {
		$wake_counts[1] = 0;
	}

	fwrite($cache, preg_replace(array("/__NAME__/", "/__VALUE__/"), array("Alarms", $wake_counts[0]+$wake_counts[1]), $TEMPLATE["statistics"]["stat"]));
	fwrite($cache, preg_replace(array("/__NAME__/", "/__VALUE__/"), array("Active Alarms", $wake_counts[0]), $TEMPLATE["statistics"]["stat"]));

	$days = array("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun");
	for($i = 0; $i < sizeof($days); $i++) {
		$day = $days[$i];
		$stats = mysql_query("SELECT HOUR(time) AS 'hour', COUNT(*) as 'count' FROM wakes WHERE FIND_IN_SET('$day', weekdays) " .
					"GROUP BY hour ORDER BY count DESC LIMIT 1");
		$row = mysql_fetch_row($stats);

		$hour = $row[0];
		if($hour == 0)
			$hour = "12 midnight";
		else if($hour == 12)
			$hour = "12 noon";
		else if($hour > 12)
			$hour = ($hour - 12) . " P.M.";
		else
			$hour = "$hour A.M.";

		fwrite($cache, preg_replace(array("/__NAME__/", "/__VALUE__/"), array("Most Popular Alarm Hour, $day", $hour), $TEMPLATE["statistics"]["stat"]));
	}


	fwrite($cache, preg_replace("/__TITLE__/", "Alarm Statistics", $TEMPLATE["statistics"]["group_end"]));



	# Message stats
	fwrite($cache, preg_replace("/__TITLE__/", "Users Per Message", $TEMPLATE["statistics"]["group_start"]));

	$stats = mysql_query("SELECT message, COUNT(*) AS 'count' FROM wakes GROUP BY message ORDER BY count DESC");
	while($row = mysql_fetch_row($stats)) {
		$id = $row[0];
		if($id == 0) continue;
		$count = $row[1];

		if($id == -1) {
			$line = '<b>Random Message</b>';
		} else {
			$message = $FinneganConfig->messages[$id-1];
			$line = sprintf('#%d: <a href="messages/%s">%s</a>, by %s', $id, $message["mp3"], $message["message"], $message["author"]);
		}
		fwrite($cache, preg_replace(array("/__NAME__/", "/__VALUE__/"), array($count, $line), $TEMPLATE["statistics"]["stat"]));
	}

	fwrite($cache, preg_replace("/__TITLE__/", "Message Statistics", $TEMPLATE["statistics"]["group_end"]));


	fclose($cache);
}


echo implode('', file("statistics.html"));


page_end();

?>
