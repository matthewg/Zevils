<?

$page = "setpin";
require "include/finnegan.inc";
page_start();

if(!$auth_ok) redirect("login.php");

if(isset($_POST["op"])) {
	$op = $_POST["op"];
	if($op == "Set PIN") {
		$oldpin = isset($_POST["oldpin"]) ? $_POST["oldpin"] : "";
		$pin1 = isset($_POST["pin1"]) ? $_POST["pin1"] : "";
		$pin2 = isset($_POST["pin2"]) ? $_POST["pin2"] : "";
		$error = "";
		if($oldpin != $pin) {
			echo $TEMPLATE["setpin"]["old_pin_error"];
			$error = "old_pin_error";
		} else if($pin1 != $pin2) {
			echo $TEMPLATE["setpin"]["new_pin_mismatch"];
			$error = "new_pin_mismatch";
		} else if($pin_error = pin_check($extension, $pin1, 1)) {
			echo $TEMPLATE["setpin"]["new_pin_invalid"];
			$error = "new_pin_invalid";
		} else {
			set_pin($extension, $pin1);

			if($savepin) {
				setcookie("finnegan-pin", $pin1, time()+60*60*24*365);
			} else {
				setcookie("finnegan-pin", $pin1);
			}

			echo $TEMPLATE["setpin"]["ok"];
		}

		if($error) log_ext($extension, "setpin", "failure", $error);
	} else if($op == "Log Out") {
		unset($_COOKIE["finnegan-pin"]);
		unset($_POST["pin"]);
		setcookie("finnegan-pin", "", time()-3600);
		setcookie("finnegan-savepin", "", time()-3600);

		if($extension_ok) log_ext($extension, "delcookie", "success");
		redirect("login.php");
	}
}

echo preg_replace("/__EXTENSION__/", $extension, $TEMPLATE["setpin"]["form"]);

page_end();

?>
