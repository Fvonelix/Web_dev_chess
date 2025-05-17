List<List<String>> parseFEN(String fen) {
  final rows = fen.split(" ")[0].split("/");
  return rows.map((row) {
    List<String> result = [];
    for (var char in row.split('')) {
      if (int.tryParse(char) != null) {
        result.addAll(List.filled(int.parse(char), ""));
      } else {
        result.add(char);
      }
    }
    return result;
  }).toList();
}

const Map<String, String> pieceSymbols = {
  'r': '♜',
  'n': '♞',
  'b': '♝',
  'q': '♛',
  'k': '♚',
  'p': '♟',
  'R': '♖',
  'N': '♘',
  'B': '♗',
  'Q': '♕',
  'K': '♔',
  'P': '♙',
};
