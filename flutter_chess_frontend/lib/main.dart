import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart';

// Einstiegspunkt der App
void main() {
  runApp(ChessApp());
}

// Haupt-Widget der App (StatefulWidget, da sich der Zustand ändert)
class ChessApp extends StatefulWidget {
  @override
  _ChessAppState createState() => _ChessAppState();
}

// State-Klasse für ChessApp
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
  final String backendUrl = "http://localhost:8000"; 

  @override
  void initState() {
    super.initState();
    // Starte ein neues Spiel beim Start der App (Skill-Level 5)
    newGame(10);
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

  // Startet ein neues Spiel mit gewünschtem Schwierigkeitsgrad
  Future<void> newGame(skillLevel) async {
    try {
      final response = await http.post(Uri.parse("$backendUrl/new"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"skillLevel": skillLevel}),);

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

  // Baut das UI der App auf
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Schach Flutter",
      home: Scaffold(
        appBar: AppBar(
          title: Text("Schach"),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Zeigt Statusmeldungen an
              Text(statusMessage),
              SizedBox(height: 20),
              // Das Schachbrett mit fester Höhe
              Container(
                child: buildResponsiveBoard(fen),            
              ),
              SizedBox(height: 20),
              // Verschiedene Buttons für neue Spiele mit unterschiedlichen Schwierigkeitsgraden
              ElevatedButton(
                onPressed: () async { await newGame(5); },
                child: Text("Spiel starten Easy"),
              ),
              ElevatedButton(
                onPressed: () async { await newGame(10); },
                child: Text("Spiel starten Mid"),
              ),
              ElevatedButton(
                onPressed: () async { await newGame(15); },
                child: Text("Spiel starten Hard"),
              ),
              ElevatedButton(
                onPressed: () async { await newGame(20); },
                child: Text("Spiel starten Very Hard"),
              ),
              SizedBox(height: 10),
              // Textfeld für Zug-Eingabe (z.B. "e2e4")
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
                },
              ),
              SizedBox(height: 10),
              // Button zum Senden des Zuges
              ElevatedButton(
                onPressed: () {
                  final move = moveController.text.trim();
                  if (move.isNotEmpty) {
                    makeMove(move);
                    moveController.clear();
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

  // Responsive Schachbrett (passt sich der Bildschirmgröße an)
  Widget buildResponsiveBoard(String fen) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rawSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth * 0.9
            : constraints.maxHeight * 0.9;

        final size = rawSize.clamp(200.0, 400.0); // min 200, max 400 px
        final squareSize = size / 10;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: buildBoardWithSize(fen, squareSize),
          ),
        );
      },
    );
  }

  // Baut das Schachbrett mit Beschriftungen und Drag & Drop
  Widget buildBoardWithSize(String fen, double squareSize) {
    final board = parseFEN(fen); // Wandelt FEN in 2D-Array um
    const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

    return Column(
      children: [
        // Spaltenbeschriftung oben
        Row(
          children: [
            SizedBox(width: squareSize),
            for (final l in letters)
              SizedBox(
                width: squareSize,
                height: squareSize,
                child: Center(child: Text(l)),
              ),
            SizedBox(width: squareSize),
          ],
        ),
        // Das eigentliche Brett (8x8 Felder)
        for (int row = 0; row < 8; row++)
          Row(
            children: [
              // Reihennummern links
              SizedBox(
                width: squareSize,
                height: squareSize,
                child: Center(child: Text('${8 - row}')),
              ),
              for (int col = 0; col < 8; col++)
                DragTarget<Map<String, dynamic>>(
                  onWillAccept: (data) => true,
                  onAccept: (data) {
                    final from = data['from'];
                    // Erzeuge UCI-Zugnotation, z.B. "e2e4"
                    final move =
                        "${String.fromCharCode(from['col'] + 97)}${8 - from['row']}"
                        "${String.fromCharCode(col + 97)}${8 - row}";
                    makeMove(move);
                  },
                  builder: (context, candidateData, rejectedData) {
                    final piece = board[row][col];
                    final isLight = (row + col) % 2 == 0;

                    // Wenn Figur vorhanden, mache sie draggable
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
                                style: TextStyle(fontSize: squareSize * 0.6),
                              ),
                            ),
                            childWhenDragging: Container(),
                            child: Center(
                              child: Text(
                                pieceSymbols[piece] ?? '',
                                style: TextStyle(fontSize: squareSize * 0.6),
                              ),
                            ),
                          )
                        : null;

                    return Container(
                      width: squareSize,
                      height: squareSize,
                      decoration: BoxDecoration(
                        color:
                            isLight ? Colors.brown[200] : Colors.brown[700],
                        border: Border.all(color: Colors.black12),
                      ),
                      child: pieceWidget ?? const SizedBox.shrink(),
                    );
                  },
                ),
              // Reihennummern rechts
              SizedBox(
                width: squareSize,
                height: squareSize,
                child: Center(child: Text('${8 - row}')),
              ),
            ],
          ),
        // Spaltenbeschriftung unten
        Row(
          children: [
            SizedBox(width: squareSize),
            for (final l in letters)
              SizedBox(
                width: squareSize,
                height: squareSize,
                child: Center(child: Text(l)),
              ),
            SizedBox(width: squareSize),
          ],
        ),
      ],
    );
  }
}