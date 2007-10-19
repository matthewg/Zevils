$(document).ready(function() {
	var markdown_syntax = $('#markdown_syntax');
	var markdown_syntax_disclosure = $('#markdown_syntax_disclosure > a');

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