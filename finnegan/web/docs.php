<?

$faqs = array(
	array("Who's responsible for Finnegan?", <<<END_FAQITEM
The <a href="http://union.brandeis.edu/">Student Union</a> and <a href="http://www.brancog.org/">Computer Operators Group</a>
have provided the funding and equipment for Finnegan.  The system was developed, and is being maintained by,
<a href="http://www.zevils.com/">Matthew Sachs</a>, with help from <a href="http://people.brandeis.edu/~zeno/">Danny Silverman</a>.
END_FAQITEM
),

	array("Who recorded those fabulous wake-up messages?", <<<END_FAQITEM
"This is your wake-up call" and "WAKE UP!!" were recorded by <a href="http://www.zevils.com/">Matthew Sachs</a>.
"Wake up sleepy-head" and "Up at at 'em" were recorded by Randi Sachs, Matthew's mother.
END_FAQITEM
),

	array("Why is this called 'Finnegan'?", <<<END_FAQITEM
"The name is a play on the title <em>Finnegans Wake</em>, a novel by James Joyce.
You can read about the book at <a href="http://www.everything2.com/index.pl?node_id=65042">Everything2</a> and
<a href="http://www.amazon.com/exec/obidos/ASIN/0141181265">Amazon.com</a>, or check it out from
<a href="http://library.brandeis.edu/">the Brandeis library</a>.
END_FAQITEM
));

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
