<?

$faq_anchor = crc32("What are the advanced options for alarms?");

$TEMPLATE["mkwake"] = array(
	"title" => "Create/Edit Alarm",
	"start" => "",
	"new_start" => <<<END
<form method="post" action="mkwake.php">
END
,

	"edit_start" => <<<END
<form method="post" action="mkwake.php">
<input type="hidden" name="id" value="__ID__" />
END
,

	"script" => <<<END
var user_entered_date = false;

//Automatically set the date based on the time, to either today (if {today,enteredtime} is in future) or tomorrow
//...unless the user has entered some other date
function timechanged() {
	var datefield = getobj("date");
	var thetime = getobj("time");
	var curdate = new Date();
	var timebits = (new String(thetime.value)).split(":");
	var hours;
	var minutes;
	var enteredtime;
	var curtime;

	if(user_entered_date) return;

	if(timebits.length == 2) { //We have an h:mm
		hours = parseInt(timebits[0]);
		minutes = parseInt(timebits[1]);
		if(getobj("am_opt").checked) { //AM
			if(hours == "12") hours = 0;
		} else if(getobj("pm_opt").checked) { //PM
			if(hours != "12") hours = parseInt(hours) + 12;
		} else {
			return;
		}
		enteredtime = hours*60*60 + minutes*60;

		curtime = parseInt(curdate.getHours())*60*60 + parseInt(curdate.getMinutes()) - 60*60*2; //Give a two-hour fudge factor

		if(curtime > enteredtime) {
			curdate = new Date(curdate.getTime() + 1000*60*60*24); // Make 'curdate' tomorrow - getTime() is in milliseconds
		}

		datefield.value = (curdate.getMonth()+1) + "/" + curdate.getDate();
	}
}

function datechanged() {
	if(getobj("date").value == "") {
		user_entered_date = false;
	} else {
		user_entered_date = true;
	}
}
END
,

	"head" => "",
	"end" => "</form>",

	"id_invalid" => errmsg("Wake-up call not found."),
	"time_invalid" => errmsg("Please enter a valid time."),
	"ampm_invalid" => errmsg("Please specify 'AM' or 'PM'."),
	"message_invalid" => errmsg("Please enter a valid wake-up message number."),
	"max_snooze_count_invalid" => errmsg("Please enter a valid maximum snooze count."),
	"date_invalid" => errmsg("Please enter a valid date."),
	"weekdays_invalid" => errmsg("Please select one or more days of the week."),
	"cal_type_invalid" => errmsg("Please select a valid calendar type."),
	"type_invalid" => errmsg("Please select a type of wake-up call."),
	"time_unavailable_onetime" => errmsg("Too many wake-up calls are scheduled for that time, no phone lines available."),
	"time_unavailable_recur" => errmsg("Too many wake-up calls are scheduled for that time, no phone lines available.  That time was unavailable on the following days: __DAYS__."),
	"too_many_wakes" => errmsg("You have too many wake-up calls.  You may only have ten.  Try using recurring wake-up calls instead of setting one-time calls for every day, or delete some of your other wake-up calls.  If you need more wake-up calls, email <a href=\"mailto:finnegan@brandeis.edu\">finnegan@brandeis.edu</a>"),

	"message_link" => <<<END
<input type="radio" name="message" value="__NUM__" __SELECTED__><a href="__URL__">__NAME__</a></option><br />
END
,

	"message_option" => <<<END
END
,

	"form" => <<<END
<hr />
<p id="typesel">
<b>Alarm Type:</b><br />
<input type="radio" name="type" id="onetime_opt" onclick="hide('recur'); show('onetime');" value="one-time" __ONETIME__ /> One-time<br />
<input type="radio" name="type" id="recur_opt" onclick="hide('onetime'); show('recur');" value="recur" __RECUR__ /> Recurring
</p>
<hr />
<p>
<b>Time (h:mm):</b> <em>(Example: 8:23)</em><br />
<input type="text" name="time" id="time" size="6" maxlength="5" value="__TIME__" onchange="timechanged()" />
<input type="radio" name="ampm" id="am_opt" value="AM" __AM__ onchange="timechanged()" onclick="timechanged()" /> AM
<input type="radio" name="ampm" id="pm_opt" value="PM" __PM__ onchange="timechanged()" onclick="timechanged()" /> PM<br />
</p>
<hr />
<p><b>Message:</b> (click to preview) <br />
__MESSAGE_LINKS__
</p>
<hr />
<div id="onetime"><p>
<b>Date</b> (one-time alarms only): <input type="text" name="date" id="date" size="6" maxlength="5" value="__DATE__" onchange="datechanged()" />
</p>
<hr />
</div><div id="recur"><p>
<b>Days of the Week</b> (recurring alarms only):<br />
<input type="checkbox" name="mon" value="1" __MON__ /> Monday<br />
<input type="checkbox" name="tue" value="1" __TUE__ /> Tuesday<br />
<input type="checkbox" name="wed" value="1" __WED__ /> Wednesday<br />
<input type="checkbox" name="thu" value="1" __THU__ /> Thursday<br />
<input type="checkbox" name="fri" value="1" __FRI__ /> Friday<br />
<input type="checkbox" name="sat" value="1" __SAT__ /> Saturday<br />
<input type="checkbox" name="sun" value="1" __SUN__ /> Sunday
</p><p>
<b>Calendar Type</b> (recurring alarms only):<br />
<select name="cal_type">
<option value="Brandeis" __CALTYPE_BRANDEIS__>Brandeis</option>
<option value="holidays" __CALTYPE_HOLIDAYS__>National Holidays</option>
<option value="normal" __CALTYPE_NORMAL__>Normal</option>
</select>
</p>
<hr />
</div>
<p>
<b>Advanced Options:</b> (<a href="docs.php#$faq_anchor">What are these?</a>)<br />
Maximum snooze count: <input type="text" name="max_snooze_count" size="2" maxlength="1" value="__MAXSNOOZE__" />
</p>
<hr />
<p>
<input type="submit" name="submit" value="Set Alarm" /> <input type="reset" />
</p>
<script type="text/javascript">
//<!--
if(!getobj("onetime_opt").checked) hide("onetime");
if(!getobj("recur_opt").checked) hide("recur");
if(getobj("date").value != "") user_entered_date = true;
// -->
</script>
END

);

?>
