$(document).ready(function(){
	$("#filters input").click(function(){
		alert($(this).attr("label") + " - " + $(this).attr("checked"));
	});
});
