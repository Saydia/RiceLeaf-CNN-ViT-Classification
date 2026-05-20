import 'package:flutter/material.dart';

class QuickReferenceCard extends StatelessWidget {
  const QuickReferenceCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quick Disease Reference',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Visual Guide',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 16),

            _buildDiseaseCard(
              emoji: '✅',
              name: 'Healthy Leaf',
              description: 'Vibrant green, no spots',
              action: 'Continue current practices',
              color: Colors.green,
            ),

            _buildDiseaseCard(
              emoji: '🐛',
              name: 'Insect Damage',
              description: 'Holes, tears, leaf rolling',
              action: 'Apply insecticide immediately',
              color: Colors.orange,
              urgentChemicals: [
                'Chlorantraniliprole 60ml/acre',
                'Fipronil 400ml/acre',
              ],
            ),

            _buildDiseaseCard(
              emoji: '🍂',
              name: 'Leaf Scald',
              description: 'Scalded tips, brown margins',
              action: 'Apply fungicide + improve drainage',
              color: Colors.orange.shade700,
              urgentChemicals: [
                'Propiconazole 200ml/acre',
                'Azoxystrobin 200ml/acre',
              ],
            ),

            _buildDiseaseCard(
              emoji: '💥',
              name: 'Rice Blast - CRITICAL!',
              description: 'Diamond lesions, gray center',
              action: 'URGENT: Apply fungicide NOW!',
              color: Colors.red,
              urgentChemicals: [
                'Tricyclazole 120-150g/acre',
                'Isoprothiolane 375ml/acre',
              ],
              isCritical: true,
            ),

            const SizedBox(height: 24),

            _buildTipsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseCard({
    required String emoji,
    required String name,
    required String description,
    required String action,
    required Color color,
    List<String>? urgentChemicals,
    bool isCritical = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical ? Colors.red : color,
          width: isCritical ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCritical ? Icons.warning : Icons.local_hospital,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isCritical ? Colors.red : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                if (urgentChemicals != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const Text(
                    'Quick Treatment:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...urgentChemicals.map(
                    (chem) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              chem,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    return Container(
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
              Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 28),
              const SizedBox(width: 8),
              const Text(
                'Farmer Tips',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildTip('📸 Take clear, well-lit photos'),
          _buildTip('⏰ Check fields weekly'),
          _buildTip('🧪 Mix chemicals as per label'),
          _buildTip('🧤 Wear protective gear'),
          _buildTip('☀️ Spray early morning or evening'),
          _buildTip('💧 Maintain 5-10cm water depth'),
          _buildTip('🌱 Use disease-resistant varieties'),
          _buildTip('📞 Consult agricultural officer for serious cases'),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
