<?

eval(preg_replace(array("/#__PERLONLY_START__(.|\\n)*?#__PERLONLY_END__/", "/hash\\(/", "/^\\\$/m"), array("", "array(", "var \$"), implode('', file("$path/../etc/settings.inc"))));
$FinneganConfig = new FinneganConfig();

if($cisco) {
	eval(preg_replace(array("/#__PERLONLY_START__(.|\\n)*?#__PERLONLY_END__/", "/hash\\(/", "/^\\\$/m"), array("", "array(", "var \$"), implode('', file("$path/../etc/cisco-settings.inc"))));
	$FinneganCiscoConfig = new FinneganCiscoConfig();
}

?>
