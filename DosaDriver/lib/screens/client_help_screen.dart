import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';

class ClientHelpScreen extends StatefulWidget {
  const ClientHelpScreen({super.key});

  @override
  State<ClientHelpScreen> createState() => _ClientHelpScreenState();
}

class _ClientHelpScreenState extends State<ClientHelpScreen> {
  final List<_FaqItem> _faqs = const [
    _FaqItem(
      question: 'كيف أحجز رحلة؟',
      answer:
          'اضغط على حقل "ابحث عن وجهتك" في الشاشة الرئيسية، حدد موقع الانطلاق والوجهة، اختر نوع الرحلة والسعر المناسب، ثم اضغط "تأكيد الحجز".',
    ),
    _FaqItem(
      question: 'كيف يُحسب السعر؟',
      answer:
          'يُحسب السعر بناءً على المسافة والوقت المقدر للرحلة. يمكنك تعديل السعر المعروض باستخدام شريط التسعير قبل تأكيد الحجز.',
    ),
    _FaqItem(
      question: 'كيف أتواصل مع الكابتن؟',
      answer:
          'بعد قبول الرحلة، يظهر زر "اتصال" في شاشة الرحلة الجارية يتيح لك الاتصال المباشر بالكابتن.',
    ),
    _FaqItem(
      question: 'كيف أدفع؟',
      answer:
          'نقبل الدفع نقدًا، وعبر InstaPay، وعبر فودافون كاش. اختر طريقة الدفع المناسبة عند تأكيد الحجز.',
    ),
    _FaqItem(
      question: 'كيف أُلغي رحلة؟',
      answer:
          'يمكنك إلغاء الرحلة قبل وصول الكابتن من خلال زر "إلغاء الرحلة" في شاشة الرحلة الجارية.',
    ),
    _FaqItem(
      question: 'كيف أُقيّم الرحلة؟',
      answer:
          'بعد اكتمال الرحلة تظهر شاشة التقييم تلقائيًا. يمكنك أيضًا تقييم الرحلة لاحقًا من سجل رحلاتك.',
    ),
    _FaqItem(
      question: 'هل تطبيقي آمن؟',
      answer:
          'نعم، جميع بيانات الدفع مشفرة. ولا نشارك معلوماتك الشخصية مع أي طرف ثالث دون إذنك.',
    ),
    _FaqItem(
      question: 'ماذا أفعل إذا نسيت شيئًا في السيارة؟',
      answer:
          'تواصل مع الكابتن مباشرةً عبر سجل رحلاتك، أو تواصل مع الدعم الفني على البريد الإلكتروني أدناه.',
    ),
  ];

  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'المساعدة والدعم',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header card ──
          _buildHeaderCard(),
          const SizedBox(height: 20),

          // ── FAQ ──
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الأسئلة الشائعة',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.darkGray,
              ),
            ),
          ),
          const SizedBox(height: 10),

          ...List.generate(_faqs.length, (i) => _buildFaqTile(i)),

          const SizedBox(height: 24),

          // ── Contact ──
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'تواصل معنا',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.darkGray,
              ),
            ),
          ),
          const SizedBox(height: 10),

          _buildContactCard(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF8C1D18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.headset_mic_outlined, color: Colors.white, size: 40),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحبًا، كيف نساعدك؟',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'فريق الدعم متاح 24/7 لمساعدتك',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile(int i) {
    final faq = _faqs[i];
    final open = _expanded.contains(i);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ExpansionTile(
          key: ValueKey(i),
          initiallyExpanded: false,
          onExpansionChanged: (v) =>
              setState(() => v ? _expanded.add(i) : _expanded.remove(i)),
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(
            faq.question,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: open ? AppColors.primary : AppColors.darkGray,
            ),
          ),
          trailing: Icon(
            open
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: open ? AppColors.primary : AppColors.mediumGray,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  faq.answer,
                  style: const TextStyle(
                      color: AppColors.mediumGray,
                      fontSize: 13,
                      height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _ContactTile(
            icon: Icons.email_outlined,
            label: 'البريد الإلكتروني',
            value: 'support@dosadriver.com',
            onTap: () => _launch('mailto:support@dosadriver.com'),
          ),
          const Divider(height: 1, indent: 56),
          _ContactTile(
            icon: Icons.phone_outlined,
            label: 'الهاتف',
            value: '+20 100 000 0000',
            onTap: () => _launch('tel:+201000000000'),
          ),
          const Divider(height: 1, indent: 56),
          _ContactTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'واتساب',
            value: 'تواصل عبر WhatsApp',
            onTap: () =>
                _launch('https://wa.me/201000000000?text=مرحبًا، أحتاج مساعدة'),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح التطبيق')),
        );
      }
    }
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.primaryLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      title: Text(label,
          style: const TextStyle(color: AppColors.mediumGray, fontSize: 12)),
      subtitle: Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.darkGray)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: AppColors.mediumGray),
      onTap: onTap,
    );
  }
}
