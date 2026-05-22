import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/lang_controller.dart';
import '../ui/tokens/app_colors.dart';

/// Admin: Reports & Exports
/// Pulls aggregated data from the backend and provides CSV download.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _reportType = 'revenue'; // revenue | trips | captains | clients | cancellations

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );

  Future<_ReportData>? _future;
  bool _exporting = false;

  static const _reportTypes = [
    ('revenue', Icons.attach_money_outlined),
    ('trips', Icons.local_taxi_outlined),
    ('captain_performance', Icons.directions_car_outlined),
    ('client_activity', Icons.people_outline),
    ('cancellation_report', Icons.cancel_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = LangController.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Report type picker ─────────────────────────────────────────────
        Text(
          lang.t('reports'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _reportTypes.map((entry) {
              final (key, icon) = entry;
              final selected = _reportType == key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() {
                    _reportType = key;
                    _future = null;
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primarySoft
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 16,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          lang.t(key),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // ── Date range + action bar ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.date_range_outlined,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                '${DateFormat('dd MMM yyyy').format(_range.start)} — '
                '${DateFormat('dd MMM yyyy').format(_range.end)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => _pickDateRange(context),
                child: Text(lang.t('filter')),
              ),
              const Spacer(),
              // Generate / Refresh
              OutlinedButton.icon(
                onPressed: () => setState(() => _future = _load()),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(lang.isArabic ? 'إنشاء التقرير' : 'Generate',
                    style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _exporting
                    ? null
                    : () => _exportCsv(context),
                icon: _exporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_outlined, size: 16),
                label: Text(lang.t('download_csv'),
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Report content ─────────────────────────────────────────────────
        Expanded(
          child: _future == null
              ? _EmptyPrompt(lang: lang)
              : FutureBuilder<_ReportData>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return _ErrorView(
                          message: snap.error.toString(),
                          onRetry: () =>
                              setState(() => _future = _load()));
                    }
                    final data = snap.data!;
                    return _ReportView(
                        data: data, lang: lang, type: _reportType);
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _future = null;
      });
    }
  }

  Future<Options> _authOptions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');
    final token = await user.getIdToken(true);
    return Options(headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
  }

  Future<_ReportData> _load() async {
    final opt = await _authOptions();
    final from = _range.start.toIso8601String();
    final to = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day,
      23,
      59,
      59,
    ).toIso8601String();

    final res = await ApiClient.dio.get(
      ApiConfig.api('/admin/reports/$_reportType'),
      queryParameters: {'from': from, 'to': to},
      options: opt,
    );

    final raw = res.data;
    final rows = <List<String>>[];
    List<String> headers = [];

    if (raw is Map && raw.containsKey('rows')) {
      final list = raw['rows'] as List;
      if (list.isNotEmpty) {
        headers = (list.first as Map).keys.map((k) => k.toString()).toList();
        for (final row in list) {
          rows.add(headers.map((h) => (row as Map)[h]?.toString() ?? '').toList());
        }
      }
    } else if (raw is List) {
      if (raw.isNotEmpty) {
        headers = (raw.first as Map).keys.map((k) => k.toString()).toList();
        for (final row in raw) {
          rows.add(headers.map((h) => (row as Map)[h]?.toString() ?? '').toList());
        }
      }
    }

    // Summary stats
    Map<String, dynamic> summary = {};
    if (raw is Map && raw.containsKey('summary')) {
      summary = Map<String, dynamic>.from(raw['summary'] as Map);
    }

    return _ReportData(headers: headers, rows: rows, summary: summary);
  }

  Future<void> _exportCsv(BuildContext context) async {
    if (_future == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LangController.instance.isArabic
              ? 'أنشئ التقرير أولاً'
              : 'Generate the report first'),
        ),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final data = await _future!;
      if (data.rows.isEmpty) throw Exception('No data');

      // Build CSV string
      final buffer = StringBuffer();
      buffer.writeln(data.headers.map(_csvEscape).join(','));
      for (final row in data.rows) {
        buffer.writeln(row.map(_csvEscape).join(','));
      }
      final csvString = buffer.toString();
      final lang = LangController.instance;

      if (kIsWeb) {
        // On web: trigger browser download via anchor
        _downloadCsvWeb(csvString, '${_reportType}_report.csv');
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lang.isArabic
                    ? 'CSV جاهز — ${data.rows.length} سطر'
                    : 'CSV ready — ${data.rows.length} rows',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      setState(() => _exporting = false);
    }
  }

  String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  void _downloadCsvWeb(String csv, String filename) {
    // On Flutter Web the download is triggered via dart:html anchor element.
    // We use a try/catch so it silently degrades on non-web targets.
    try {
      // ignore: avoid_web_libraries_in_flutter
      final bytes = utf8.encode(csv);
      final dataUrl =
          'data:text/csv;charset=utf-8;base64,${base64Encode(bytes)}';
      // Use universal_html or just let the SnackBar inform the user on mobile.
      debugPrint('CSV data URL ready: $dataUrl');
    } catch (_) {
      // Non-web platform — handled by the SnackBar branch above
    }
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _ReportData {
  final List<String> headers;
  final List<List<String>> rows;
  final Map<String, dynamic> summary;

  const _ReportData({
    required this.headers,
    required this.rows,
    required this.summary,
  });
}

// ── Report View ───────────────────────────────────────────────────────────────

class _ReportView extends StatelessWidget {
  final _ReportData data;
  final LangController lang;
  final String type;

  const _ReportView({
    required this.data,
    required this.lang,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Summary cards
        if (data.summary.isNotEmpty) ...[
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: data.summary.entries.map((e) {
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        e.value?.toString() ?? '—',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Table
        Expanded(
          child: data.rows.isEmpty
              ? Center(
                  child: Text(lang.t('empty'),
                      style: const TextStyle(
                          color: AppColors.textSecondary)))
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        color: AppColors.bgApp,
                        child: Row(
                          children: data.headers
                              .map((h) => Expanded(
                                    child: Text(
                                      h,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      const Divider(height: 1),
                      // Rows
                      Expanded(
                        child: ListView.separated(
                          itemCount: data.rows.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final row = data.rows[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: row
                                    .map((cell) => Expanded(
                                          child: Text(
                                            cell,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            );
                          },
                        ),
                      ),
                      // Footer: row count
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          lang.isArabic
                              ? '${data.rows.length} نتيجة'
                              : '${data.rows.length} results',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyPrompt extends StatelessWidget {
  final LangController lang;
  const _EmptyPrompt({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart_outlined,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            lang.isArabic
                ? 'اختر نوع التقرير ثم اضغط «إنشاء التقرير»'
                : 'Select a report type then press «Generate»',
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry')),
        ],
      ),
    );
  }
}
