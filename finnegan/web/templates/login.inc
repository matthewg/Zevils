<?

$TEMPLATE["login"] = array(
	"title" => "Finnegan: Log In",
	"start" => <<<END
<ul class="navigation">
<li><a href="docs.php">Help With Finnegan</a></li>
</ul>
<h3>Log In</h3>
END
;

	"script" => "",
	"head" => "",
	"end" => "",

	"extension_invalid" => errmsg("The extension you entered is invalid."),
	"extension_forbidden" => errmsg("That extension is not allowed to receive wake-up calls."),
	"pin_invalid" => errmsg("The PIN you entered is invalid.  A PIN must be between one and four digits long, and can only contain the digits 0 through 9."),
	"pin_error" => errmsg("The PIN you entered is incorrect.  If you've forgotten your PIN, please click the \"Forgot PIN\" button, and the system will call you with your PIN."),
	"pin_bruteforce" => errmsg("You have entered too many incorrect PINs and are temporarily locked out of the system. Please wait an hour, and then click the 'Forgot PIN' button below."),

	"pin_sent" => <<<END
<p class="status">
The system will call you and tell you your PIN as soon as it is available.
It shouldn't take more than a few minutes.  If, after 15 minutes, the system
has not called you, please contact <a href=\"mailto:finnegan@brandeis.edu\">finnegan@brandeis.edu</a> for assistance.
</p>
END
,

	"pin_not_found" => errmsg("The system could not locate your PIN.  Try logging in without one, and you will be prompted to set a new PIN."),

	"form" => <<END
<form method="post" action="login.php">
<p>
Please enter your 5-digit Brandeis extension.  If you've previously set a PIN, enter it here, too.  If you've never used the
system before, leave your PIN blank.
If you'd like your PIN to be saved on this computer, check the 'Save PIN' box.
</p><p>
If you've forgotten your PIN and would like to have the system call you and you it,
click the "Forgot PIN" button below.
</p><p>
Extension: <input type="text" name="extension" size="6" maxlength="5" value="__EXTENSION__" /><br />
PIN: <input type="password" name="pin" size="5" maxlength="4" /><br />
<input type="checkbox" name="savepin" value="1" />Save PIN<br />
<input type="submit" name="op" value="View Wake-up Calls" /><br />
<input type="submit" name="op" value="Forgot PIN" />
</p>
</form>
END

);

?>
