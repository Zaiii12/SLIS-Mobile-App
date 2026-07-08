import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/state/auth_provider.dart';
import '../data/dashboard_repository.dart';
import '../models/dashboard_data.dart';
import 'widgets/announcements_card.dart';
import 'widgets/attendance_card.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/pending_enrollment_card.dart';
import 'widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = DashboardRepository();
  late Future<DashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _repository.fetch();
  }

  Future<void> _refresh() async {
    final data = await _repository.fetch();
    setState(() => _dataFuture = Future.value(data));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 74,
        title: FutureBuilder<DashboardData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            final schoolYear = snapshot.data?.schoolYear ?? '';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$schoolYear · ${DateFormat('EEE, MMMM d').format(today)}',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dashboard',
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingDark,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.avatarGradientStart, AppColors.avatarGradientEnd],
                  ),
                ),
                child: Center(
                  child: Text(
                    user?.initials ?? '?',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<DashboardData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Total Students',
                          value: '${data.totalStudents}',
                          icon: Icons.groups_outlined,
                          pill: StatPill(
                            label: '${data.activeStudents} active',
                            background: AppColors.successBg,
                            textColor: AppColors.successText,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.statGridGap),
                      Expanded(
                        child: StatCard(
                          label: 'Enrolled S.Y.',
                          value: '${data.enrolledThisYear}',
                          icon: Icons.calendar_month_outlined,
                          pill: StatPill(
                            label: data.schoolYear,
                            background: AppColors.neutralPillBg,
                            textColor: AppColors.neutralPillText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.statGridGap),
                  PendingEnrollmentCard(value: data.pendingEnrollment),
                  const SizedBox(height: AppSpacing.interCardGap),
                  AttendanceCard(attendance: data.attendance, date: today),
                  const SizedBox(height: AppSpacing.interCardGap),
                  AnnouncementsCard(announcements: data.announcements),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const DashboardBottomNavBar(),
    );
  }
}
