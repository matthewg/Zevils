<?php

$wgExtensionCredits['other'][] = array(
                                       'name' => 'NamespaceLocalLinks',
                                       'url' => 'http://mediawiki.org/Extension:NamespaceLocalLinks',
                                       'description' => 'foo',
                                       'author' => '[mailto:matthewg@zevils.com Matthew Sachs]',
);

$wgExtensionFunctions[] = 'efNamespaceLocalLinks';

function efNamespaceLocalLinks() {
    global $wgHooks;

    $wgHooks['InternalParseBeforeLinks'][] = 'namespaceLocalLinkMunge';
    return true;
}

function makeReplacementText($matches) {
    global $wgArticle;
    if($wgArticle and $wgArticle->mTitle) {
        $namespace = $wgArticle->mTitle->getNsText();

        $linkTitle = $matches[1];
        $linkText = $matches[2];
        if($linkText == "") $linkText = "|$linkTitle";
        return "[[$namespace:$linkTitle$linkText]]";
    } else {
        return $matches[0];
    }
}

function namespaceLocalLinkMunge(&$parser, &$text) {
    global $action;
    global $wgArticle;
    global $wgLogo;

    if($wgArticle) {
        $namespace = $wgArticle->mTitle->getNamespace();
        if($namespace == 101) {
            $wgLogo = "http://zevils.com/misc/ranger.jpg";
        } elseif($namespace == 102) {
            $wgLogo = "http://zevils.com/misc/wed-banner.jpg";
        } elseif($namespace == 103) {
            $wgLogo = "http://zevils.com/misc/condo.jpg";
        }
    }

    
    #if($action != "view") return true;
    #$title = $parser->getTitle();
    #$article = new Article($title);
    #$xtext = preg_replace("/\x7FUNIQ[-a-h0-9]+QINU\x7F/", "", $text);
    #if($article->getContent() != $xtext) return true;

    #print "}}}}}}}}}}}}}}}\n";
    #print "Action: $action\n";
    #if($article->getContent() == $xtext)
    #   print "Article == xtext!\n";
    #print "---------articleContent-----\n";
    #print $article->getContent();
    #print "---------text------\n";
    #print $text;
    #print "---------xtext-----\n";
    #print $xtext;
    $text = preg_replace_callback("/\\[\\[([^:|]+?)(\\|.+?)?\\]\\]/",
                                  'makeReplacementText',
                                  $text);
    #print "---------munged-----\n";
    #print $text;
    #print "{{{{{{{{{{{{{{\n";
    #printf("Title (%s // %s): %s / %s -> %s\n", $title->mDbkeyform, $url,
    #       $title->mDefaultNamespace,
    #       $title->mNamespace, $wgArticle->mTitle->getNamespace());
    #$title->mDefaultNamespace = $wgArticle->mTitle->getNamespace();
    return true;
}
    
?>
