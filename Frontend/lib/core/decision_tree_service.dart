import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../main.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// Hasil prediksi dari Edge Function predict-evaluation.
///
/// [modelActive] false berarti belum ada model yang aktif; dalam kondisi ini
/// [prediksi] dan [confidence] bernilai null.
class DecisionTreePrediction {
  final bool modelActive;
  final String? prediksi; // 'selesai' | 'revisi'
  final double? confidence; // 0.0 – 1.0
  final String? modelVersion;

  const DecisionTreePrediction({
    required this.modelActive,
    this.prediksi,
    this.confidence,
    this.modelVersion,
  });

  /// Confidence dalam persentase (0–100), sudah dibulatkan.
  int? get confidencePersen =>
      confidence != null ? (confidence! * 100).round() : null;

  factory DecisionTreePrediction.fromJson(Map<String, dynamic> json) {
    final active = json['model_active'] as bool? ?? true;
    if (!active) return const DecisionTreePrediction(modelActive: false);
    return DecisionTreePrediction(
      modelActive: true,
      prediksi: json['prediksi'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      modelVersion: json['model_version'] as String?,
    );
  }
}

/// Hasil dari Edge Function submit-evaluation.
class EvaluasiResult {
  final String evaluasiId;
  const EvaluasiResult({required this.evaluasiId});
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Service untuk berinteraksi dengan Decision Tree via Supabase Edge Functions.
///
/// Semua error dilempar sebagai [Exception] dengan pesan yang dapat
/// ditampilkan langsung ke pengguna.
class DecisionTreeService {
  DecisionTreeService._();

  // Nama Edge Function yang sudah di-deploy di Supabase.
  static const _fnPredict = 'predict-evaluation';
  static const _fnSubmit = 'submit-evaluation';

  // -------------------------------------------------------------------------
  // predict
  // -------------------------------------------------------------------------

  /// Meminta prediksi Decision Tree dari server.
  ///
  /// Jika model belum aktif, mengembalikan [DecisionTreePrediction] dengan
  /// [modelActive] = false tanpa melempar exception — evaluasi tetap bisa
  /// disimpan sebagai data manual.
  static Future<DecisionTreePrediction> predict({
    required int nilai,
    required bool kelengkapan,
    required bool kesesuaian,
  }) async {
    try {
      final response = await supabase.functions.invoke(
        _fnPredict,
        body: {
          'nilai': nilai,
          'kelengkapan': kelengkapan,
          'kesesuaian': kesesuaian,
        },
      );

      final data = _parseBody(response.data);

      // HTTP 200 dengan model_active: false → fase pengumpulan data awal.
      if (data['model_active'] == false) {
        return const DecisionTreePrediction(modelActive: false);
      }

      return DecisionTreePrediction.fromJson(data);
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Gagal mendapatkan prediksi: $e');
    }
  }

  // -------------------------------------------------------------------------
  // submitEvaluation
  // -------------------------------------------------------------------------

  /// Menyimpan histori evaluasi via Edge Function submit-evaluation.
  ///
  /// Edge Function memanggil RPC `record_task_evaluation` menggunakan
  /// service role sehingga bisa melewati RLS.
  ///
  /// [keputusanGuru] harus 'selesai' atau 'revisi'.
  /// [prediksiModel] dan [modelVersion] boleh null jika model belum aktif.
  static Future<EvaluasiResult> submitEvaluation({
    required String terlambatId,
    required int nilai,
    required bool kelengkapan,
    required bool kesesuaian,
    required String keputusanGuru,
    String? prediksiModel,
    double? predictionConfidence,
    String? modelVersion,
  }) async {
    assert(
      keputusanGuru == 'selesai' || keputusanGuru == 'revisi',
      'keputusanGuru harus selesai atau revisi',
    );

    try {
      final body = <String, dynamic>{
        'terlambat_id': terlambatId,
        'nilai': nilai,
        'kelengkapan': kelengkapan,
        'kesesuaian': kesesuaian,
        'keputusan_guru': keputusanGuru,
        'prediksi_model': prediksiModel,
        'prediction_confidence': predictionConfidence,
        'model_version': modelVersion,
        'decision_source':
            modelVersion != null ? 'decision_support' : 'manual',
      };

      final response = await supabase.functions.invoke(
        _fnSubmit,
        body: body,
      );

      final data = _parseBody(response.data);
      final id = data['evaluation_id'] as String?;
      if (id == null) throw Exception('Server tidak mengembalikan evaluation_id');
      return EvaluasiResult(evaluasiId: id);
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Gagal menyimpan evaluasi: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Helper
  // -------------------------------------------------------------------------

  static Map<String, dynamic> _parseBody(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    if (kDebugMode) debugPrint('[DecisionTreeService] unexpected body: $raw');
    throw Exception('Format respons server tidak dikenali');
  }
}
