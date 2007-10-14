<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title><?php
  	$pagetitle = wp_title('&raquo;', false);
  	$pagetitle = preg_replace("/^ &raquo; /", "", $pagetitle);
  	if($pagetitle) {
  		if(is_single()) {
  		
  			$arctitle = " Archives";
  		} else {
  			$arctitle = "";
  		}
  		echo "$pagetitle (";
  		bloginfo('name');
  		echo "$arctitle)";
  	} else {
  		bloginfo('name');
  	}
  ?></title>
  <meta name="viewport" content="width=700, initial-scale=0.45, minimum-scale=0.45">

  <link rel="stylesheet" href="<?php bloginfo('stylesheet_url'); ?>" type="text/css" media="screen" />
  <link rel="alternate" type="application/rss+xml" title="<?php bloginfo('name'); ?> RSS Feed" href="<?php bloginfo('rss2_url'); ?>" />
  <link rel="pingback" href="<?php bloginfo('pingback_url'); ?>" />

<?php wp_head(); ?>
</head>
<body>
<div id="page">


<div id="header">
	<div id="headerimg">
          <a href="<?php echo get_option('home'); ?>"><img src="<?php bloginfo('template_directory')?>/images/header-img.png" alt="Zevils: More fun than a gallon of strawberries." width="435" height="45"></a>
	</div>
</div>
<hr />
