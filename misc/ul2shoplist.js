var uls = document.getElementsByTagName("ul");
if(uls && uls.length > 0) {
    var ul = null;
    for(var i = 0; i < uls.length; i++) {
	if(uls[i].childNodes) {
	    for(var j = 0; j < uls[i].childNodes.length; j++) {
		var node = uls[i].childNodes[j];
		if(node.tagName == "LI" && (!node.className || node.className == "")) {
		    ul = uls[i];
		    break;
		}
	    }
	}
	if(ul) break;
    }

    var ulKids = null;
    if(ul) ulKids = ul.childNodes;
    for(var i = 0; i < ulKids.length; i++) {
	var li = ulKids[i];
	if(li.tagName == "LI") {
	    li.setAttribute("originalOrder", i);

	    var checkbox = document.createElement("input");
	    checkbox.setAttribute("type", "checkbox");
	    li.insertBefore(checkbox, li.childNodes[0]);
	    checkbox.onclick = function() {
		var li = this.parentElement;
		var originalOrder = li.getAttribute("originalOrder");

		if(!this.checked) {
		    ul.removeChild(li);
		    var newKids = ul.childNodes;
		    var foundIt = false;
		    var firstNode = null;
		    for(var j = 0; j < newKids.length; j++) {
			var node = newKids[j];
			if(node.tagName == "LI") {
			    if(!firstNode) firstNode = node;
			    var nodeCheck = node.childNodes[0];
			    if(!nodeCheck.checked && node.getAttribute("originalOrder") > originalOrder) {
				ul.insertBefore(li, node);
				foundIt = true;
				break;
			    }
			}
		    }
		    if(!foundIt) {
			if(firstNode) {
			    ul.insertBefore(li, firstNode);
			} else {
			    ul.appendChild(li);
			}
		    }
		} else {
		    ul.removeChild(li);
		    ul.appendChild(li);
		}
	    };
	}
    }
}