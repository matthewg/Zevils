<?
//See template-spec.txt for documentation.

function errmsg($msg) { return "<p class=\"error\">$msg  Check <a href=\"docs.php\">the Finnegan documentation</a> or <a href=\"mailto:finnegan@brandeis.edu\">email finnegan@brandeis.edu</a> for assistance.</p>\n"; }

$TEMPLATE = array();

$TEMPLATE["global"] = array(
	"start" => <<<END
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">
<html>
<head>
<title>__PAGE_TITLE__</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
<style type="text/css" media="screen">
	@import url(finnegan.css);
</style>
<script type="text/javascript">
// <!-- 
var browser = "";
if(!document.all && document.getElementById) { //Netscape 6 / Mozilla
	browser = "mozilla";
} else if (document.all) { //IS IE 4 or 5 (or 6 beta)
	browser = "ie";
} else if (document.layers) { //IS NETSCAPE 4 or below
	browser = "netscape";
}

function getobj(objname) {
	if(browser == "mozilla") {
		return document.getElementById(objname);
	} else if(browser == "ie") {
		var theobj;
		eval("theobj = document.all." + objname);
		return theobj;
	} else if(browser == "netscape") {
		return document.layers[objname];
	}
	return null;
}

function getobjstyle(obj) {
	if(browser != "netscape") {
		return obj.style;
	} else {
		return obj;
	}
}

function showhide(objname, state) { getobjstyle(getobj(objname)).display = state; }
function show(objname) { showhide(objname, "block"); }
function hide(objname) { showhide(objname, "none"); }

__PAGE_SCRIPT__

// -->
</script>
</head>
<body>
<h1>Finnegan</h1>
<h2>Brandeis wake-up calls, sponsored by the Student Union and the Computer Operators Group</h2>
END
,

	"end" => <<<END
<p><small>(c)2004 <a href="http://www.zevils.com/">Matthew Sachs</a> and <a href="http://union.brandeis.edu/">the Brandeis Student Union</a>.  <a href="legal.php">Legal Information</a></small></p>
</body>
</html>
END
,

	"db_error" => errmsg("There was a problem with the database: <tt>__ERROR__</tt>. Please try again later.  If the problem persists, please report it to <a href=\"mailto:finnegan@brandeis.edu\">finnegan@brandeis.edu</a>."),
	"date_error" => errmsg("There was a problem with a date or time: '<tt>__DATE__</tt>'. Please try again later.  If the problem persists, please report it to <a href=\"mailto:finnegan@brandeis.edu\">finnegan@brandeis.edu</a>."),
	"lock_error" => errmsg("There was a problem obtaining a lock in order to check for valid wake-up call times. Please try again later.  If the problem persists, please report it to <a href=\"mailto:finnegan@brandeis.edu\">finnegan@brandeis.edu</a>."),
	"pin_bruteforce_warn" => errmsg("You have been entering too many incorrect PINs.  If you enter another incorrect PIN, you will be temporarily locked out of the system."),
);

if($FinneganConfig->testmode) {
	$TEMPLATE["global"]["start"] .= '<h1 style="color: #FF0000">TESTING TESTING TESTING TESTING - Development Server';
}
if($FinneganConfig->nocalls) {
	$TEMPLATE["global"]["start"] .= '<h1 style="color: #FF0000">No phone calls will be made.</h1>';
} else if($FinneganConfig->testmode) {
	$TEMPLATE["global"]["start"] .= '<h1 style="color: #FF0000">Phone calls will be made!</h1>';
}

?>
