import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart';

// Einstiegspunkt der App
void main() {
  runApp(ChessApp());
}

// Haupt-Widget der App
class ChessApp extends StatefulWidget {
  @override
  _ChessAppState createState() => _ChessAppState();
}



class _ChessAppState extends State<ChessApp> {
  // Aktueller Spielstand im FEN-Format
  String fen = "";
  // Wer ist am Zug ("white" oder "black")
  String turn = "";
  // Statusmeldung für den Nutzer
  String statusMessage = "Lade Spielstand...";
  // Controller für das Textfeld zur Eingabe von Zügen
  TextEditingController moveController = TextEditingController();

  // Für Drag & Drop (aktuell nicht genutzt)
  String? selectedPiece;
  int? selectedFromRow;
  int? selectedFromCol;

  // URL zum Backend (Flask-Server)
  final String backendUrl = "http://localhost:5000"; 

  @override
  void initState() {
    super.initState();
    loadBoard(); // Beim Start das Brett laden
  }



  // Holt das aktuelle Brett vom Backend
  Future<void> loadBoard() async {
    try {
      final response = await http.get(Uri.parse("$backendUrl/board"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          fen = data['fen'];
          turn = data['turn'];
          statusMessage = "Am Zug: $turn";
        });
      } else {
        setState(() {
          statusMessage = "Fehler beim Laden des Brettes";
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = "Fehler: $e";
      });
    }
  }



  // Sendet einen Zug an das Backend
  Future<void> makeMove(String move) async {
    try {
      final response = await http.post(
        Uri.parse("$backendUrl/move"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"move": move}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          fen = data['fen'];
          statusMessage = "Zug erfolgreich: $move";
        });
      } else {
        final data = json.decode(response.body);
        setState(() {
          statusMessage = "Fehler: ${data['status']}";
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = "Fehler: $e";
      });
    }
  }



  // Startet ein neues Spiel
  Future<void> newGame() async {
    try {
      final response = await http.post(Uri.parse("$backendUrl/new"));
      if (response.statusCode == 200) {
        setState(() {
          statusMessage = "Neues Spiel gestartet";
        });
        await loadBoard();
      } else {
        setState(() {
          statusMessage = "Fehler beim Neustart";
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = "Fehler: $e";
      });
    }
  }



  // Baut das UI der App
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Schach Flutter",
      home: Scaffold(
        appBar: AppBar(
          title: Text("Schach Flutter + Flask"),
        ),
        body: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Zeigt Statusmeldungen an
              Text(statusMessage),
              SizedBox(height: 20),
              // Das Schachbrett
              Expanded(
                child: buildBoard(fen),
              ),
              SizedBox(height: 20),
              // Button für neues Spiel
              ElevatedButton(
                onPressed: newGame,
                child: Text("Neues Spiel starten"),
              ),
              // Textfeld für manuelle Zug-Eingabe
              TextField(
                controller: moveController,
                decoration: InputDecoration(
                  labelText: "Zug eingeben",
                  border: OutlineInputBorder(),
                ),              
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    makeMove(value.trim());
                    moveController.clear(); 
                  }
                }
              ),
              SizedBox(height: 10),
              // Button zum Senden des Zuges
              ElevatedButton(
                onPressed: () {
                  final move = moveController.text.trim();
                  if (move.isNotEmpty) {
                    makeMove(move);
                    moveController.clear(); // Eingabe zurücksetzen
                  }
                },
                child: Text("Zug senden"),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // Baut das Schachbrett-Widget
  Widget buildBoard(String fen) {
    final board = parseFEN(fen); // Wandelt FEN in 2D-Array um
    const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']; // Spaltenbeschriftung

    return AspectRatio(
      aspectRatio: 1, // Quadrat
      child: Column(
        children: [
          // Spaltenbeschriftung oben
          Row(
            children: [
              SizedBox(width: 20),
              for (final l in letters)
                Expanded(child: Center(child: Text(l))),
              SizedBox(width: 20),
            ],
          ),
          Expanded(
            child: Row(
              children: [
                // Reihennummern links
                Column(
                  children: List.generate(8, (i) {
                    return Expanded(child: Center(child: Text("${8 - i}")));
                  }),
                ),
                // Das eigentliche Schachbrett
                Expanded(
                  child: GridView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: 64,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                    itemBuilder: (context, index) {
                      final row = index ~/ 8;
                      final col = index % 8;
                      final piece = board[row][col];
                      final isLight = (row + col) % 2 == 0;

                      // DragTarget für Drag & Drop von Figuren
                      return DragTarget<Map<String, dynamic>>(
                        onWillAccept: (data) => true,
                        onAccept: (data) {
                          // Berechnet den Zug im UCI-Format, z.B. e2e4
                          final from = data['from'];
                          final move = "${String.fromCharCode(from['col'] + 97)}${8 - from['row']}"
                                       "${String.fromCharCode(col + 97)}${8 - row}";
                          makeMove(move); 
                        },
                        builder: (context, candidateData, rejectedData) {
                          // Wenn Figur vorhanden, als Draggable anzeigen
                          final pieceWidget = piece.isNotEmpty
                              ? Draggable<Map<String, dynamic>>(
                                  data: {
                                    'from': {'row': row, 'col': col},
                                    'piece': piece,
                                  },
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: Text(
                                      pieceSymbols[piece] ?? '',
                                      style: TextStyle(fontSize: 24),
                                    ),
                                  ),
                                  childWhenDragging: Container(),
                                  child: Center(
                                    child: Text(
                                      pieceSymbols[piece] ?? '',
                                      style: TextStyle(fontSize: 24),
                                    ),
                                  ),
                                )
                              : null;

                          // Feld mit Farbe und ggf. Figur
                          return Container(
                            decoration: BoxDecoration(
                              color: isLight
                                  ? Colors.brown[200]
                                  : Colors.brown[700],
                              border: Border.all(color: Colors.black12),
                            ),
                            child: pieceWidget ?? const SizedBox.shrink(),
                          );
                        },
                      );
                    },
                  ),
                ),
                // Reihennummern rechts
                Column(
                  children: List.generate(8, (i) {
                    return Expanded(child: Center(child: Text("${8 - i}")));
                  }),
                ),
              ],
            ),
          ),
          // Spaltenbeschriftung unten
          Row(
            children: [
              SizedBox(width: 20),
              for (final l in letters)
                Expanded(child: Center(child: Text(l))),
              SizedBox(width: 20),
            ],
          ),
        ],
      ),
    );
  }
}