import 'package:flutter/material.dart';

/// Semantic colors for Ops dashboard: trips, drivers, alerts, statuses.
class AppColors {
  AppColors._();

  // Primary Theme Surfaces (Dark Ops Theme)
  static const Color background = Color(0xFF0F172A); // slate-900
  static const Color surface = Color(0xFF1E293B);    // slate-800
  static const Color surfaceLight = Color(0xFF334155); // slate-700
  static const Color border = Color(0xFF334155);

  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8); // slate-400

  // Brand Accent
  static const Color primary = Color(0xFF38BDF8); // sky-400
  static const Color primaryDark = Color(0xFF0284C7); // sky-600
  static const Color accent = Color(0xFF38BDF8); // sky-400 alias for primary

  // Semantic Status Colors
  static const Color success = Color(0xFF10B981); // Emerald / Available / Completed
  static const Color info = Color(0xFF3B82F6);    // Blue / On Trip / Dispatched
  static const Color warning = Color(0xFFF59E0B); // Amber / Pending / Reconnecting
  static const Color error = Color(0xFFEF4444);   // Rose / Cancelled / Error
  static const Color sos = Color(0xFFDC2626);     // Red-600 / Critical SOS Alert
  static const Color muted = Color(0xFF94A3B8);   // Slate-400 / Offline

  // Driver Status Helpers
  static Color forDriverStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'available':
        return success;
      case 'on_trip':
      case 'ontrip':
        return info;
      case 'busy':
        return warning;
      case 'offline':
      default:
        return muted;
    }
  }

  // Trip Status Helpers
  static Color forTripStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return success;
      case 'in_progress':
      case 'active':
        return info;
      case 'requested':
      case 'assigned':
      case 'driver_arrived':
        return warning;
      case 'cancelled':
      case 'failed':
        return error;
      default:
        return muted;
    }
  }

  // Alert Severity Helpers
  static Color forAlertSeverity(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
      case 'sos':
        return sos;
      case 'warning':
        return warning;
      case 'info':
      default:
        return info;
    }
  }
}
