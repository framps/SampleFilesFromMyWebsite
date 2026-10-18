
/* 
 Small sample java script 

 Accepts any text and returns the scrambled text
 Scramble rule:
 1) Don't scramble a word with less than 4 characters
 2) Keep the first and last character of the word and scramble the rest   
 
 11/29/12 framp at linux-tips-and-tricks dot de
*/

function clearText() {
	document.getElementById("textToScramble").value = ""
		document.getElementById("scrambledText").value = ""
}

function loadText() {
	var language = window.navigator.userLanguage || window.navigator.language;
	
	if (language.toUpperCase().indexOf('DE') >= 0) {
		document.getElementById("textToScramble").value = "Aufgrund einer Studie an einer Englischen Universität ist es egal, in welcher Reihenfolge die Buchstaben in einem Wort stehen, das einzig wichtige dabei ist, dass der erste und letzte Buchstabe am richtigen Platz sind. Der Rest kann totaler Blödsinn sein, und du kannst es trotzdem ohne Probleme lesen. Das geht deshalb, weil wir nicht Buchstabe für Buchstabe einzeln lesen, sondern Wörter als Ganzes. Stimmt's?"
			var dv = document.getElementById("english")
			dv.parentNode.removeChild(dv);
		document.getElementById("sampleButton").innerHTML = "Beispieldaten"
			document.getElementById("scrambleButton").innerHTML = "Mischen"
			document.getElementById("clearButton").innerHTML = "Löschen"
	} else {
		document.getElementById("textToScramble").value = "According to a researcher at Cambridge University, it doesn't matter in what order the letters in a word are, the only important thing is that the first and last letter be at the right place. The rest can be a total mess and you can still read it without problem. This is because the human mind does not read every letter by itself but the word as a whole."
			var dv = document.getElementById("german")
			dv.parentNode.removeChild(dv);
		document.getElementById("sampleButton").innerHTML = "Sample"
			document.getElementById("scrambleButton").innerHTML = "Scramble"
			document.getElementById("clearButton").innerHTML = "Clear"
	}
}

function shuffle(sourceString) {
	
	for (var n = 0; n < sourceString.length - 1; n++) {
		var k = n + Math.floor(Math.random() * (sourceString.length - n));
		
		var temp = sourceString[k];
		sourceString = sourceString.replace(sourceString.charAt(k), sourceString[n]);
		sourceString = sourceString.replace(sourceString.charAt(n), temp);
	}
	return sourceString
}

function scramble(text) {
	
	var invalidChars = /([^a-zA-ZÄäÖöÜüß0-9])/
		var result = ""
		words = text.split(invalidChars)
		
		words = words.filter(function (word) {
			return word != " " && word.length > 0;
		});
	
	for (var i = 0; i < words.length; i++) {
		var word = words[i]
			if (word.length > 3) {
				part = word.substr(1, word.length - 2)
					prefix = result.length > 0 ? " " : ""
					
					result += prefix + word[0] + shuffle(part) + word[word.length - 1]
			} else {
				if (!word.match(invalidChars)) {
					result += ' ' + word
				} else {
					result += word
				}
			}
	}
	
	return result;
}

function displayText() {
	oldText = document.getElementById("textToScramble").value;
	newText = oldText.replace(/ /g, " ")
		newText = scramble(oldText);
	document.getElementById("scrambledText").value = newText;
}