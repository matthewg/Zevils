<?

$path = ".";
if(isset($cisco) && $cisco) $path = "../..";

require "$path/include/finnegan-config.inc";
if(isset($cisco) && $cisco) {
	require "$path/include/common-funcs.inc";
	require "$path/include/cisco-funcs.inc";
} else {
	require "$path/templates/global.inc";
	require "$path/templates/".$page.".inc";
	require "$path/include/web-funcs.inc";
	require "$path/include/common-funcs.inc";
}

?>
