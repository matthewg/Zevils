$(document).ready(function() {
    $(".metoo_flag").click(function() {
        var messageID = $("../../..").attr("id").replace(/^metoo_post_flags_/, "");
        var removeFlags = new Array();
        var addFlags = new Array();

        if($(this).has_class("metoo_flag_selected")) {
            $(this).removeClass("metoo_flag_selected");
            $(this).addClass("metoo_flag_unselected");
            removeFlags.push($(".metoo_flag_name").text());
        } else {
            $("../.metoo_flag").each(function() {
                $(this).removeClass("metoo_flag_selected");
                removeFlags.push($(".metoo_flag_name").text());
            });
            $(this).addClass("metoo_flag_selected");
            addFlags.push($(".metoo_flag_name").text());
        }

        $.ajax({
            type: "POST",
            url: phorum_get_url(PHORUM_CUSTOM_URL, "metoo_save_flags.php", 0),
            data: "messageID=" + messageID + "&addFlags=&" + addFlags.join(",") + "removeFlags=" + removeFlags.join(","),
            success: function(msg) {},
            error: function(msg) {
                alert("Couldn't save post flags!");
            }
        });
    });
});