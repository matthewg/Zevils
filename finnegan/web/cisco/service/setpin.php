<?

$cisco = 1;
require "../../include/finnegan.inc";

if(isset($_REQUEST["pin"])) {
	$pin = $_REQUEST["pin"];
	if(pin_syntax_check($pin)) {
		cisco_error("Invalid PIN", "Please enter a valid PIN of up to four digits.");
	} else {
		set_pin($extension, $pin);
		if($pin) {
			cisco_message("PIN Set", "Your PIN has been set.");
		} else {
			cisco_message("PIN Set", "PIN cleared.  This will prevent you from accessing the system via the web.");
		}
	}
} else {
?>
<CiscoIPPhoneInput>
<Title>Set PIN</Title>
<Prompt>Enter new PIN</Prompt>
<URL><?echo $FinneganCiscoConfig->url_base ?>/service/setpin.php</URL>
<InputItem>
<DisplayName>New PIN</DisplayName>
<QueryStringParam>pin</QueryStringParam>
<InputFlags>N</InputFlags>
</InputItem>
<SoftKeyItem>
<Name>About</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/about.php</URL>
</SoftKeyItem>
</CiscoIPPhoneInput>
<?
}
?>
