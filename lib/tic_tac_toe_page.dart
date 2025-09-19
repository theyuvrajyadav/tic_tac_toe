import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class TicTacToePage extends StatefulWidget {
  final SharedPreferences prefs;
  final VoidCallback onToggleTheme;
  final VoidCallback onCycleAccent;
  const TicTacToePage({required this.prefs, required this.onToggleTheme, required this.onCycleAccent, Key? key}) : super(key: key);

  @override
  State<TicTacToePage> createState() => _TicTacToePageState();
}

class _TicTacToePageState extends State<TicTacToePage> {
  final List<String> _board = List.filled(9, '');
  String _currentPlayer = 'X';
  bool _gameOver = false;
  List<int> _winningIndices = [];
  int _scoreX = 0;
  int _scoreO = 0;
  int _draws = 0;
  bool _singlePlayer = false;
  final GlobalKey _boardKey = GlobalKey();

  late ConfettiController _confettiController;

  static const List<List<int>> _winPatterns = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _loadScores();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadScores() async {
    setState(() {
      _scoreX = widget.prefs.getInt('scoreX') ?? 0;
      _scoreO = widget.prefs.getInt('scoreO') ?? 0;
      _draws = widget.prefs.getInt('draws') ?? 0;
    });
  }

  Future<void> _saveScores() async {
    await widget.prefs.setInt('scoreX', _scoreX);
    await widget.prefs.setInt('scoreO', _scoreO);
    await widget.prefs.setInt('draws', _draws);
  }

  void _handleTap(int index) {
    if (_board[index].isNotEmpty || _gameOver) return;

    setState(() {
      _board[index] = _currentPlayer;
      _checkResult();
      if (!_gameOver) {
        _currentPlayer = _currentPlayer == 'X' ? 'O' : 'X';
        if (_singlePlayer && _currentPlayer == 'O') {
          // AI move
          Future.delayed(const Duration(milliseconds: 250), () {
            final move = _bestMove();
            if (move != -1) _handleTap(move);
          });
        }
      }
    });
  }

  void _checkResult() {
    for (var pattern in _winPatterns) {
      final a = pattern[0];
      final b = pattern[1];
      final c = pattern[2];
      if (_board[a].isNotEmpty && _board[a] == _board[b] &&
          _board[b] == _board[c]) {
        _gameOver = true;
        _winningIndices = pattern;
        if (_board[a] == 'X') {
          _scoreX += 1;
        } else {
          _scoreO += 1;
        }
        _confettiController.play();
        _saveScores();
        return;
      }
    }

    if (!_board.contains('')) {
      _gameOver = true;
      _draws += 1;
      _winningIndices = [];
      _saveScores();
    }
  }

  void _restartBoard({bool keepScore = true}) {
    setState(() {
      for (int i = 0; i < 9; i++)
        _board[i] = '';
      _gameOver = false;
      _winningIndices = [];
      _currentPlayer = 'X';
      if (!keepScore) {
        _scoreX = 0;
        _scoreO = 0;
        _draws = 0;
        _saveScores();
      }
    });
  }

  int _bestMove() {
    // Easy: random chance to make a mistake
    if (Random().nextDouble() < 0.3) {
      final empty = List.generate(9, (i) => i).where((i) => _board[i].isEmpty).toList();
      return empty[Random().nextInt(empty.length)];
    }

    // Otherwise play optimally
    int bestScore = -9999;
    int move = -1;
    for (int i = 0; i < 9; i++) {
      if (_board[i].isEmpty) {
        _board[i] = 'O';
        int score = _minimax(0, false);
        _board[i] = '';
        if (score > bestScore) {
          bestScore = score;
          move = i;
        }
      }
    }
    return move;
  }


  int _minimax(int depth, bool isMaximizing) {
    final winner = _evaluateWinner();
    if (winner != null) {
      if (winner == 'O') return 10 - depth;
      if (winner == 'X') return depth - 10;
      if (winner == 'D') return 0;
    }

    if (isMaximizing) {
      int bestScore = -9999;
      for (int i = 0; i < 9; i++) {
        if (_board[i].isEmpty) {
          _board[i] = 'O';
          int score = _minimax(depth + 1, false);
          _board[i] = '';
          bestScore = score > bestScore ? score : bestScore;
        }
      }
      return bestScore;
    } else {
      int bestScore = 9999;
      for (int i = 0; i < 9; i++) {
        if (_board[i].isEmpty) {
          _board[i] = 'X';
          int score = _minimax(depth + 1, true);
          _board[i] = '';
          bestScore = score < bestScore ? score : bestScore;
        }
      }
      return bestScore;
    }
  }

  String? _evaluateWinner() {
    for (var pattern in _winPatterns) {
      final a = pattern[0];
      final b = pattern[1];
      final c = pattern[2];
      if (_board[a].isNotEmpty && _board[a] == _board[b] &&
          _board[b] == _board[c]) {
        return _board[a];
      }
    }
    if (!_board.contains('')) return 'D';
    return null;
  }

  // --- Export board as image & share ---
  Future<void> _shareBoard() async {
    try {
      RenderRepaintBoundary boundary =
      _boardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/board.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
          [XFile(file.path)], text: 'Check out my Tic Tac Toe game!');
    } catch (e) {
      debugPrint("Error capturing board: $e");
    }
  }


  Widget _buildSquare(int index) {
    final value = _board[index];
    final isWinning = _winningIndices.contains(index);

    return GestureDetector(
      onTap: () => _handleTap(index),
      child: AnimatedScale(
        scale: isWinning ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isWinning ? Colors.green.shade300 : Theme
                .of(context)
                .colorScheme
                .surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, offset: Offset(0, 4), blurRadius: 6)
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isWinning ? 48 : 42,
                fontWeight: FontWeight.w700,
                color: value == 'X' ? Theme
                    .of(context)
                    .colorScheme
                    .primary : Theme
                    .of(context)
                    .colorScheme
                    .secondary,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return RepaintBoundary(
      key: _boardKey,
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            return _buildSquare(index);
          },
        ),
      ),
    );
  }

  Widget _buildStatus() {
    String status;
    if (_gameOver && _winningIndices.isNotEmpty) {
      final winner = _board[_winningIndices[0]];
      status = 'Player $winner wins!';
    } else if (_gameOver && _winningIndices.isEmpty) {
      status = 'Draw!';
    } else {
      status = 'Current: $_currentPlayer';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          status,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        AnimatedOpacity(
          opacity: _gameOver ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: _gameOver
              ? Text(
            _winningIndices.isNotEmpty
                ? 'Tap Restart to play again'
                : 'No winner — restart to try again',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface
            ),
          )
              : const SizedBox.shrink(),
        )
      ],
    );
  }

  Widget _buildScoreboard() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _scoreTile('X', _scoreX, Theme
            .of(context)
            .colorScheme
            .primary),
        _scoreTile('Draws', _draws, Colors.grey.shade700),
        _scoreTile('O', _scoreO, Theme
            .of(context)
            .colorScheme
            .secondary),
      ],
    );
  }

  Widget _scoreTile(String label, int value, Color color) {
    return Column(
      children: [
        Text(
            label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value.toString(), style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600)),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/tic-tac-toe.png',
              height: 25,
            ),
            const SizedBox(width: 8),
            const Text('Tic Tac Toe'),
          ],
        ),
        elevation: 4,
        actions: [
          IconButton(
            tooltip: 'Change theme mode',
            onPressed: widget.onToggleTheme,
            icon: const Icon(Icons.brightness_6),
          ),
          IconButton(
            tooltip: 'Cycle accent',
            onPressed: widget.onCycleAccent,
            icon: const Icon(Icons.color_lens),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Status + Single Player toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatus(),
                      Row(
                        children: [
                          const Text('Single player'),
                          Switch(
                            value: _singlePlayer,
                            onChanged: (v) {
                              setState(() {
                                _singlePlayer = v;
                                _restartBoard();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Scoreboard
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: _buildScoreboard(),
                ),
                const SizedBox(height: 18),

                // Game board
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 18),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: _buildBoard(),
                        ),
                      ),
                    ),
                  ),
                ),

                // Buttons BELOW the board
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _restartBoard(),
                    icon: const Icon(Icons.replay),
                    label: const Text('Restart'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _shareBoard,
                        icon: const Icon(Icons.share),
                        label: const Text('Share image'),
                      ),
                      TextButton(
                        onPressed: () => _restartBoard(keepScore: false),
                        child: const Text('Reset scores'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),

            // Confetti animation
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 30,
                gravity: 0.3,
                emissionFrequency: 0.02,
              ),
            ),
          ],
        ),
      ),
    );
  }
}