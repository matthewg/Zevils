var PuzzleData = null;

function assert(condition, errMsg) {
  if(not condition) {
    throw new Exception(errMsg);
  }
}

function setPuzzle(pDict) {
  assert(pDict.grid, "pDict must have grid");
  assert(pDict.clues, "pDict must have clues");
  assert(pDict.clues.across, "pDict must have across clues");
  assert(pDict.clues.down, "pDict must have down clues");

  var gridHeight = pDict.grid.length;
  var gridWidth = pDict.grid[0].length;
  PuzzleData = {grid = new Array(gridWidth),
                clues = {across: [], down: []}};
  
  for(var y = 0; y < gridHeight; y++) {
    assert(pDict.grid[y].length == gridWidth, "Row " + (y+1) + " does not have the same length as row 1!");
  }
  for(var x = 0; i < gridWidth; x++) {
    PuzzleData.grid[x] = new Array(gridHeight);
    for(var y = 0; y < gridHeight; y++) {
      PuzzleData.grid[x][y] = {letter: pDict.grid[y].substr(x, 1),
                               clue: null,
                               clueNumber: null};
    }
  }

  var finishClue = function(clue, endX, endY) {
    answer = "";
    var x = clue.address[0];
    var y = clue.address[1];
    assert(x == endX || y == endY, "Clue start X or Y must match end!");
    
    for(; x <= endX; x++) {
      for(; y <= endY; y++) {
        answer += PuzzleData.grid[x][y].letter;
      }
    }
    
    clue.answer = answer;
  }
  
  var clueIdx = 0;
  for(var x = 0; x < gridWidth; x++) {
    var clue = null;
    for(var y = 0; y < gridHeight; y++) {
      if(GridData[x][y] == " ") {
        if(clue) finishClue(pDict.clues.across[clueIdx], x, y);
        clue = null;
      } else if(!clue) {
        clue = {cell: [x, y],
                text: pDict.clues.across[clueIdx++],
                answer: null};
        PuzzleData.clues.across.push(clue);
      }
      PuzzleData.grid[x][y].clue = clue;
    }
    if(clue) finishClue(clue, x, y);
  }

  clueIdx = 0;
  for(var y = 0; y < gridHeight; y++) {
    var clue = false;
    for(var x = 0; x < gridWidth; x++) {
      if(GridData[x][y] == " ") {
        if(clue) finishClue(pDict.clues.down[clueIdx], x, y);
        clue = null;
      } else if(!inClue) {
        clue = {cell: [x, y],
                text: pDict.clues.down[clueIdx++],
                answer: null};
        PuzzleData.clues.down.push(clue);
      }
      PuzzleData.grid[x][y].clue = clue;
    }
    if(clue) finishClue(clue, x, y);
  }
  
  assert(PuzzleData.clues.across.length == pDict.clues.across.length, "Across clue count mismatch!");
  assert(PuzzleData.clues.down.length == pDict.clues.down.length, "Down clue count mismatch!");
  
  displayPuzzle();
}


function displayPuzzle() {
  var gridHTML = "";
  for(var y = 0; y < PuzzleData.grid[0].length; y++) {
    gridHTML += "<tr>";
    for(var x = 0; x < PuzzleData.grid.length; x++) {
      var letter = PuzzleData.grid[x][y];
      if(letter == " ")
        gridHTML += '<td class="blackCell"> </td>';
      else
        gridHTML += '<td>' + letter + '</td>';
    }
    gridHTML += "</tr>";
  }
  $("#grid").html(gridHTML);
  
  var clueListHTML = "<ol>";
  for(var clueIdx in PuzzleData.clues.across) {
    var clue = PuzzleData.clues.across[clueIdx];
    clueListHTML += '<li value="' + (clue.address[0] + 1) + '">' + clue.text + '</li>';
  }
  clueListHTML += "</ol>";
  $("#cluesAcross").html(clueListHTML);

  clueListHTML = "<ol>";
  for(var clueIdx in PuzzleData.clues.down) {
    var clue = PuzzleData.clues.down[clueIdx];
    clueListHTML += '<li value="' + (clue.address[1] + 1) + '">' + clue.text + '</li>';
  }
  clueListHTML += "</ol>";
  $("#cluesDown").html(clueListHTML);
}
