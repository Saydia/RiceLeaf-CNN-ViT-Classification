import 'package:flutter/material.dart';
import 'dart:io';
import 'disease_info.dart';

class DiseaseDetailPage extends StatelessWidget {
  final String diseaseName;
  final double confidence;
  final File? imageFile;

  const DiseaseDetailPage({
    Key? key,
    required this.diseaseName,
    required this.confidence,
    this.imageFile,
  }) : super(key: key);

  Color _getSeverityColor(String severity) {
    if (severity.contains('None')) return Colors.green;
    if (severity.contains('Medium')) return Colors.orange;
    if (severity.contains('High') || severity.contains('CRITICAL'))
      return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final diseaseInfo = DiseaseInfo.getInfo(diseaseName);

    if (diseaseInfo == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Disease Information'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
        body: const Center(child: Text('Disease information not available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          diseaseInfo.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with image and confidence
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF2E7D32),
                    const Color(0xFF2E7D32).withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  if (imageFile != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          imageFile!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoCard(
                          context,
                          'Confidence',
                          '${confidence.toStringAsFixed(1)}%',
                          Icons.analytics,
                        ),
                        _buildInfoCard(
                          context,
                          'Severity',
                          diseaseInfo.severity,
                          Icons.warning,
                          color: _getSeverityColor(diseaseInfo.severity),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Description
            _buildSection(context, '${diseaseInfo.iconEmoji} About', [
              diseaseInfo.description,
            ], Icons.info_outline),

            // Symptoms
            if (diseaseInfo.symptoms.isNotEmpty)
              _buildSection(
                context,
                '🔍 Symptoms',
                diseaseInfo.symptoms,
                Icons.search,
              ),

            // Causes
            if (diseaseInfo.causes.isNotEmpty)
              _buildSection(
                context,
                '⚠️ Causes',
                diseaseInfo.causes,
                Icons.error_outline,
              ),

            // Treatments (Most Important)
            if (diseaseInfo.treatments.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.blue.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: _buildSection(
                  context,
                  '💊 Treatment Recommendations',
                  diseaseInfo.treatments,
                  Icons.medical_services,
                  isImportant: true,
                ),
              ),

            // Prevention
            if (diseaseInfo.prevention.isNotEmpty)
              _buildSection(
                context,
                '🛡️ Prevention Measures',
                diseaseInfo.prevention,
                Icons.shield,
              ),

            // Additional Tips
            _buildAdditionalTips(context, diseaseInfo),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color ?? Colors.green.shade700, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<String> items,
    IconData icon, {
    bool isImportant = false,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isImportant ? 0 : 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isImportant ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isImportant
            ? null
            : [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isImportant
                    ? Colors.green.shade700
                    : const Color(0xFF2E7D32),
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isImportant
                        ? Colors.green.shade900
                        : const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            // Check if item is a header (ends with ':' or is all caps)
            bool isHeader =
                item.endsWith(':') ||
                (item == item.toUpperCase() && item.length > 5);

            // Check if item is indented (starts with spaces)
            bool isIndented = item.startsWith('  ');

            if (item.isEmpty) {
              return const SizedBox(height: 8);
            }

            if (isHeader) {
              return Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: 8, left: isIndented ? 16 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isIndented)
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isImportant
                            ? Colors.green.shade700
                            : const Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      item.trim(),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAdditionalTips(BuildContext context, DiseaseInfo diseaseInfo) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.cyan.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Important Tips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTip(
            'Consult with local agricultural extension officers for region-specific advice',
          ),
          _buildTip('Always read and follow pesticide labels carefully'),
          _buildTip('Use protective equipment when applying chemicals'),
          _buildTip(
            'Keep records of treatments applied and their effectiveness',
          ),
          if (diseaseInfo.severity.contains('High') ||
              diseaseInfo.severity.contains('CRITICAL'))
            _buildTip(
              'URGENT: This disease can cause severe crop loss. Act immediately!',
              isUrgent: true,
            ),
        ],
      ),
    );
  }

  Widget _buildTip(String text, {bool isUrgent = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isUrgent ? Icons.warning : Icons.check_circle,
            color: isUrgent ? Colors.red : Colors.green.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isUrgent ? Colors.red.shade700 : Colors.grey.shade800,
                fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
