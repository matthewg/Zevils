<?
//See template-spec.txt for documentation.

$TEMPLATE = array(
	"page_start" => <<<END_PAGE_START
<html>
<head>
<title>__TITLE__</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
<style type="text/css" media="screen">
	@import url(finnegan.css);
</style>
</head>
<body>
END_PAGE_START
,

	"viewcalls_start_noext" => <<<END_VIEWCALLS_START_NOEXT
<h1><a href="docs.php">Help with Finnegan</a></h1>
<form method="post" action="index.php">
END_VIEWCALLS_START_NOEXT
,

	"viewcalls_start" => <<<END_VIEWCALLS_START
<h1><a href="docs.php">Help with Finnegan</a></h1>
<h1><a href="mkwake.php">Create a New Wake-up Call</a></h1>
<form method="post" action="index.php">
END_VIEWCALLS_START
,

	"mkwake_new_start" => <<<END_MKWAKE_NEW_START
<h1><a href="docs.php">Help with Finnegan</a></h1>
<h1><a href="index.php">View Your Wake-up Calls</a></h1>
<form method="post" action="mkwake.php">
<input type="hidden" name="op" value="create" />
END_MKWAKE_NEW_START
,

	"mkwake_edit_start" => <<<END_MKWAKE_EDIT_START
<h1><a href="docs.php">Help with Finnegan</a></h1>
<h1><a href="index.php">View Your Wake-up Calls</a></h1>
<form method="post" action="mkwake.php">
<input type="hidden" name="op" value="edit" />
<input type="hidden" name="id" value="__ID__" />
END_MKWAKE_EDIT_START
,

	"docs_start" => <<<END_DOCS_START
<h1><a href="index.php">View Your Wake-up Calls</a></h1>
<h1><a href="mkwake.php">Create a New Wake-up Call</a></h1>
END_DOCS_START
,

	"wake_list_start" => <<<END_WAKE_LIST_START
<p>
Your current wake-up calls are listed below.  To add a wake-up call,
<a href="mkwake.php">click here</a>.  To edit a wake-up call, click
the link marked 'Edit' in the row for that wake-up call.  To
delete wake-up calls, check the box in the row for each wake-up call
you'd like to delete, and then click the button mark 'Delete marked wake-up calls'
below.
</p>
<table rules="cols">
<thead><tr><th></th><th></th><th>Time</th><th>Date/Days</th><th>Calendar Type</th></tr></thead>
<tbody>
END_WAKE_LIST_START
,

	"wake_list_item_once" => <<<END_WAKE_LIST_ITEM_ONCE
<tr>
	<td><input type="checkbox" name="id[__ID__]" value="1" __DELETE__ /></td>
	<td><a href="mkwake.php?id=__ID__;extension=__EXTENSION__">Edit</a></td>
	<td>__TIME__</td>
	<td>__DATE__</td>
	<td></td>
</tr>
END_WAKE_LIST_ITEM_ONCE
,

	"wake_list_item_recur" => <<<END_WAKE_LIST_ITEM_RECUR
<tr>
	<td width="5%"><input type="checkbox" name="id[__ID__]" value="1" __DELETE__ /></td>
	<td width="15%"><a href="mkwake.php?id=__ID__;extension=__EXTENSION__">Edit</a></td>
	<td width="20%">__TIME__</td>
	<td width="35%">__DAYS__</td>
	<td width="25%">__CAL__</td>
</tr>
END_WAKE_LIST_ITEM_RECUR
,

	"wake_list_end" => <<<END_WAKE_LIST_END
</tbody>
</table>
<p><input type="submit" name="op" value="Delete marked wake-up calls" /></p>
END_WAKE_LIST_END
,

	"viewcalls_end" => <<<END_VIEWCALLS_END
<p>
Use this form to set or change your PIN.  You shouldn't use the same PIN that you use for voice mail, or anything else important.
Your PIN is not protected by very strong security. <br />
Old PIN: <input type="password" name="oldpin" size="5" maxlength="4" /><br />
New PIN: <input type="password" name="pin1" size="5" maxlength="4" /><br />
Confirm new PIN: <input type="password" name="pin2" size="5" maxlength="4" /><br />
<input type="submit" name="op" value="Set PIN" />
<p>
Log out to have your browser forget your PIN.  Note that you should do this even if you did
not check the "Save PIN" box, unless you want the browser to remember your PIN.<br />
<input type="submit" name="op" value="Log Out" />
</p>
</form>
END_VIEWCALLS_END
,

	"viewcalls_end_noext" => <<<END_VIEWCALLS_END_NOEXT
</form>
END_VIEWCALLS_END_NOEXT
,

	"mkwake_edit_end" => <<<END_MKWAKE_EDIT_END
</form>
END_MKWAKE_EDIT_END
,

	"mkwake_new_end" => <<<END_MKWAKE_NEW_END
</form>
END_MKWAKE_NEW_END
,

	"docs_end" => <<<END_DOCS_END
END_DOCS_END
,

	"page_end" => <<<END_PAGE_END
</body>
</html>
END_PAGE_END
,

	"get_extension" => <<<END_GET_EXTENSION
<p>
Welcome to Finnegan, the Brandeis wake-up call system, brought to you by the <a href="http://union.brandeis.edu/">Student Union</a>
and the <a href="http://www.brancog.org/">Computer Operators Group</a>.
</p><p>
Please enter your 5-digit Brandeis extension.  If you've previously set a PIN, enter it here, too.
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
END_GET_EXTENSION
,

	"extension_invalid" => <<<END_EXTENSION_INVALID
<p class="error">The extension you entered is invalid.</p>
END_EXTENSION_INVALID
,

	"db_error" => <<<END_DB_ERROR
<p class="error">
There was a problem with the database: <tt>__ERROR__</tt>.
Please try again later.  If the problem persists, please report it to blah blah.
</p>
END_DB_ERROR
,

	"date_error" => <<<END_DATE_ERROR
<p class="error">
There was a problem with a date or time: '<tt>__DATE__</tt>'.
Please try again later.  If the problem persists, please report it to blah blah.
</p>
END_DATE_ERROR
,

	"pin_invalid" => <<<END_PIN_INVALID
<p class="error">
The PIN you entered is invalid.  A PIN must be between one and four digits
long, and can only contain the digits 0 through 9.
</p>
END_PIN_INVALID
,

	"pin_set_new_invalid" => <<<END_PIN_SET_NEW_INVALID
<p class="error">
Your PIN could not be set because the new PIN you entered is invalid.  A PIN must be between one and four digits
long, and can only contain the digits 0 through 9.
</p>
END_PIN_SET_NEW_INVALID
,

	"pin_error" => <<<END_PIN_ERROR
<p class="error">
The PIN you entered is incorrect.  If you've forgotten your PIN, please
click the "Forgot PIN" button, and the system will call you with your PIN.
</p>
END_PIN_ERROR
,

	"pin_mismatch" => <<<END_PIN_MISMATCH
<p class="error">
The values you entered for 'New PIN' and 'Confirm New PIN' don't match.
Please try again.
</p>
END_PIN_MISMATCH
,

	"pin_empty" => <<<END_PIN_EMPTY
<p class="error">
You have entered a PIN, but your extension doesn't have a PIN associated with it.
To set a PIN, use the 'change PIN' field on the main screen.
</p>
END_PIN_EMPTY
,

	"pin_bruteforce_warn" => <<<END_PIN_BRUTEFORCE_WARN
<p class="error">
You have been entering too many incorrect PINs.  If you enter another incorrect PIN,
you will be temporarily locked out of the system.
</p>
END_PIN_BRUTEFORCE_WARN
,

	"pin_bruteforce" => <<<END_PIN_BRUTEFORCE
<p class="error">
You have entered too many incorrect PINs and are temporarily locked out of the system.
Please wait an hour, and then click the 'Forgot PIN' button below.
</p>
END_PIN_BRUTEFORCE
,

	"pin_set_old_error" => <<<END_PIN_SET_OLD_ERROR
<p class="error">
Your PIN could not be set because you entered your old PIN incorrectly.
Please try again.
</p>
END_PIN_SET_OLD_ERROR
,

	"pin_set_new_mismatch" => <<<END_PIN_SET_NEW_MISMATCH
<p class="error">
Your PIN could not be set because what you typed for "New PIN" didn't
match what you typed for "Confirm New PIN".  Please try again.
</p>
END_PIN_SET_NEW_MISMATCH
,

	"pin_set_ok" => <<<END_PIN_SET_OK
<p class="status">
Your PIN was successfully changed.
</p>
END_PIN_SET_OK
,

	"pin_sent" => <<<END_PIN_SENT
<p class="error">
The system will call you and tell you your PIN as soon as it is available.
It shouldn't take more than a few minutes.  If, after 15 minutes, the system
has not called you, please contact blah blah for assistance.
</p>
END_PIN_SENT
);
?>
