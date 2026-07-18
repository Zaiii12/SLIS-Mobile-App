import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/state/auth_provider.dart';

class _FaqEntry {
  const _FaqEntry(this.question, this.answer);

  final String question;
  final String answer;
}

const _adminFaqs = [
  _FaqEntry(
    'How do I check who did what and when?',
    'Go to the Audit Log tab. Every action is filterable by role, module, '
        'status, and date/time range — tap a filter chip to narrow the list, '
        'or "Clear" to reset. Pull down to refresh.',
  ),
  _FaqEntry(
    'What do the Financials numbers show?',
    'The Financials tab shows a live summary (billed, collected, outstanding) '
        'plus the real payments feed, filterable by payment method. It is '
        'view-only — recording a new payment still has to be done on the '
        'website.',
  ),
  _FaqEntry(
    'Why can\'t I see Attendance or Grades tabs?',
    'Admin and Super Admin accounts see Monitoring, Audit Log, and Financials '
        'instead — the backend gives these two roles full school-wide '
        'visibility through the Monitoring tab rather than a per-section '
        'Attendance/Grades view.',
  ),
  _FaqEntry(
    'How current is the "Recent activity" list in Notification Settings?',
    'It pulls live from the same endpoints as Dashboard and Financials '
        '(recent enrollments, pending applications, unpaid invoices, audit '
        'log) — pull to refresh, or toggle a category off if you don\'t want '
        'it included.',
  ),
  _FaqEntry(
    'A student or invoice looks wrong. What should I do?',
    'Double-check on the website first, since this app is a read-mostly '
        'companion to the ASIA admin portal for most records. If the data '
        'still looks wrong there too, contact IT support below.',
  ),
];

const _accountingFaqs = [
  _FaqEntry(
    'What does the Financials tab show me?',
    'A live summary of billed, collected, and outstanding amounts for the '
        'school year, plus the real payments feed filterable by payment '
        'method. It is view-only — recording a new payment still has to be '
        'done on the website.',
  ),
  _FaqEntry(
    'How do I see which invoices are still unpaid?',
    'The Financials tab and the "Recent activity" list in Notification '
        'Settings both surface unpaid invoices — the notification list shows '
        'the newest ones with balance and due date.',
  ),
  _FaqEntry(
    'Can I record a payment or edit an invoice from the app?',
    'Not yet — this app is view-only for billing. Use the ASIA web admin '
        'portal to record payments or make changes to an invoice.',
  ),
];

const _registrarFaqs = [
  _FaqEntry(
    'How do I see newly enrolled or pending students?',
    'Dashboard shows both. Notification Settings also has a live "Recent '
        'activity" feed for new enrollments and pending applications — '
        'toggle either category off if you don\'t want it included.',
  ),
  _FaqEntry(
    'Why don\'t I see Audit Log or Financials tabs?',
    'Those are Admin/Super Admin only on the backend. Registrar keeps full '
        'access to Students, Attendance, and Grades instead.',
  ),
  _FaqEntry(
    'Can I approve a pending enrollment from the app?',
    'Not yet — approving or editing an enrollment application still has to '
        'be done on the ASIA web admin portal. The app shows you the queue '
        'so you know what\'s waiting.',
  ),
];

const _teacherFaqs = [
  _FaqEntry(
    'Why do I only see my own students?',
    'Attendance, Grades, and the "Pending applications" notification '
        'category are automatically scoped to your assigned advisory '
        'section(s) by the backend — there\'s nothing to configure.',
  ),
  _FaqEntry(
    'What does "Today\'s attendance" in Notification Settings show?',
    'A live present/late/absent breakdown for your own section(s), for '
        'today\'s date — the same numbers you\'d see by opening the '
        'Attendance tab.',
  ),
  _FaqEntry(
    'I don\'t see any of my sections. What should I do?',
    'This usually means no advisory section has been assigned to your '
        'account yet — contact the Registrar\'s office to confirm your '
        'section assignment.',
  ),
];

const _generalFaqs = [
  _FaqEntry(
    'I can\'t log in. What should I check?',
    'Confirm your school email and password are correct. If you were '
        'recently logged in on another device, this app enforces a single '
        'active session — logging in elsewhere signs you out here.',
  ),
  _FaqEntry(
    'The app looks like it froze or shows stale data.',
    'Pull down on any list screen to refresh it. If a screen keeps failing '
        'to load, check your internet connection, then contact IT support '
        'below if it persists.',
  ),
];

/// Only shown to roles other than registrar — registrar's own FAQ set
/// already establishes that they're the ones who'd get this question.
const _contactRegistrarFaq = _FaqEntry(
  'Who do I contact about incorrect student or grade records?',
  'Contact the Registrar\'s office — the mobile app mirrors what is '
      'already in the system and does not change how records are '
      'corrected.',
);

/// Static FAQ + contact + app-info screen. ASIA has no support ticket, FAQ,
/// or contact backend (confirmed by grepping every service) — this is
/// reference content only, not a live ticketing system.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launch(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri);
    if (launched || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open ${uri.toString()}')),
    );
  }

  List<_FaqEntry> _faqsForRole(String? role) {
    if (hasAnyRole(role, staffAdmin)) {
      return [..._adminFaqs, ..._generalFaqs, _contactRegistrarFaq];
    }
    if (hasAnyRole(role, {roleRegistrar})) {
      return [..._registrarFaqs, ..._generalFaqs];
    }
    if (hasAnyRole(role, {roleAccounting})) {
      return [..._accountingFaqs, ..._generalFaqs, _contactRegistrarFaq];
    }
    if (hasAnyRole(role, {roleTeacher})) {
      return [..._teacherFaqs, ..._generalFaqs, _contactRegistrarFaq];
    }
    return [..._generalFaqs, _contactRegistrarFaq];
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;
    final faqs = _faqsForRole(role);

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.headingDark),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
        children: [
          _SectionLabel('Frequently asked questions'),
          const SizedBox(height: 8),
          _FaqCard(faqs: faqs),
          const SizedBox(height: AppSpacing.interCardGap),
          _SectionLabel('Contact'),
          const SizedBox(height: 8),
          _ContactCard(
            isRegistrar: hasAnyRole(role, {roleRegistrar}),
            onEmail: () => _launch(
              context,
              Uri(scheme: 'mailto', path: 'support@slis.edu.ph', query: 'subject=ASIA Mobile App Support'),
            ),
            onCall: () => _launch(context, Uri(scheme: 'tel', path: '+63212345678')),
          ),
          const SizedBox(height: AppSpacing.interCardGap),
          _SectionLabel('About'),
          const SizedBox(height: 8),
          const _AboutCard(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.labelUppercase2,
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.faqs});

  final List<_FaqEntry> faqs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Column(
          children: [
            for (var i = 0; i < faqs.length; i++)
              Container(
                decoration: BoxDecoration(
                  border: i < faqs.length - 1
                      ? const Border(bottom: BorderSide(color: AppColors.rowDivider))
                      : null,
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedAlignment: Alignment.centerLeft,
                  iconColor: AppColors.primary,
                  collapsedIconColor: AppColors.textMuted3,
                  title: Text(
                    faqs[i].question,
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                  ),
                  children: [
                    Text(
                      faqs[i].answer,
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted1, height: 1.4),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.isRegistrar, required this.onEmail, required this.onCall});

  final bool isRegistrar;
  final VoidCallback onEmail;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ContactRow(
            icon: Icons.email_outlined,
            label: 'Email IT Support',
            subtitle: 'support@slis.edu.ph',
            onTap: onEmail,
            showDivider: true,
          ),
          _ContactRow(
            icon: Icons.call_outlined,
            // A registrar viewing this screen already is that office, so
            // "call the Registrar's office" would point at themselves.
            label: isRegistrar ? 'Call IT Support' : 'Call the Registrar\'s Office',
            subtitle: '+63 2 123 4567',
            onTap: onCall,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.showDivider,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: showDivider ? const Border(bottom: BorderSide(color: AppColors.rowDivider)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(AppRadii.iconChipLarge),
              ),
              child: Icon(icon, size: 14, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                  ),
                  const SizedBox(height: 1),
                  Text(subtitle, style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 13, color: Color(0xFFD0B0B0)),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.neutralPillBg,
                borderRadius: BorderRadius.circular(AppRadii.iconChipLarge),
              ),
              child: const Icon(Icons.info_outline, size: 14, color: AppColors.neutralPillText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ASIA Mobile',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                  ),
                  Text(
                    'South Lakes Integrated School',
                    style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted3),
                  ),
                ],
              ),
            ),
            Text('v1.0.0', style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted3)),
          ],
        ),
      ),
    );
  }
}
