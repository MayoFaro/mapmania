// lib/widgets/countdown_timer.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// Widget affiche un compte à rebours numérique avant le début du jeu.
/// Affiche le nombre de secondes restantes, et déclenche [onFinished]
/// lorsque le compte atteint 0.
class CountdownTimer extends StatefulWidget {
  /// Durée initiale en secondes
  final int seconds;
  /// Callback appelé lorsque le compte à rebours est terminé
  final VoidCallback onFinished;

  const CountdownTimer({
    Key? key,
    required this.seconds,
    required this.onFinished,
  }) : super(key: key);

  @override
  _CountdownTimerState createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remaining--;
      });
      if (_remaining <= 0) {
        timer.cancel();
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$_remaining',
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}
