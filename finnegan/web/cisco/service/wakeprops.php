<?

$cisco = 1;
require "../../include/finnegan.inc";

if(isset($_REQUEST["id"])) {
	$id = preg_replace("/[^0-9]/", "", $_REQUEST["id"]);
	if(!$id) cisco_message("Invalid Alarm", "Please select a valid alarm.", $FinneganCiscoConfig->url_base."/service/wakes.php");

	$wake = get_wake($id);
	if(!$wake) cisco_message("Invalid Alarm", "Please select a valid alarm.", $FinneganCiscoConfig->url_base."/service/wakes.php");
?>
		<CiscoIPPhoneText>
		<Name>Alarm Properties</Name>
		<Text><? echo format_wake($wake) ?></Text>

		<SoftKeyItem>
		<Name>Edit</Name>
		<Position>1</Position>
		<URL><? echo $FinneganCiscoConfig->url_base ?>/service/mkwake.php?id=<?echo $id?></URL>
		</SoftKeyItem>

		<SoftKeyItem>
		<Name>Delete</Name>
		<Position>2</Position>
		<URL><? echo $FinneganCiscoConfig->url_base ?>/service/rmwake.php?id=<?echo $id?></URL>
		</SoftKeyItem>

		<SoftKeyItem>
		<Name><? echo $wake["disabled"] ? "Activate" : "Deactivate" ?></Name>
		<Position>3</Position>
		<URL><? echo $FinneganCiscoConfig->url_base ?>/service/togglewake.php?id=<?echo $id?></URL>
		</SoftKeyItem>

		<SoftKeyItem>
		<Name>Back</Name>
		<Position>4</Position>
		<URL><? echo $FinneganCiscoConfig->url_base ?>/service/wakes.php</URL>
		</SoftKeyItem>

		</CiscoIPPhoneText>
<?
	}
} else {
	cisco_message("Select Alarm", "Please select an alarm to view.", $FinneganCiscoConfig->url_base."/service/wakes.php");
}

?>
