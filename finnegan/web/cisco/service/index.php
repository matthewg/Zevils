<?

$cisco = 1;
require "../../include/finnegan.inc";

?>

<CiscoIPPhoneMenu>
<Title>Wake-up Calls</Title>
<Prompt>Select an option</Prompt>

<MenuItem>
<Name>View/Edit Alarms</Name>
<URL><?echo $FinneganCiscoConfig->url_base?>/service/wakes.php</URL>
</MenuItem>

<MenuItem>
<Name>New Alarms</Name>
<URL><?echo $FinneganCiscoConfig->url_base?>/service/mkwake.php</URL>
</MenuItem>

<MenuItem>
<Name>Set PIN</Name>
<URL><?echo $FinneganCiscoConfig->url_base?>/service/setpin.php</URL>
</MenuItem>

<SoftKeyItem>
<Name>About</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/about.php</URL>
</SoftKeyItem>

</CiscoIPPhoneMenu>
