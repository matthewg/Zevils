<?

$TEMPLATE["login"] = array(
	"title" => "Log In",
	"start" => "",
	"script" => "",
	"head" => "",
	"end" => "",

	"extension_invalid" => errmsg("The extension you entered is invalid."),
	"extension_forbidden" => errmsg("That extension is not allowed to receive wake-up calls."),
	"pin_invalid" => errmsg("The PIN you entered is invalid.  A PIN must be between one and four digits long, and can only contain the digits 0 through 9."),
	"pin_error" => errmsg("The PIN you entered is incorrect.  If you've forgotten your PIN, set a new one through the phone service."),
	"pin_bruteforce" => errmsg("You have entered too many incorrect PINs and are temporarily locked out of the system. Please wait an hour."),
	"too_many_newpins" => errmsg("You have been generating too many PINs and have been temporarily locked out of the system.  Please wait an hour."),

	"no_pin" => <<<END
<p class="status">
A PIN has been generated for you.  The system will be calling you with your PIN shortly.
It shouldn't take more than a few minutes.  If, after 15 minutes, the system
has not called you, please contact <a href=\"mailto:finnegan@brandeis.edu\">finnegan@brandeis.edu</a> for assistance.
</p>
END
,

	"pin_sent" => <<<END
<p class="status">
The system will call you and tell you your PIN as soon as it is available.
It shouldn't take more than a few minutes.  If, after 15 minutes, the system
has not called you, please contact <a href=\"mailto:finnegan@brandeis.edu\">finnegan@brandeis.edu</a> for assistance.
</p>
END
,

	"pin_not_found" => errmsg("The system could not locate your PIN.  Try logging in without one, and you will be prompted to set a new PIN."),

	"form" => <<<END
<form method="post" action="login.php">
<p>
Please enter your 5-digit Brandeis extension.  If you've previously set a PIN, enter it here, too.  If you've never used the system before, leave your PIN blank.
If you'd like your PIN to be saved on this computer, check the 'Save PIN' box.
</p><p>
If you've forgotten your PIN, set a new one through the service on the phone.
</p><p>
Extension: <input type="text" name="extension" size="6" maxlength="5" value="__EXTENSION__" /><br />
PIN: <input type="password" name="pin" size="5" maxlength="4" /><br />
<input type="checkbox" name="savepin" value="1" />Save PIN<br />
<input type="submit" name="op" value="Log In" />
</p>
</form>
END

);

if($FinneganConfig->use_cisco && $FinneganCiscoConfig->use_xml_service) {
	$pin_set_instructions = "See <a href=\"http://phoneapps.brandeis.edu/docs.php#-791461759\">the Finnegan documentation</a> for instructions on accessing the service.";

	$TEMPLATE["login"]["no_pin"] = '<p class="status">Please use the wakeup call service on your phone to set a PIN.  ' . $pin_set_instructions . '</p>';
	$TEMPLATE["login"]["form"] = preg_replace("/leave your PIN blank./", "set a PIN via the wakeup call service on your phone.  $pin_set_instructions", $TEMPLATE["login"]["form"]);
}

?>
