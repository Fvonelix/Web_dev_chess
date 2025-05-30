from flask import Flask, jsonify, request
from flask_cors import CORS  # Für Cross-Origin Resource Sharing (Frontend-Backend-Kommunikation)
import chess                  # python-chess Bibliothek für Spiellogik
from stockfish import Stockfish  # Für die Anbindung der Stockfish-Engine
import os

app = Flask(
    __name__,
    static_folder=os.path.join(os.path.dirname(__file__), '..', 'flutter_chess_frontend', 'build', 'web')
)
CORS(app)  # Erlaubt Anfragen von anderen Domains (z.B. Flutter-Frontend)

board = chess.Board()  # Erstellt ein neues Schachbrett (Startposition)


# Startet ein neues Spiel (setzt das Brett zurück)
@app.route("/new", methods=["POST"])
def new_game():
    global board
    global stockfish
    board = chess.Board()  # Neues Spiel starten (Startposition)
    data = request.get_json()
    skill_level = data.get("skillLevel", 10)  # Default = 10
    stockfish_path = os.path.join(os.path.dirname(__file__), "stockfish", "stockfish", "stockfish-windows-x86-64-avx2.exe")
    stockfish = Stockfish(
        path=stockfish_path,
        parameters={"Threads": 2, "Minimum Thinking Time": 30, "Skill Level": skill_level}
    )
    return jsonify({"status": "new game started"})




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
    move = data.get("move")           # Extrahiert den Zug-String 
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



from flask import send_from_directory
import os

@app.route('/')
def serve_index():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/<path:path>')
def serve_static(path):
    return send_from_directory(app.static_folder, path)




# Startet den Flask-Server im Debug-Modus
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)