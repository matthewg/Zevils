<?

$TEMPLATE["setpin"] = array(
	"title" => "Finnegan: Change PIN or Log Out",
	"start" => <<<END
<ul class="navigation">
<li><a href="wakes.php">View Wake-up Alarms</a></li>
<li><a href="mkwake.php">Create New Alarm</a></li>
<li><a href="docs.php">Help With Finnegan</a></li>
</ul>
<h3>Change PIN or Log Out</h3>
END
,

	"script" => "",
	"head" => "",
	"end" => "",

	"old_pin_error" => errmsg("Your PIN could not be set because you entered your old PIN incorrectly. Please try again."),
	"old_pin_invalid" => errmsg("Your PIN could not be set because you entered an invalid old PIN. Please try again."),
	"new_pin_invalid" => errmsg("Your PIN could not be set because the new PIN you entered is invalid.  A PIN must be between one and four digits long, and can only contain the digits 0 through 9."),
	"new_pin_mismatch" => errmsg("The values you entered for 'New PIN' and 'Confirm New PIN' don't match. Please try again."),
	"ok" => <<<END
<p class="status">
Your PIN was successfully changed.
</p>
END
,

	"form" => <<<END
<form method="post" action="setpin.php">
<p>
Use this form to change your PIN.  You shouldn't use the same PIN that you use for voice mail, or anything else important.
Your PIN is not protected by very strong security.<br />
Old PIN: <input type="password" name="oldpin" size="5" maxlength="4" /><br />
New PIN: <input type="password" name="pin1" size="5" maxlength="4" /><br />
Confirm new PIN: <input type="password" name="pin2" size="5" maxlength="4" /><br />
<input type="submit" name="op" value="Set PIN" />
</p><p>
Log out to have your browser forget your PIN.  Note that you should do this even if you did
not check the "Save PIN" box, unless you want the browser to remember your PIN.<br />
<input type="submit" name="op" value="Log Out" />
</p>
</form>
END

);

?>
