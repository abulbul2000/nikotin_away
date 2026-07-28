import 'dart:collection';
import 'dart:io';
import 'package:image/image.dart';

/// Strips the light card the launcher artwork sits on, so the mark can be
/// drawn straight onto the app's dark background instead of appearing as a
/// pale rectangle floating on it.
///
/// Grows a region inward from the border instead of keying out every light
/// pixel. Two reasons: the butterfly has white highlights of its own and
/// those aren't connected to the edge, so they survive; and the card carries
/// a soft drop shadow, which a fixed "is this the corner colour?" test walks
/// straight off the end of — comparing each pixel to the one that reached it
/// follows that gradient down instead.
///
/// The luminance floor is what keeps the growth off the artwork: the card and
/// its shadow sit well above it, the chain and butterfly well below.
void main() {
  final src = decodePng(File('assets/images/no_smoke_launcher_icon.png').readAsBytesSync())!;
  final img = src.convert(numChannels: 4);
  final w = img.width, h = img.height;

  const stepTolerance = 26.0; // per-hop colour distance
  const luminanceFloor = 190.0; // never grow into artwork this dark

  double lum(num r, num g, num b) => 0.299 * r + 0.587 * g + 0.114 * b;

  final visited = List<bool>.filled(w * h, false);
  final queue = Queue<List<int>>(); // [x, y, srcR, srcG, srcB]

  void tryAdd(int x, int y, num sr, num sg, num sb) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = y * w + x;
    if (visited[i]) return;
    final p = img.getPixel(x, y);
    if (p.a >= 8) {
      if (lum(p.r, p.g, p.b) < luminanceFloor) return;
      final dr = p.r - sr, dg = p.g - sg, db = p.b - sb;
      if (dr * dr + dg * dg + db * db > stepTolerance * stepTolerance) return;
    }
    visited[i] = true;
    queue.add([x, y, p.r.toInt(), p.g.toInt(), p.b.toInt()]);
  }

  for (var x = 0; x < w; x++) {
    tryAdd(x, 0, 255, 255, 255);
    tryAdd(x, h - 1, 255, 255, 255);
  }
  for (var y = 0; y < h; y++) {
    tryAdd(0, y, 255, 255, 255);
    tryAdd(w - 1, y, 255, 255, 255);
  }

  var cleared = 0;
  while (queue.isNotEmpty) {
    final n = queue.removeFirst();
    final x = n[0], y = n[1];
    img.setPixelRgba(x, y, 0, 0, 0, 0);
    cleared++;
    tryAdd(x - 1, y, n[2], n[3], n[4]);
    tryAdd(x + 1, y, n[2], n[3], n[4]);
    tryAdd(x, y - 1, n[2], n[3], n[4]);
    tryAdd(x, y + 1, n[2], n[3], n[4]);
  }

  File('assets/images/no_smoke_logo_transparent.png')
      .writeAsBytesSync(encodePng(img));
  stdout.writeln(
    'saydamlastirilan: $cleared (%${(cleared / (w * h) * 100).toStringAsFixed(1)})',
  );
}
