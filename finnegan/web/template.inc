<?
//See template-spec.txt for documentation.

function errmsg($msg) { return "<p class=\"error\">$msg  Check <a href=\"docs.php\">the Finnegan documentation</a> or <a href=\"mailto:finnegan@brandeis.edu\">email finnegan@brandeis.edu</a> for assistance.</p>\n"; }

$TEMPLATE = array(
	"page_start" => <<<END_PAGE_START
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">
<html>
<head>
<title>Finnegan: Brandeis wake-up calls</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
<style type="text/css" media="screen">
	@import url(finnegan.css);
</style>
</head>
<body>
<h1>Finnegan</h1>
<h2>Brandeis wake-up calls, sponsored by the Student Union and the Computer Operators Group</h2>
END_PAGE_START
,

	"viewcalls_start_noext" => <<<END_VIEWCALLS_START_NOEXT
<ul class="navigation">
<li><a href="docs.php">Help with Finnegan</a></li>
</ul>
<h3>Log In to Finnegan</h3>
<form method="post" action="index.php">
END_VIEWCALLS_START_NOEXT
,

	"viewcalls_start" => <<<END_VIEWCALLS_START
<ul class="navigation">
<li><a href="docs.php">Help with Finnegan</a></li>
<li><a href="mkwake.php">Create a New Wake-up Call</a></li>
</ul>
<h3>View Your Wake-up Calls</h3>
<form method="post" action="index.php">
END_VIEWCALLS_START
,

	"mkwake_new_start" => <<<END_MKWAKE_NEW_START
<ul class="navigation">
<li><a href="docs.php">Help with Finnegan</a></li>
<li><a href="index.php">View Your Wake-up Calls</a></li>
</ul>
<h3>Create a New Wake-up Call</h3>
<form method="post" action="mkwake.php">
<input type="hidden" name="op" value="create" />
END_MKWAKE_NEW_START
,

	"mkwake_edit_start" => <<<END_MKWAKE_EDIT_START
<ul class="navigation">
<li><a href="docs.php">Help with Finnegan</a></li>
<li><a href="index.php">View Your Wake-up Calls</a></li>
</ul>
<h3>Edit a Wake-up Call</h3>
<form method="post" action="mkwake.php">
<input type="hidden" name="op" value="edit" />
<input type="hidden" name="id" value="__ID__" />
END_MKWAKE_EDIT_START
,

	"docs_start" => <<<END_DOCS_START
<ul class="navigation">
<li><a href="index.php">View Your Wake-up Calls</a></li>
<li><a href="mkwake.php">Create a New Wake-up Call</a></li>
</ul>
<h3>Documentation</h3>
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
<thead><tr><th></th><th></th><th>Time</th><th>Date (mm/dd)/Days</th><th>Calendar Type</th></tr></thead>
<tbody>
END_WAKE_LIST_START
,

	"wake_list_item_once" => <<<END_WAKE_LIST_ITEM_ONCE
<tr __DELETE_CLASS__>
	<td><input type="checkbox" name="id[__ID__]" value="1" __DELETE__ /></td>
	<td><a href="mkwake.php?id=__ID__">Edit</a></td>
	<td>__TIME__</td>
	<td>__DATE__</td>
	<td></td>
</tr>
END_WAKE_LIST_ITEM_ONCE
,

	"wake_list_item_recur" => <<<END_WAKE_LIST_ITEM_RECUR
<tr __DELETE_CLASS__>
	<td width="5%"><input type="checkbox" name="id[__ID__]" value="1" __DELETE__ /></td>
	<td width="15%"><a href="mkwake.php?id=__ID__">Edit</a></td>
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

	"delete_confirm" => <<<END_DELETE_CONFIRM
<p class="error">
Are you sure you want to delete the selected wake-up calls?<br />
<input type="submit" name="op" value="Confirm Deletion" />
</p>
END_DELETE_CONFIRM
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

	"extension_invalid" => errmsg("The extension you entered is invalid."),
	"extension_forbidden" => errmsg("That extension is not allowed to receive wake-up calls."),
	"db_error" => errmsg("There was a problem with the database: <tt>__ERROR__</tt>. Please try again later.  If the problem persists, please report it to <a href=\"mailto:finnegan@brandeis.edu\">finnegan@brandeis.edu</a>."),
	"date_error" => errmsg("There was a problem with a date or time: '<tt>__DATE__</tt>'. Please try again later.  If the problem persists, please report it to <a href=\"mailto:finnegan@brandeis.edu\">finnegan@brandeis.edu</a>."),
	"pin_invalid" => errmsg("The PIN you entered is invalid.  A PIN must be between one and four digits long, and can only contain the digits 0 through 9."),
	"pin_set_new_invalid" => errmsg("Your PIN could not be set because the new PIN you entered is invalid.  A PIN must be between one and four digits long, and can only contain the digits 0 through 9."),
	"pin_error" => errmsg("The PIN you entered is incorrect.  If you've forgotten your PIN, please click the \"Forgot PIN\" button, and the system will call you with your PIN."),
	"pin_mismatch" => errmsg("The values you entered for 'New PIN' and 'Confirm New PIN' don't match. Please try again."),
	"pin_empty" => errmsg("You have entered a PIN, but your extension doesn't have a PIN associated with it. To set a PIN, use the 'change PIN' field on the main screen."),
	"pin_bruteforce_warn" => errmsg("You have been entering too many incorrect PINs.  If you enter another incorrect PIN, you will be temporarily locked out of the system."),
	"pin_bruteforce" => errmsg("You have entered too many incorrect PINs and are temporarily locked out of the system. Please wait an hour, and then click the 'Forgot PIN' button below."),
	"pin_set_old_error" => errmsg("Your PIN could not be set because you entered your old PIN incorrectly. Please try again."),
	"pin_set_new_mismatch" => errmsg("Your PIN could not be set because what you typed for \"New PIN\" didn't match what you typed for \"Confirm New PIN\".  Please try again."),

	"pin_set_ok" => <<<END_PIN_SET_OK
<p class="status">
Your PIN was successfully changed.
</p>
END_PIN_SET_OK
,

	"pin_sent" => <<<END_PIN_SENT
<p class="status">
The system will call you and tell you your PIN as soon as it is available.
It shouldn't take more than a few minutes.  If, after 15 minutes, the system
has not called you, please contact <a href=\"mailto:finnegan@brandeis.edu\">finnegan@brandeis.edu</a> for assistance.
</p>
END_PIN_SENT
,

	"id_invalid" => errmsg("Wake-up call not found."),
	"time_invalid" => errmsg("Please enter a valid time."),
	"ampm_invalid" => errmsg("Please specify 'AM' or 'PM'."),
	"message_invalid" => errmsg("Please enter a valid wake-up message number."),
	"date_invalid" => errmsg("Please enter a valid date."),
	"weekdays_invalid" => errmsg("Please select one or more days of the week."),
	"cal_type_invalid" => errmsg("Please select a valid calendar type."),
	"type_invalid" => errmsg("Please select a type of wake-up call.  If you've selected a recurring wake-up call, do not enter a date, and select which days of the week the wake-up call should be activate on.  If you've selected a one-time wake-up call, enter a date, and do not select days of the week."),
	"time_unavailable_onetime" => errmsg("Too many wake-up calls are scheduled for that time, no phone lines available."),
	"time_unavailable_recur" => errmsg("Too many wake-up calls are scheduled for that time, no phone lines available.  That time was unavailable on the following days: __DAYS__"),
	"too_many_wakes" => errmsg("You have too many wake-up calls.  You may only have ten.  Try using recurring wake-up calls instead of setting one-time calls for every day, or delete some of your other wake-up calls.  If you need more wake-up calls, email <a href=\"mailto:finnegan@brandeis.edu\">finnegan@brandeis.edu</a>"),

	"mkwake_form" => <<<END_MKWAKE_FORM
<p>
1. Enter a time for the wake-up call.<br />
Time: <input type="text" name="time" size="6" maxlength="5" value="__TIME__" /><br />
<input type="radio" name="ampm" value="AM" __AM__ /> AM<br />
<input type="radio" name="ampm" value="PM" __PM__ /> PM<br />
</p><p>
2. Select a wake-up message.  This is the message you will hear when you pick up your wake-up call.<br />
Messages:
</p><ol>
<!-- <li>"Hello, this is Matthew Sachs, and I pronounce 'Finnegan' as 'Finnegan'.</li> -->
<li>"This is your wake-up call."</li>
<li>"WAKE UP!!"</li>
</ol><p>
Message: <input type="text" name="message" size="3" maxlength="2" value="__MESSAGE__" />
</p><p>
3. Would you like this to be a one-time wake-up call or a recurring wake-up call?  A one-time wake-up call
will call you once, on a particular date at a particular time.  A recurring wake-up call will call you
every time it's a particular day or days of the week, at a particular for time.  For instance, you could
set a recurring wake-up call to call you every Tuesday and Friday at 8:42 AM.<br />
<input type="radio" name="type" value="one-time" __ONETIME__ /> One-time
<input type="radio" name="type" value="recur" __RECUR__ /> Recurring
</p><p>
4a. <strong>Skip this step for recurring wake-up calls.</strong> Enter the date, in month/day format,
that this wake-up call is for.  For instance, for a March 20th wake-up call, enter 3/20.  You don't need
to specify a year; Finnegan will automatically set the wake-up call for the next time the date and time
roll around (so if it's December, and you enter a date in January, it will go off next month.)<br />
Date: <input type="text" name="date" size="6" maxlength="5" value="__DATE__" />
</p><p>
4b. <strong>Skip this step for one-time wake-up calls.</strong> Which days of the week
would you like this wake-up call to call you on?<br />
Standard Active Weekdays: <br />
<input type="checkbox" name="mon" value="1" __MON__ /> Monday<br />
<input type="checkbox" name="tue" value="1" __TUE__ /> Tuesday<br />
<input type="checkbox" name="wed" value="1" __WED__ /> Wednesday<br />
<input type="checkbox" name="thu" value="1" __THU__ /> Thursday<br />
<input type="checkbox" name="fri" value="1" __FRI__ /> Friday<br />
<input type="checkbox" name="sat" value="1" __SAT__ /> Saturday<br />
<input type="checkbox" name="sun" value="1" __SUN__ /> Sunday
</p><p>
5b. <strong>Skip this step for one-time wake-up calls.</strong> Which type of calendar
would you like this wake-up call to use?  Calls which use the "Brandeis" calendar will
only call you if the University is having classes on that day, and it will treat
Brandeis Mondays as Monday.  Calls which use the "National Holidays" calendar
won't call you on national holidays.  Calls which use the "Normal" calendar
don't do anything special.<br />
Calendar Type: <select name="cal_type">
<option value="Brandeis" __CALTYPE_BRANDEIS__>Brandeis</option>
<option value="holidays" __CAPTYPE_HOLIDAYS__>National Holidays</option>
<option value="normal" __CALTYPE_NORMAL__>Normal</option>
</select>
</p></p>
6b. <strong>Skip this step for one-time wake-up calls.</strong> If you want
your recurring wake-up call to skip a particular day the next time that call
would otherwise be activated on that day, you can select a different set of
days here.  You might want to do this if a class has been cancelled one day.
This isn't very useful for new wake-up calls, and if you're creating a new
wake-up call you can safely ignore it, but you can use the 'Edit'
link to set this later.<br />
Current Active Weekdays:<br />
<input type="checkbox" name="mon_cur" value="1" __MON_CUR__ /> Monday<br />
<input type="checkbox" name="tue_cur" value="1" __TUE_CUR__ /> Tuesday<br />
<input type="checkbox" name="wed_cur" value="1" __WED_CUR__ /> Wednesday<br />
<input type="checkbox" name="thu_cur" value="1" __THU_CUR__ /> Thursday<br />
<input type="checkbox" name="fri_cur" value="1" __FRI_CUR__ /> Friday<br />
<input type="checkbox" name="sat_cur" value="1" __SAT_CUR__ /> Saturday<br />
<input type="checkbox" name="sun_cur" value="1" __SUN_CUR__ /> Sunday
</p><p>
<input type="submit" name="submit" value="Submit" /><br />
</p><p>
<input type="reset" />
</p>
END_MKWAKE_FORM
,

	"docs_index_start" => <<<END_DOCS_INDEX_START
<h4>Index</h4>
<ol class="faq_index">
END_DOCS_INDEX_START
,

	"docs_index_entry" => <<<END_DOCS_INDEX_ENTRY
<li><a href="#__NUM__">__NAME__</></li>
END_DOCS_INDEX_ENTRY
,

	"docs_index_end" => <<<END_DOCS_INDEX_END
</ol>
END_DOCS_INDEX_END
,

	"docs_body_start" => "",

	"docs_body_entry" => <<<END_DOCS_BODY_ENTRY
<a name="__NUM__" /><h4>__NUM__. __NAME__</h4>
<p class="faq_item">
__CONTENTS__
</p>
END_DOCS_BODY_ENTRY
,

	"docs_body_end" => ""
);
?>
