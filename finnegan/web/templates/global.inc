<?
//See template-spec.txt for documentation.

function errmsg($msg) { return "<p class=\"error\">$msg  Check <a href=\"docs.php\">the Finnegan documentation</a> or <a href=\"mailto:finnegan@brandeis.edu\">email finnegan@brandeis.edu</a> for assistance.</p>\n"; }

$TEMPLATE = array();

$TEMPLATE["global"] = array(
	"start" => <<<END
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>Finnegan: __PAGE_TITLE__</title>
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
<div id="top">__LOGGED_IN__ &bull; System Time: <strong>__TIME__</strong></div>
<div id="left"><a href="/"><img src="img/wallphone.png" alt="Wall Phone" width="90" height="265" border="0" /></a></div>
<div id="right"> 
  <div class="title">
  <!-- <img src="img/6wake.png" alt="x6WAKE" width="138" height="23" style="padding-bottom: 8px" /> -->
  <img src="img/tagline.png" alt="Finnegan Wake-up Call Service" width="287" height="20" style="padding-top: 8px" />
  <hr class="top" />
  <!-- <img src="img/tagline.png" alt="Finnegan Wake-up Call Service" width="287" height="20" style="padding-top: 8px" /> -->
  </div>
  <div id="main">
  <div id="navigation">
	__NAV_MENU__
  </div>
  <h3>__PAGE_TITLE__</h3>
END
,

	"logged_in" => "Logged in as x<strong>__EXTENSION__</strong>",
	"not_logged_in" => "Not logged in",
	"nav_menu_item_current" => "<li><strong>__TEXT__</strong></li>",
	"nav_menu_item" => "<li><a href=\"__URL__\">__TEXT__</a></li>",


	"end" => <<<END
	</div>
</div>
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
	$TEMPLATE["global"]["start"] .= <<<END
<h1 style="color: #FF0000">TESTING TESTING TESTING TESTING - Development Server</h1>
<p class="status"><big>Finnegan is still under active development.  Please have patience while we
finish writing and testing the system.  In particular, our capacity is currently very limited.
In particular, if you try to set a wake-up call and get a message that no phone lines are available,
we are aware of the problem.  For announcements about the service, or if you have anything you'd like to
say about it, visit <a href="http://my.brandeis.edu/bboard/q-and-a?topic%5fid=592">the Finnegan bboard</a>.</big></p>
END
;

}
if($FinneganConfig->nocalls) {
	$TEMPLATE["global"]["start"] .= '<h1 style="color: #FF0000">No phone calls will be made.</h1>';
} else if($FinneganConfig->testmode) {
	$TEMPLATE["global"]["start"] .= '<h1 style="color: #FF0000">Phone calls will be made!</h1>';
}

?>
