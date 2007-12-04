<? header("Content-type: text/javascript"); ?>

// Pull in a stylesheet via JavaScript
// This hides the elements which will be shown via JQuery.
// We want them to be shown by default for browsers that don't support JS.
// But if we just rely on $(document).ready to show them, we get a nasty FOUC.
var js_css = document.createElement('link');
js_css.rel = 'stylesheet';
js_css.type = 'text/css';
js_css.href = '<?php bloginfo('template_directory')?>/hide_default.css';
document.getElementsByTagName('head')[0].appendChild(js_css);

$(document).ready(function() {
	var markdown_syntax = $('#markdown_syntax');
	var markdown_syntax_disclosure = $('#markdown_syntax_disclosure > a');

        $('#flexo_archives').show();
	markdown_syntax.hide();
	markdown_syntax_disclosure.click(function(){
		if(markdown_syntax.is(':hidden')) {
			markdown_syntax_disclosure.text('Hide Markdown help.');
		} else {
			markdown_syntax_disclosure.text('Show Markdown help.');
		}
		markdown_syntax.toggle('fast');
	});
});
