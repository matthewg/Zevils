<?

$cisco = 1;
require "../../include/finnegan.inc";

if(isset($_REQUEST["id"])) {
	$id = preg_replace("/[^0-9]/", "", $_REQUEST["id"]);
	if(!$id) cisco_message("Invalid Alarm", "Please select a valid alarm.", $FinneganCiscoConfig->url_base."/service/wakes.php");

	if(isset($_REQUEST["confirm"])) {
		$wake = @mysql_query("DELETE FROM wakes WHERE extension='$extension' AND wake_id=$id");
		if(!$wake) db_error();

		if(!mysql_affected_rows()) {
			cisco_message("Invalid Alarm", "Please select a valid alarm.", $FinneganCiscoConfig->url_base."/service/wakes.php");
		} else {
			cisco_message("Alarm Deleted", "Alarm deleted.", $FinneganCiscoConfig->url_base."/service/wakes.php");
		}
	} else {
		$wake = get_wake($id);
?>
		<CiscoIPPhoneText>
		<Name>Confirm Deletion</Name>
		<Text><? echo format_wake($wake) ?></Text>
		<Prompt>Are you sure?</Prompt>

		<SoftKeyItem>
		<Name>Yes</Name>
		<Position>1</Position>
		<URL><? echo $FinneganCiscoConfig->url_base ?>/service/rmwake.php?id=<?echo $id?>&amp;confirm=1</URL>
		</SoftKeyItem>

		<SoftKeyItem>
		<Name>No</Name>
		<Position>4</Position>
		<URL><? 
			if($PHONE_MODEL == "CP-7912G")
				echo $FinneganCiscoConfig->url_base."/service/wakeprops.php?id=$id";
			else
				echo $FinneganCiscoConfig->url_base."/service/wakes.php";
		?></URL>
		</SoftKeyItem>

		</CiscoIPPhoneText>
<?
	}
} else {
	cisco_message("Select Alarm", "Please select an alarm to delete.", $FinneganCiscoConfig->url_base."/service/wakes.php");
}

?>
