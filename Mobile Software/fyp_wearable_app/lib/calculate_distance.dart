import 'dart:math';
import 'package:flutter/foundation.dart';

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000; // meters
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;

  final a =
      (sin(dLat / 2) * sin(dLat / 2)) +
      cos(lat1 * pi / 180) *
      cos(lat2 * pi / 180) *
      (sin(dLon / 2) * sin(dLon / 2));

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  debugPrint("Calculated distance: ${R * c} meters");
  return R * c;
}

final List<double> distanceBuffer = [];

double smoothDistance(double d) {
  distanceBuffer.add(d);
  if (distanceBuffer.length > 5) {
    distanceBuffer.removeAt(0);
  }
  return distanceBuffer.reduce((a, b) => a + b) / distanceBuffer.length;
}

String calculateZone(double distance) {
  if (distance > 50) return "FAR";
  if (distance > 15) return "MID";
  if (distance > 3)  return "NEAR";
  return "FOUND";
}
