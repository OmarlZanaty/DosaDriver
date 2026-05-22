import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../widgets/captain_drawer.dart';

class CaptainHelpScreen extends StatefulWidget {
  const CaptainHelpScreen({super.key});

  @override
  State<CaptainHelpScreen> createState() => _CaptainHelpScreenState();
}

class _CaptainHelpScreenState extends State<CaptainHelpScreen> {
  final List<_FaqItem> _faqs = const [
    _FaqItem(
      question: 'كيف أقبل رحلة؟',
      answer:
          'تظهر طلبات الرحلات في الشاشة الرئيسية. اضغط على بطاقة الرحلة لعرض التفاصيل، ثم اضغط "قبول" لتأكيد الرحلة.',
    ),
    _FaqItem(
      question: 'كيف تُحسب أرباحي؟',
      answer:
          'تُحسب الأرباح بناءً على المسافة والوقت لكل رحلة. يمكن الاطلاع على التفاصيل الكاملة في شاشة الأرباح.',
    ),
    _FaqItem(
      question: 'كيف أُفعّل وضع "متصل"؟',
      answer:
          'في الشاشة الرئيسية، اضغط زر "متصل / غير متصل" للتبديل بين الوضعين. عند تفعيل "متصل" ستبدأ استقبال طلبات الرحلات.',
    ),
    _FaqItem(
      question: 'ماذا أفعل إذا رفض العميل الدفع؟',
      answer:
          'يُرجى التواصل مع فريق الدعم فورًا عبر البريد الإلكتروني أو الهاتف المذكورَين أدناه مع تفاصيل الرحلة.',
    ),
    _FaqItem(
      question: 'كيف أُحدّث بيانات سيارتي؟',
      answer:
          'اذهب إلى صفحة الإعدادات من القائمة الجانبية وقم بتحديث بيانات السيارة والمستندات المطلوبة.',
    ),
    _FaqItem(
      question: 'لماذا تم تعليق حسابي؟',
      answer:
          'قد يُعلَّق الحساب بسبب انتهاك سياسة الاستخدام أو انتهاء صلاحية المستندات. تواصل مع الدعم لمعرفة السبب والحل.',
    ),
    _FaqItem(
      question: 'كيف أُضيف طريقة استلام أرباح؟',
      answer:
          'من شاشة الأرباح اضغط "سحب الأرباح" للاطلاع على طرق الاستلام المتاحة والتواصل مع الدعم لإعداد حسابك.',
    ),
    _FaqItem(
      question: 'هل يمكنني العمل في أكثر من مدينة؟',
      answer:
          'نعم، يمكنك العمل في أي منطقة تغطيها خدمة DosaDriver طالما كان حسابك نشطًا ومستنداتك سارية.',
    ),
  ];

  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      drawer: const CaptainDrawer(),
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
          _buildHeaderCard(),
          const SizedBox(height: 20),

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

          ...List.generate(_faqs.length, _buildFaqTile),

          const SizedBox(height: 24),

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
          Icon(Icons.support_agent_rounded, color: Colors.white, size: 40),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'دعم الكابتن',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'نحن هنا لمساعدتك في أي وقت',
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
            value: 'captain-support@dosadriver.com',
            onTap: () => _launch('mailto:captain-support@dosadriver.com'),
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
                _launch('https://wa.me/201000000000?text=مرحبًا، أنا كابتن وأحتاج مساعدة'),
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
