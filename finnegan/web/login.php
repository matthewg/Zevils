<?

$page = "login";
require "include/finnegan.inc";
page_start();

if(isset($_POST["op"])) {
	if($auth_ok) redirect("wakes.php");
	$op = $_POST["op"];
	if($op == "Forgot PIN" && $extension_ok && $extension) {
		if(!$FinneganConfig->use_cisco || !$FinneganCiscoConfig->use_xml_service) {
			if(!mysql_query("UPDATE prefs SET forgot_pin=1 WHERE extension='$extension'")) db_error();
			if(!mysql_affected_rows() && !mysql_num_rows(mysql_query("SELECT * FROM prefs WHERE extension='$extension'")))
				echo $TEMPLATE["login"]["pin_not_found"];
			else
				echo $TEMPLATE["login"]["pin_sent"];
		}
	}
}

if($auth_ok) {
	redirect("wakes.php");
} else if($auth_error != "no_extension" && $auth_error) {
	if(isset($TEMPLATE["login"][$auth_error])) {
		echo $TEMPLATE["login"][$auth_error];
	} else {
		echo $TEMPLATE["global"][$auth_error];
	}
}

echo preg_replace("/__EXTENSION__/", $extension, $TEMPLATE["login"]["form"]);

page_end();

?>
