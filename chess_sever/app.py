from flask import Flask, jsonify, request
from flask_cors import CORS  # Für Cross-Origin Resource Sharing (Frontend-Backend-Kommunikation)
import chess                  # python-chess Bibliothek für Spiellogik
import chess.svg              # (Optional) Für SVG-Export, hier nicht genutzt
from stockfish import Stockfish  # Für die Anbindung der Stockfish-Engine

app = Flask(__name__)
CORS(app)  # Erlaubt Anfragen von anderen Domains (z.B. Flutter-Frontend)

board = chess.Board()  # Erstellt ein neues Schachbrett (Startposition)
stockfish = Stockfish(
    path=r"C:\Users\duets\Projekts\Web_dev_chess\chess_sever\stockfish\stockfish\stockfish-windows-x86-64-avx2.exe",  # Pfad zur Stockfish-Engine
    parameters={"Threads": 2, "Minimum Thinking Time": 30}  # Engine-Parameter
)

# Gibt das aktuelle Brett als JSON zurück (FEN, Spielstatus, wer am Zug ist)
@app.route("/board", methods=["GET"])
def get_board():
    return jsonify({
        "fen": board.fen(),
        "is_game_over": board.is_game_over(),
        "turn": "white" if board.turn else "black"
    })

# Nimmt einen Zug entgegen, prüft ihn, führt ihn aus und ggf. auch den Stockfish-Zug
@app.route("/move", methods=["POST"])
def make_move():
    global board
    data = request.get_json()         # Holt die gesendeten Daten (JSON)
    move = data.get("move")           # Extrahiert den Zug-String (z.B. "e2e4")
    try:
        chess_move = chess.Move.from_uci(move)   # Wandelt den String in ein Schach-Zug-Objekt um
        if chess_move in board.legal_moves:      # Prüft, ob der Zug erlaubt ist
            board.push(chess_move)               # Führt den Zug aus

            # Wenn jetzt Schwarz am Zug ist und das Spiel nicht vorbei ist:
            if not board.turn and not board.is_game_over():
                stockfish.set_fen_position(board.fen())      # Setzt die Stellung für Stockfish
                best_move = stockfish.get_best_move()        # Holt den besten Zug von Stockfish
                if best_move:
                    board.push(chess.Move.from_uci(best_move))  # Führt den Stockfish-Zug aus

            # Gibt den neuen Spielstand zurück
            return jsonify({"status": "ok", "fen": board.fen()})
        else:
            # Wenn der Zug nicht erlaubt ist
            return jsonify({"status": "illegal move"}), 400
    except Exception as e:
        # Wenn ein Fehler auftritt (z.B. ungültiges Format)
        return jsonify({"status": "invalid move", "error": str(e)}), 400

# Startet ein neues Spiel (setzt das Brett zurück)
@app.route("/new", methods=["POST"])
def new_game():
    global board
    board = chess.Board()  # Neues Spiel starten (Startposition)
    return jsonify({"status": "new game started"})

# Startet den Flask-Server im Debug-Modus
if __name__ == "__main__":
    app.run(debug=True)