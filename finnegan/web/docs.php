<?

$faqs = array(
	array("Who's responsible for Finnegan?", <<<END_FAQITEM
The <a href="http://union.brandeis.edu/">Student Union</a> and <a href="http://www.brancog.org/">Computer Operators Group</a>
have provided the funding and equipment for Finnegan.  The system was developed, and is being maintained by,
<a href="http://www.zevils.com/">Matthew Sachs</a>, with help from <a href="http://people.brandeis.edu/~zeno/">Danny Silverman</a>
and <a href="http://people.brandeis.edu/~natb/">Nat Budin</a>.
END_FAQITEM
),

	array("Why does it keep calling me every 9 minutes?", <<<END_FAQITEM
You have to press a button on your phone (one of the buttons you use to dial, not the
volume or menu buttons) to confirm that you're awake.  Otherwise, the 'snooze button'
feature will kick in.  It will only 'snooze' a maximum of three times.
END_FAQITEM
),

	array("Does Finnegan have a 'snooze button' feature?", <<<END_FAQITEM
Yes - actually, it has a "'don't snooze' button".  You must press any button your phone's keypad during a wake-up call, or
it will act as if you had pressed the snooze button on a regular
alarm clock.  That is, you will be called again in 9 minutes.  A particular instance of a wake-up call
will only go off up to 4 times.
END_FAQITEM
),

	array("Why go to all this trouble when everyone has an alarm clock?", <<<END_FAQITEM
You can't tell an alarm clock "Wake up up at 8AM on Mondays, Wednesdays, and Thursdays and 11:30 on Tuesdays
and Fridays, and don't wake me up when don't have classes, and treat it like a Monday if we have a
Brandeis Monday.
END_FAQITEM
),

	array("Who recorded those fabulous messages?", <<<END_FAQITEM
The prompts, numbers, and the "This is your wake-up call" and "WAKE UP!!" wake-up messages
were recorded by <a href="http://www.zevils.com/">Matthew Sachs</a>.
"Wake up sleepy-head" and "Up at at 'em" were recorded by Randi Sachs, Matthew's mother, and are what
she used to say to wake Matthew up for grade school.
The "Musical Medley" wake-up message was arranged by <a href="http://people.brandeis.edu/~natb/">Nat Budin</a>, who also
recorded the planetary destruction message.  If you have suggestions for new wake-up messages, post them to
<a href="http://my.brandeis.edu/bboard/q-and-a?topic%5fid=592&topic=Finnegan%3a%20Wake%2dup%20Call%20System">the Finnegan bboard</a>.
END_FAQITEM
),

	array("Why is this called 'Finnegan'?", <<<END_FAQITEM
The name is a play on the title of <em>Finnegans Wake</em>, a novel by James Joyce.
You can read about the book at <a href="http://www.everything2.com/index.pl?node_id=65042">Everything2</a> and
<a href="http://www.amazon.com/exec/obidos/ASIN/0141181265">Amazon.com</a>, or check it out from
<a href="http://library.brandeis.edu/">the Brandeis library</a>.
END_FAQITEM
),

	array("Are there any plans to support off-campus phone numbers?", <<<END_FAQITEM
Support for local off-campus numbers is under consideration.  Support for long-distance
off-campus numbers is not currently planned, but post to <a href="http://my.brandeis.edu/bboard/q-and-a?topic%5fid=592&topic=Finnegan%3a%20Wake%2dup%20Call%20System">the Finnegan bboard</a>
if you're interested in seeing it added.
END_FAQITEM
),

	array("Why won't it let me set a wake-up call at a particular time?", <<<END_FAQITEM
Finnegan operates off of a computer with a limited number of modems and phone lines.  A modem can only make 
one call at a time.  In order to prevent wake-up calls from being unable to go out due to too many
phone lines being in use, Finnegan is very conservative as to how many wake-up calls it will let be
scheduled for the same time.  Furthermore, because of the "snooze button", setting a wake-up call
takes up a potential phone line not just for the time of the call, but for several lengths of time
after the call.  The four different types of wake-up calls (one-time wake-up calls, and three different
calendars for recurring wake-up calls) add additional complications, since recurring calls that take
place on a Monday on the Brandeis calendar will sometimes be on a Monday on the other calendars,
and will sometimes be on other days (when there's a Brandeis Monday in effect.
END_FAQITEM
),

	array("How does Finnegan know when there's a holiday, no classes, or a Brandeis Monday?", <<<END_FAQITEM
The Finnegan team enters the data by hand,
taking the Brandeis calendar information from <a href="http://www.brandeis.edu/registrar/cal.html">the registrar's website</a>.
END_FAQITEM
),

	array("What security features does Finnegan have?", <<<END_FAQITEM
Finnegan performs extensive logging whenever any action is performed, so if the system is abused, the tools
to track down the responsible parties are in place.  Finnegan will not allow wake-up calls to be set for
certain critical extensions, such as the Public Safety emergency number.  If Finnegan sees that too many
invalid PINs are being entered in a short period of time, it will temporarily prevent the extension and/or
person entering the invalid PINs from accessing the system.
END_FAQITEM
),

	array("Can I get a copy of the Finnegan source code?", <<<END_FAQITEM
Yes, the Finnegan source is available under <a href="COPYING.txt">version 2 of the GNU General Public License</a>.
Our CVS repository can be accessed as follows:
<blockquote>
<tt>cvs -d :pserver:anonymous@zevils.com:/home/cvs login</tt> (password is 'cvs')<br />
<tt>cvs -z3 -d :pserver:anonymous@zevils.com:/home/cvs co finnegan</tt>
</blockquote>
You can also <a href="http://www.zevils.com/cgi-bin/viewcvs.cgi/finnegan/">browse the repository</a>.
END_FAQITEM
),

	array("Who can I contact regarding questions/comments/suggestions/complaints pertaining to Finnegan?", <<<END_FAQITEM
You can post a message to <a href="http://my.brandeis.edu/bboard/q-and-a?topic%5fid=592&topic=Finnegan%3a%20Wake%2dup%20Call%20System">the Finnegan bboard</a>
or email <a href="mailto:finnegan@brandeis.edu">finnegan@brandeis.edu</a> .
END_FAQITEM
));

require "finnegan-config.inc";
require "template.inc";

echo $TEMPLATE["page_start"];

echo $TEMPLATE["docs_start"];

echo $TEMPLATE["docs_index_start"];
for($i = 0; $i < sizeof($faqs); $i++)
	echo preg_replace(array("/__NAME__/", "/__NUM__/"), array($faqs[$i][0], $i+1), $TEMPLATE["docs_index_entry"]);
echo $TEMPLATE["docs_index_end"];

echo $TEMPLATE["docs_body_start"];
for($i = 0; $i < sizeof($faqs); $i++)
	echo preg_replace(array("/__NAME__/", "/__CONTENTS__/", "/__NUM__/"), array($faqs[$i][0], $faqs[$i][1], $i+1), $TEMPLATE["docs_body_entry"]);
echo $TEMPLATE["docs_body_end"];


echo $TEMPLATE["docs_end"];
echo $TEMPLATE["page_end"];
?>
