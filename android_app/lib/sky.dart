import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const LiquidPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .17),
              Colors.white.withValues(alpha: .045),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: .24),
            width: 1,
          ),
        ),
        child: child,
      ),
    ),
  );
}

class LivingSky extends StatefulWidget {
  final String condition;
  final bool night;
  const LivingSky({super.key, required this.condition, required this.night});
  @override
  State<LivingSky> createState() => _LivingSkyState();
}

class _LivingSkyState extends State<LivingSky>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
    } else {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, child) => CustomPaint(
        painter: SkyPainter(controller.value, widget.condition, widget.night),
        size: Size.infinite,
      ),
    ),
  );
}

class SkyPainter extends CustomPainter {
  final double t;
  final String condition;
  final bool night;
  SkyPainter(this.t, this.condition, this.night);
  @override
  void paint(Canvas canvas, Size size) {
    final wet = ['rain', 'sleet', 'snow'].contains(condition);
    final colors = night
        ? [
            const Color(0xff0b1534),
            const Color(0xff23385b),
            const Color(0xff244f66),
          ]
        : wet
        ? [
            const Color(0xff20364c),
            const Color(0xff497b92),
            const Color(0xff143f5b),
          ]
        : [
            const Color(0xff123f73),
            const Color(0xff408cb2),
            const Color(0xff174c70),
          ];
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
    );
    final sun = Offset(size.width * .78, size.height * .16);
    canvas.drawCircle(
      sun,
      150,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xffc3eeff).withValues(alpha: wet ? .08 : .3),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: 150)),
    );
    if (!wet && condition == 'clear') {
      canvas.drawCircle(
        sun,
        night ? 23 : 36,
        Paint()
          ..color = (night ? const Color(0xffdef1ff) : const Color(0xffffe7ae))
              .withValues(alpha: .9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      if (night) {
        canvas.drawCircle(
          sun.translate(11, -8),
          22,
          Paint()..color = colors[0],
        );
      }
    }
    if (night) {
      for (int i = 0; i < 42; i++) {
        final x = ((i * 73) % 401) / 401 * size.width;
        final y = ((i * 47) % 397) / 397 * size.height * .7;
        canvas.drawCircle(
          Offset(x, y),
          i % 3 == 0 ? 1.4 : .8,
          Paint()
            ..color = Colors.white.withValues(
              alpha: .2 + .25 * (1 + math.sin(t * 2 * math.pi + i)) / 2,
            ),
        );
      }
    }
    for (int i = 0; i < 7; i++) {
      final x = size.width * (i / 5 - .2) + math.sin(t * 2 * math.pi + i) * 28;
      final y = size.height * (.13 + (i % 3) * .105);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 230, height: 62),
        Paint()
          ..color = Colors.white.withValues(
            alpha: condition == 'clear' ? .045 : .12,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
      );
    }
    if (wet) {
      for (int i = 0; i < 65; i++) {
        final x = ((i * 61.7 + t * 55) % size.width);
        final y =
            ((i * 97.3 + t * size.height * (condition == 'snow' ? 2 : 5)) %
            size.height);
        final paint = Paint()
          ..color = Colors.white.withValues(alpha: .15 + (i % 4) * .09)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        if (condition == 'snow' || (condition == 'sleet' && i.isEven)) {
          canvas.drawCircle(
            Offset(x + math.sin(t * 2 * math.pi + i) * 12, y),
            1.5 + i % 3,
            paint,
          );
        } else {
          canvas.drawLine(Offset(x, y), Offset(x - 4, y + 18 + i % 12), paint);
        }
      }
    }
    // Slow suspended water droplets with rim highlights and refracted centers.
    for (int i = 0; i < 8; i++) {
      final r = 13.0 + (i % 3) * 14;
      final center = Offset(
        size.width * ((i * 37 % 97) / 97),
        size.height * (.3 + (i * 19 % 67) / 100) +
            math.sin(t * 2 * math.pi + i) * 14,
      );
      final circle = Rect.fromCircle(center: center, radius: r);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.4, -.5),
            colors: [Color(0x28ffffff), Color(0x0316a5cc), Color(0x20c8f3ff)],
            stops: [0, .75, 1],
          ).createShader(circle),
      );
      canvas.drawArc(
        circle,
        math.pi,
        math.pi * .72,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: .24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      canvas.drawCircle(
        center.translate(-r * .35, -r * .43),
        r * .14,
        Paint()
          ..color = Colors.white.withValues(alpha: .3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(SkyPainter old) =>
      old.t != t || old.condition != condition || old.night != night;
}
