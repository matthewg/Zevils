<?
/*
 * Finnegan stores the user's extension in a cookie called finnegan-extension.
 * This cookie will expire a year after it is set.
 * It will read the extension from there, or from a GET or POST variable called 'extension'.
 *
 * Description of template items:
 *	page_start: Top of the entire page.
 *		TITLE: Title of the page
 *	form_start: Starts an HTML form.  This will be called immediately after 'head'.
 *		FORM_PARAMETERS: Parameters for HTML form element
 *	form_start_noext: This is called instead of form_start if we don't know the user's extension.
 *		FORM_PARAMETERS: Parameters for HTML form element
 *
 *
 *  Wake-up call list.  To give the user the ability to edit their wake-up calls,
 *   submit a POST request to index.php as per the method for creating wake-up calls
 *   below, but use op='edit' instead of op='create', and give an 'id' parameter containing
 *   the wake-up call ID.  Also, for recurring wake-up calls, use parameters named 'cur_xxx'
 *   where 'xxx' is mon/tue/wed/thu/fri/sat/sun to set one-time exceptions to the normal
 *   schedule for the wake.  To delete wake-up calls, use a POST request with op=delete
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
 *			save: If this parameter is present, the user's PIN and extension will be saved in a cookie.
 *			op: Either 'login' to log the user in, or 'forgotpin' to have the system call the user's extension and tell the user his/her PIN.
 *
 *	form_end: Ends the HTML form started in 'form_start'.  This will be called immediately before 'foot'.
 *	page_end: End of the entire page.
 *
 *	db_error: Database error.
 *		ERROR: Error message
 *	date_error: Problem with a date/time.
 *		ERROR: Error message
 *	pin_error: Invalid PIN.
 *	pin_sent: System will soon call the user's extension and read out the PIN.
 *
 *
 * Things that you must do somewhere in your template:
 *
 *	Link to take the user to the page for creating a new wake-up call.
 *		The page should post the following data to index.php:
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
 *	Link to take the user to a documentation page.
 *
 *	Submitting to index.php with op='delcookie' will clear the user's saved PIN and extension.
 *
 *	Submitting to index.php with op='setpin', and parameters 'oldpin', 'pin1', and 'pin2'
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
<style type="text/css">
th {
	font-weight: bold
}
.weekday-off {
	text-decoration: line-through
}
.weekday-on {
	
}
.weekday-temp {
	font-style: italic
}
</style>
</head>
<body>
END_PAGE_START
,

	"form_start_noext" => <<<END_FORM_START_NOEXT
<h1><a href="docs.php">Help with Finnegan</a></h1>
<form __FORM_PARAMETERS__>
END_FORM_START_NOEXT
,

	"form_start" => <<<END_FORM_START
<h1><a href="docs.php">Help with Finnegan</a></h1>
<h1><a href="mkwake.php">Create a New Wake-up Call</a></h1>
<form __FORM_PARAMETERS__>
END_FORM_START
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
<table cols="5">
<tr><th>Delete?</th><th>Edit</th><th>Time</th><th>Date/Days</th><th>Calendar Type</th></tr>
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
	<td><input type="checkbox" name="id[__ID__]" value="1" __DELETE__ /></td>
	<td><a href="mkwake.php?id=__ID__;extension=__EXTENSION__">Edit</a></td>
	<td>__TIME__</td>
	<td>__DAYS__</td>
	<td>__CAL__</td>
</tr>
END_WAKE_LIST_ITEM_RECUR
,

	"wake_list_end" => <<<END_WAKE_LIST_END
</table>
<p><input type="submit" name="op" value="delete" text="Delete marked wake-up calls" /></p>
END_WAKE_LIST_END
,

	"form_end" => <<<END_FORM_END
</form>
END_FORM_END
,

	"page_end" => <<<END_PAGE_END
</body>
</html>
END_PAGE_END
,

	"get_extension" => <<<END_GET_EXTENSION
<p>
Please enter your 5-digit Brandeis extension.<br />
Extension: <input type="text" name="extension" size="6" length="5" value="__EXTENSION__" /> <input type="submit" name="submit" value="Submit" />
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

	"pin_error" => <<<END_PIN_ERROR
<p class="error">
The PIN you entered is invalid.  If you've forgotten your PIN, please
click the "Forgot PIN" button, and the system will call you with your PIN.
</p>
END_PIN_ERROR
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
