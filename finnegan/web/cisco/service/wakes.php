<?

$cisco = 1;
require "../../include/finnegan.inc";

$wakes = get_wakes();

?>

<CiscoIPPhoneMenu>
<Title>Alarms</Title>

<?

while($wake = mysql_fetch_assoc($wakes)) {
	echo "<MenuItem>\n";
	echo "<Name>" . format_wake($wake) . "</Name>\n";

	if($PHONE_MODEL == "CP-7912G")
		echo "<URL>".$FinneganCiscoConfig->url_base."/service/wakeprops.php?id=".$wake["wake_id"]."</URL>\n";
	else
		echo "<URL>QueryStringParam:id=".$wake["wake_id"]."</URL>\n";

	echo "</MenuItem>\n";
}

if($PHONE_MODEL == "CP-7912G") {
?>

<SoftKeyItem>
<Name>Change</Name>
<URL>SoftKey:Select</URL>
<Position>1</Position>
</SoftKeyItem>

<? } else { ?>

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

<? } ?>

<SoftKeyItem>
<Name>Back</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/index.php</URL>
<Position>4</Position>
</SoftKeyItem>
</CiscoIPPhoneMenu>
