function fireClick(element) {
    var evt = document.createEvent('MouseEvents');
    var i;
    var len;
    evt.initMouseEvent("click",
                       true,
                       true,
                       window, 0, 0, 0, 0, 0,
                       false, false, false, false, 0, null);
    element.dispatchEvent(evt);
}

// Find and number exits.
var exits = [];
var links = document.getElementById("exits").querySelectorAll("a");
for(var i = 0; i < links.length; i++) {
    var link = links[i];
    if(link.href.match(/.*mm_exit[.]php.*/)) {
        exits.push(link);
        link.textContent = exits.length + ". " + link.textContent;
    }
}

var commandline = document.getElementById("ta");
function clInput(e) {
    // If enter was pressed...
    if(e.keyCode == 13) {
        var text = commandline.value;
        var matches = text.match(/^(\S+)\s+(\S.*)$/);
        if(matches) {
            var command = matches[1].toLowerCase();
            var value = matches[2];
            if(command == "go") {
                e.preventDefault();
                value = parseInt(value);
                if(isNaN(value) || (value > exits.length) || (value < 1)) {
                    alert("Invalid value.");
                    return;
                }

                fireClick(exits[value - 1]);
                return;
            }

            var actions = document.getElementById("actions").getElementsByTagName("a");
            for(var i = 0; i < actions.length; i++) {
                var action = actions[i];
                if(action.textContent.toLowerCase() == command) {
                    e.preventDefault();
                    commandline.value = value;
                    fireClick(action);
                    break;
                }
            }
        }
    }
}
if(commandline) {
    commandline.addEventListener("keypress", clInput, false);
}
