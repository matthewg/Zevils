<?php

$wgExtensionCredits['other'][] = array(
                                   'name' => 'HTTPChallenge',
                                   'author' => 'Matthew Sachs',
                                   'url' => 'http://zevils.com/',
                                   'description' => 'Sends HTTP authentication challenge'
                                   );
$wgHooks['AutoAuthenticate'][] = 'fnHTTPChallenge';

function fnHTTPChallenge(&$user) {
    global $wgSiteName;
    
    wfSetupSession();

    if(!isset($_REQUEST["auth"])) return true;

    if(!isset($_SERVER['PHP_AUTH_USER'])) {
        header('WWW-Authenticate: Basic realm="'.$wgSiteName.'"');
        header('HTTP/1.1 401 Unauthorized');
        die("Please log in, " . $_SERVER['PHP_AUTH_USER'] . "/" . $_SERVER['PHP_AUTH_PW']);
    }

    global $wgContLang;
    $name = $wgContLang->ucfirst($_SERVER['PHP_AUTH_USER']);
    $t = Title::newFromText($name);
    if(is_null($t)) return null;

    global $wgAuth;
    $canonicalName = $wgAuth->getCanonicalName($t->getText());
    if(!User::isValidUserName($canonicalName)) return null;

    $u = User::newFromName($canonicalName);
    if(0 == $u->getID()) return null;
    if(!$u->checkPassword($_SERVER['PHP_AUTH_PW'])) return null;
    $user = $u;
    $user->setCookies();
    
    return true;
}

?>
