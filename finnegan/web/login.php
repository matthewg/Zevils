<?

$page = "login";
require "include/finnegan.inc";
page_start();

if(isset($_POST["op"])) {
	$op = $_POST["op"];
	if($op == "Forgot PIN" && $extension_ok && $extension) {
		if(!mysql_query("UPDATE prefs SET forgot_pin=1 WHERE extension='$extension'")) db_error();
		if(!mysql_affected_rows())
			echo $TEMPLATE["login"]["pin_not_found"];
		else
			echo $TEMPLATE["login"]["pin_sent"];
	}
} else if($auth_ok) {
	redirect("wakes.php");
} else if($auth_error != "no_extension") {
	if(isset($TEMPLATE["login"][$auth_error])) {
		echo $TEMPLATE["login"][$auth_error];
	} else {
		echo $TEMPLATE["global"][$auth_error];
	}
}

echo preg_replace("/__EXTENSION__/", $extension, $TEMPLATE["login"]["form"]);

page_end();

?>
