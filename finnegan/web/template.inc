<?
/*
 * Description of template items:
 *	page_start: Top of the entire page.
 *		TITLE: Title of the page
 *	viewcalls_start: Start of the 'view wake-up calls' page.  This will be called immediately after 'page_start'.
 *	viewcalls_start_noext: This is called instead of viewcalls_start if we don't know the user's extension.
 *	mkwake_new_start: Start of the 'new wake-up call' page.
 *	mkwake_edit_start: Start of the 'edit wake-up call' page.
 *		ID: ID of the wake-up call being edited.
 *	docs_start: Start of the documentation page.
 *
 *
 *  Wake-up call list.  To give the user the ability to edit their wake-up calls,
 *   submit a POST request to index.php as per the method for creating wake-up calls
 *   below, but use op='edit' instead of op='create', and give an 'id' parameter containing
 *   the wake-up call ID.  Also, for recurring wake-up calls, use parameters named 'cur_xxx'
 *   where 'xxx' is mon/tue/wed/thu/fri/sat/sun to set one-time exceptions to the normal
 *   schedule for the wake.  To delete wake-up calls, use a POST request with op="Delete marked wake-up calls"
 *   and set the parameter named 'id[__ID__]' for each wake to delete.
 *
 *	wake_list_start: Start of a user's wake-up call list
 *		COUNT: Number of wake-up calls that the user has.
 *	wake_list_item_once: A one-shot wake-up call in the wake-up call list
 *		ID: Unique identifier for this wake-up call
 *		DELETE: If 'SELECTED', this wake-up call was flagged for deletion.
 *			Otherwise, blank.  Note that wake-up calls marked for
 *			deletion will be wrapped in <span class="wake-delete">...</span>
 *		TIME: Time that the wake-up call is set for
 *		MESSAGE: Number of the wake-up message that the call is using
 *		DATE: Date that the wake-up call is set for
 *	wake_list_item_recur: A recurring wake-up call in the wake-up call list
 *		ID: As above
 *		DELETE: As above
 *		TIME: As above
 *		MESSAGE: As above
 *		DAYS: List of days of week, with active ones in span class 'weekday-on',
 *			temporarily inactive ones in class 'weekday-off', and temporarily
 *			active ones in class 'weekday-temp'.  For instance, for a wake-up
 *			call which is normally active on Monday, Wednesday, and Thursday,
 *			but this week the user has deactivated Wednesday and checked off
 *			Tuesday instead, DAYS would be set to:
 *				<span class="weekday-on">Mon</span>, <span class="weekday-temp">Tue</span>, <span class="weekday-off">Wed</span>, <span class="weekday-on">Thu</span>
 *		CAL: Type of calendar that the wake-up call uses: 'Regular'/'Brandeis'/'National Holidays'
 *	wake_list_end: End of the wake-up call list
 *
 *	delete_confirm: "Confirm Deletion" button.
 *		This template is called if op='delete' was posted.  It should
 *		post to index.php with op='delete_confirm'.
 *
 *
 *	extension_invalid: Show 'extension invalid' error.
 *	get_extension: Ask for the user's extension.  This should submit a POST request to index.php.
 *		EXTENSION: Value of the user's extension.  May be present if the user entered an invalid extension.
 *		Form parameters:
 *			extension: User's extension
 *			pin: User's PIN (4-digit number).  If the user did not previously have a PIN, and one is present here, a PIN will be set.  Otherwise, this must match the user's previously-set PIN.
 *			savepin: If this parameter is present, the user's PIN will be saved in a cookie.
 *			op: 'Forgot PIN' to have the system call the user's extension and tell the user his/her PIN.
 *
 *	viewcalls_end: End of the 'view wake-up calls' page.  This will be called immediately before 'foot'.
 *	viewcalls_end_noext: This is called instead of viewcalls_start if we don't know the user's extension.
 *	mkwake_new_end: End of the 'new wake-up call' page.
 *	mkwake_edit_end: End of the 'edit wake-up call' page.
 *	docs_end: End of the documentation page.
 *	page_end: End of the entire page.
 *
 *	db_error: Database error.
 *		ERROR: Error message
 *	date_error: Problem with a date/time.
 *		ERROR: Error message
 *	pin_error: Incorrect PIN.
 *	pin_invalid: Syntactically invalid PIN.
 *	pin_empty: User gave PIN, but doesn't have one set.
 *	pin_bruteforce_warn: User will be temporarily locked out of the system if they enter a bad PIN again.
 *	pin_bruteforce: User has had too many recent login failures, and should wait an hour.
 *	pin_sent: System will soon call the user's extension and read out the PIN.
 *	pin_set_old_error: When setting PIN, "old PIN" is wrong.
 *	pin_set_new_mismatch: When setting PIN, pin1 != pin2
 *	pin_set_new_invalid: When setting PIN, new PIN is not syntactically valid.
 *	pin_set_ok: Pin changed.
 *
 *
 * Things that you must do somewhere in your template:
 *
 *	Link to take the user to the page for creating a new wake-up call. (mkwake.php)
 *		The page should post the following data to mkwake.php:
 *			op: 'create'
 *			extension: User's extension
 *			time: Time of the wake-up call
 *			ampm: 'AM' if time is 'AM', otherwise 'PM'
 *			message: Number of the wake-up message the user wants
 *			One-time wake-up calls:
 *				month: Number (1-12) of month for the wake
 *				day: Number (1-31) of day of month for the wake
 *			Recurring wake-up calls:
 *				mon: If present, this call is active on Mondays.
 *				tue: If present, this call is active on Tuesdays.
 *				wed: If present, this call is active on Wednesdays.
 *				thu: If present, this call is active on Thursdays.
 *				fri: If present, this call is active on Fridays.
 *				sat: If present, this call is active on Saturdays.
 *				sun: If present, this call is active on Sundays.
 *				cal_type:
 *					'brandeis': Use the Brandeis calendar for this wake.
 *					'holidays': Use the American calendar for this wake, skipping national holidays.
 *					'normal': Use the regular calendar for this wake.
 *
 *	Link to take the user to a documentation page. (docs.php)
 *
 *	Submitting to index.php with op='Log Out' will clear the user's saved PIN.
 *
 *	Submitting to index.php with op='Set Pin', and parameters 'oldpin', 'pin1', and 'pin2'
 *	will change the user's PIN.  oldpin must match the previous PIN, and pin1 and pin2
 *	must match.
 *
 * You should probably use the page_start/page_end from your template for your documentation
 * and 'new wake-up call' pages.
 */

$TEMPLATE = array(
	"page_start" => <<<END_PAGE_START
<html>
<head>
<title>__TITLE__</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
<style type="text/css" media="screen">
	@import url(/finnegan.css);
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
