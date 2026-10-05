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
    final cloudy = condition == 'cloudy';
    final overcast = condition == 'overcast';
    final rainy = condition == 'rain';
    final snowy = condition == 'snow';
    final sleety = condition == 'sleet';
    final colors = night
        ? [
            const Color(0xff0b1534),
            overcast
                ? const Color(0xff26313f)
                : rainy
                ? const Color(0xff172b40)
                : snowy
                ? const Color(0xff3b4c61)
                : sleety
                ? const Color(0xff1c2e43)
                : cloudy
                ? const Color(0xff1d2e4b)
                : const Color(0xff23385b),
            overcast
                ? const Color(0xff394653)
                : rainy
                ? const Color(0xff1c3d51)
                : snowy
                ? const Color(0xff566b7a)
                : sleety
                ? const Color(0xff2d4151)
                : cloudy
                ? const Color(0xff293e5c)
                : const Color(0xff244f66),
          ]
        : overcast
        ? [
            const Color(0xff46515e),
            const Color(0xff77838c),
            const Color(0xff52616d),
          ]
        : rainy
        ? [
            const Color(0xff263b50),
            const Color(0xff55788b),
            const Color(0xff1d4054),
          ]
        : snowy
        ? [
            const Color(0xff53677d),
            const Color(0xff91aabd),
            const Color(0xff627d92),
          ]
        : sleety
        ? [
            const Color(0xff34475b),
            const Color(0xff718b9b),
            const Color(0xff355669),
          ]
        : cloudy
        ? [
            const Color(0xff245174),
            const Color(0xff6590a8),
            const Color(0xff365c78),
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
    final glow = overcast
        ? .025
        : rainy || sleety
        ? .055
        : cloudy
        ? .13
        : .3;
    final pulse = .94 + .06 * math.sin(t * 2 * math.pi);
    canvas.drawCircle(
      sun,
      178 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xffd8f3ff).withValues(alpha: night ? .09 : glow),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: 178 * pulse)),
    );
    if (condition == 'clear' && !night) {
      canvas.save();
      canvas.translate(sun.dx, sun.dy);
      canvas.rotate(t * math.pi * 2);
      for (var i = 0; i < 12; i++) {
        canvas.rotate(math.pi / 6);
        canvas.drawLine(
          const Offset(0, -53),
          const Offset(0, -88),
          Paint()
            ..color = const Color(0xffffedc2).withValues(alpha: .15 * pulse)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.restore();
    }
    if (!wet && !overcast && condition == 'clear') {
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
              alpha:
                  (.2 + .25 * (1 + math.sin(t * 2 * math.pi + i)) / 2) *
                  (overcast
                      ? .12
                      : cloudy
                      ? .45
                      : wet
                      ? .25
                      : 1),
            ),
        );
      }
    }
    final cloudCount = overcast
        ? 11
        : cloudy
        ? 8
        : 5;
    for (int i = 0; i < cloudCount; i++) {
      final drift = overcast
          ? 12.0
          : cloudy
          ? 34.0
          : 48.0;
      final x =
          size.width * (i / (cloudCount - 1) - .15) +
          math.sin(t * 2 * math.pi + i * .8) * drift;
      final y =
          size.height *
          (overcast ? .15 + (i % 4) * .075 : .13 + (i % 3) * .105);
      final cloudWidth = overcast
          ? 285.0
          : cloudy
          ? 245.0
          : 210.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: cloudWidth,
          height: overcast ? 86 : 62,
        ),
        Paint()
          ..color = Colors.white.withValues(
            alpha: overcast
                ? .24
                : cloudy
                ? .17
                : wet
                ? .11
                : .045,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, overcast ? 38 : 28),
      );
    }
    if (wet) {
      final particleCount = snowy
          ? 58
          : sleety
          ? 72
          : 92;
      for (int i = 0; i < particleCount; i++) {
        final fallSpeed = snowy
            ? 1.25
            : sleety
            ? 3.2
            : 5.2;
        final windDrift = snowy ? 22 : 8;
        final x = ((i * 61.7 + t * windDrift * 20) % size.width);
        final y = ((i * 97.3 + t * size.height * fallSpeed) % size.height);
        final paint = Paint()
          ..color = Colors.white.withValues(
            alpha: snowy ? .22 + (i % 4) * .11 : .13 + (i % 4) * .08,
          )
          ..strokeWidth = snowy ? 1 : 1.2
          ..strokeCap = StrokeCap.round;
        if (snowy || (sleety && i.isEven)) {
          canvas.drawCircle(
            Offset(x + math.sin(t * 2 * math.pi + i) * windDrift, y),
            snowy ? 1.5 + i % 3 : 1.5 + i % 2,
            paint,
          );
        } else {
          canvas.drawLine(
            Offset(x, y),
            Offset(x - (rainy ? 7 : 4), y + (rainy ? 24 : 18) + i % 12),
            paint,
          );
        }
      }
      if (rainy || sleety) {
        for (int i = 0; i < 7; i++) {
          final x =
              size.width * (.08 + i * .14) + math.sin(t * 2 * math.pi + i) * 12;
          final phase = (t * 1.8 + i * .17) % 1;
          final radius = 4 + phase * 20;
          final center = Offset(x, size.height * (.83 + phase * .1));
          canvas.drawOval(
            Rect.fromCenter(center: center, width: radius * 1.7, height: 3),
            Paint()
              ..color = Colors.white.withValues(alpha: (1 - phase) * .18)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
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
