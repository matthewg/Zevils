var DB = null;
var SAVED_ROLLS = [];

function initSavedRolls() {
    if(!DB) return;

    DB.transaction(function(tx) {
        tx.executeSql("SELECT * FROM saved_rolls", [], function(tx, rs) {
            for(var i = 0; i < rs.rows.length; i++) {
                var row = rs.rows.item(i);
                SAVED_ROLLS[row['name']] = [row['bonus'], row['pool']];
            }
            updatedSavedRolls();
            initRollHistory();
        }, function(tx, error) {
            tx.executeSql("CREATE TABLE saved_rolls(name VARCHAR NOT NULL PRIMARY KEY, bonus INT NOT NULL, pool INT NOT NULL)");
            updatedSavedRolls();
            initRollHistory();
        });
    });
}

function initRollHistory() {
    DB.transaction(function(tx) {
        tx.executeSql("SELECT * FROM roll_history ORDER BY seq DESC LIMIT 50",
                      [],
                      function(tx, rs) {
                          var delSeq = null;
                          for(var i = 0; i < rs.rows.length; i++) {
                              var row = rs.rows.item(i);
                              $("#rolls").append(row['text']);
                              delSeq = parseInt(row['seq']);
                          }
                          tx.executeSql("DELETE FROM roll_history WHERE seq < ?", [delSeq]);
                          finishedInit();
                      },
                      function(tx, error) {
                          tx.executeSql("CREATE TABLE roll_history(seq INTEGER PRIMARY KEY AUTOINCREMENT, text VARCHAR)");
                          finishedInit();
                      });
    });
}

function finishedInit() {
    $("#roll").attr("enabled", true);
}


function updatedSavedRolls() {
    $("#loadroll").empty();
    $("#loadroll").append("<option value=''>Edit saved roll...</option>");
    $("#savedlist").empty();

    var keys = [];
    for(var key in SAVED_ROLLS) {
        keys.push(key);
    }

    keys.sort();
    for(var i = 0; i < keys.length; i++) {
        var key = keys[i];
        var roll = SAVED_ROLLS[key];
        var str = key + ": " + roll[0] + "P" + roll[1];

        var loadOption = $("<option>" + str + "</option>");
        loadOption.attr("value", key);
        $("#loadroll").append(loadOption);

        var doRoll = $("<a href=\"#\">" + str + "</a>");
        doRoll.click(function(event) {
            $("#bonus").val(roll[0]);
            $("#pool").val(roll[1]);
            $("#savename").val("");
            $("#roll").click();
            event.preventDefault();
        });
        var li = $("<li>");
        li.append(doRoll);
        $("#savedlist").append(li);
    }
}

function loadSavedRoll(event) {
    var loadName = $(this).val();
    if(loadName) {
        var roll = SAVED_ROLLS[loadName];
        $("#bonus").val(roll[0]);
        $("#pool").val(roll[1]);
        $("#savename").val(loadName);
        $(this).val("");
        event.preventDefault();
    }
}


function clickedRoll(event) {
    event.preventDefault();

    var bonus = parseInt($("#bonus").val());
    var pool = parseInt($("#pool").val());
    var comment = $("#comment").val();
    var savename = $("#savename").val();

    if(savename && !bonus && !pool) {
        delete SAVED_ROLLS[savename];
        updatedSavedRolls();
        if(DB) {
            DB.transaction(function(tx) {
                tx.executeSql("DELETE FROM saved_rolls WHERE name = ?", [savename]);
            });
        }
    } else {
        if(isNaN(bonus)) {
            alert("Invalid bonus!");
            return;
        }
        if(isNaN(pool)) {
            alert("Invalid pool!");
            return;
        }

        var pool_left = pool;
        var total = bonus;
        var rolls = [];
        while(pool_left > 0) {
            var val = Math.floor(Math.random() * 8) + 1;
            if(val != 8) pool_left--;
            total += val;
            rolls.push(val);
        }

        if(comment) {
            comment = " (" + comment + ")";
        }
        var str = "<p><b>" + total + "</b>" + comment + " [" + rolls.join(" ") + "]</p>";
        $("#rolls").prepend(str);
        $("#comment").val("");
        $("#savename").val("");

        if(savename) {
            SAVED_ROLLS[savename] = [bonus, pool];
            updatedSavedRolls();
        }
        if(DB) {
            DB.transaction(function(tx) {
                tx.executeSql("INSERT INTO roll_history (text) VALUES (?)",
                              [str]);
                if(savename) {
                    tx.executeSql("INSERT INTO saved_rolls (name, bonus, pool) VALUES (?, ?, ?)",
                                  [savename, bonus, pool]);
                }
            });
        }
    }
}


$(document).ready(function() {
    $("#loadroll").change(loadSavedRoll);
    $("#roll").click(clickedRoll);

    if(!window.openDatabase) {
        alert("Database functionality not supported; saving not available.");
    } else {
        $("#roll").attr("enabled", false);
        try {
            DB = openDatabase("DiceOfAya", "1.0", "Dice of Aya", 500000);
            if(!DB) {
                alert("Couldn't open database; saving not available.");
                finishedInit();
                return;
            }
        } catch(err) {
            DB = null;
            alert("Database error: " + err + "; saving not available.");
            finishedInit();
            return;
        }
        initSavedRolls();
    }
});
