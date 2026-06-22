import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import 'gdpr_screen.dart';
import 'session_management_screen.dart';

// Left-nav item descriptor
class _NavItem {
  final String label;
  final IconData icon;

  const _NavItem(this.label, this.icon);
}

const _navItems = [
  _NavItem('Company', Icons.business_outlined),
  _NavItem('Users & Roles', Icons.people_outline),
  _NavItem('Compliance', Icons.security_outlined),
  _NavItem('Billing & DATEV', Icons.receipt_long_outlined),
  _NavItem('Geofences', Icons.map_outlined),
];

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  int _activeNav = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Company profile fields
  final _legalNameController = TextEditingController();
  final _vatIdController = TextEditingController();
  final _defaultCurrencyController = TextEditingController(text: 'EUR');
  final _timezoneController = TextEditingController(text: 'Europe/Berlin');

  // Company settings fields (loaded alongside profile)
  final _commissionController = TextEditingController();
  final _cancellationFeeController = TextEditingController();
  final _noShowFeeController = TextEditingController();
  TimeOfDay _workStart = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 22, minute: 0);

  // Tariff fields
  final _basePriceController = TextEditingController();
  final _pricePerKmController = TextEditingController();
  final _airportSurchargeController = TextEditingController();
  final _nightSurchargeController = TextEditingController();

  // DATEV fields
  final _datevBeraternummerController = TextEditingController();
  final _datevMandantennummerController = TextEditingController();
  final _datevSachkontenlaengeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _legalNameController.dispose();
    _vatIdController.dispose();
    _defaultCurrencyController.dispose();
    _timezoneController.dispose();
    _commissionController.dispose();
    _cancellationFeeController.dispose();
    _noShowFeeController.dispose();
    _basePriceController.dispose();
    _pricePerKmController.dispose();
    _airportSurchargeController.dispose();
    _nightSurchargeController.dispose();
    _datevBeraternummerController.dispose();
    _datevMandantennummerController.dispose();
    _datevSachkontenlaengeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final results = await Future.wait([
        apiClient.get('/company/settings'),
        apiClient.get('/company/tariff'),
      ]);
      final settingsResponse = results[0];
      final tariffResponse = results[1];

      if (settingsResponse.statusCode == 200) {
        final settings = jsonDecode(settingsResponse.body);
        // Company profile fields
        _legalNameController.text = settings['legalName'] as String? ?? '';
        _vatIdController.text = settings['vatId'] as String? ?? '';
        _defaultCurrencyController.text =
            settings['defaultCurrency'] as String? ?? 'EUR';
        _timezoneController.text =
            settings['timezone'] as String? ?? 'Europe/Berlin';
        // Other settings
        _commissionController.text = (settings['commissionRate'] ?? 0)
            .toString();
        _cancellationFeeController.text = (settings['cancellationFee'] ?? 0)
            .toString();
        _noShowFeeController.text = (settings['noShowFee'] ?? 0).toString();
        if (settings['workStartHour'] != null) {
          _workStart = TimeOfDay(
            hour: settings['workStartHour'] as int,
            minute: (settings['workStartMinute'] as int?) ?? 0,
          );
        }
        if (settings['workEndHour'] != null) {
          _workEnd = TimeOfDay(
            hour: settings['workEndHour'] as int,
            minute: (settings['workEndMinute'] as int?) ?? 0,
          );
        }
        _datevBeraternummerController.text =
            settings['datevBeraternummer'] as String? ?? '';
        _datevMandantennummerController.text =
            settings['datevMandantennummer'] as String? ?? '';
        _datevSachkontenlaengeController.text =
            (settings['datevSachkontenlaenge'] as int?)?.toString() ?? '';
      }

      if (tariffResponse.statusCode == 200) {
        final tariff = jsonDecode(tariffResponse.body);
        _basePriceController.text = (tariff['basePrice'] ?? 0).toString();
        _pricePerKmController.text = (tariff['pricePerKm'] ?? 0).toString();
        _airportSurchargeController.text = (tariff['airportSurcharge'] ?? 0)
            .toString();
        _nightSurchargeController.text = (tariff['nightSurcharge'] ?? 0)
            .toString();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final apiClient = context.read<AuthBloc>().apiClient;

      final datevSachkontenlaengeRaw = _datevSachkontenlaengeController.text
          .trim();
      final datevSachkontenlaenge = datevSachkontenlaengeRaw.isNotEmpty
          ? int.tryParse(datevSachkontenlaengeRaw)
          : null;

      final settingsPayload = <String, dynamic>{
        'commissionRate': double.tryParse(_commissionController.text) ?? 0,
        'defaultCurrency': _defaultCurrencyController.text,
        'cancellationFee':
            double.tryParse(_cancellationFeeController.text) ?? 0,
        'noShowFee': double.tryParse(_noShowFeeController.text) ?? 0,
        'workStartHour': _workStart.hour,
        'workStartMinute': _workStart.minute,
        'workEndHour': _workEnd.hour,
        'workEndMinute': _workEnd.minute,
        // Company profile fields — send if present
        if (_legalNameController.text.isNotEmpty)
          'legalName': _legalNameController.text,
        if (_vatIdController.text.isNotEmpty) 'vatId': _vatIdController.text,
        if (_timezoneController.text.isNotEmpty)
          'timezone': _timezoneController.text,
      };

      final datevBeraternummer = _datevBeraternummerController.text.trim();
      final datevMandantennummer = _datevMandantennummerController.text.trim();
      if (datevBeraternummer.isNotEmpty) {
        settingsPayload['datevBeraternummer'] = datevBeraternummer;
      }
      if (datevMandantennummer.isNotEmpty) {
        settingsPayload['datevMandantennummer'] = datevMandantennummer;
      }
      if (datevSachkontenlaenge != null) {
        settingsPayload['datevSachkontenlaenge'] = datevSachkontenlaenge;
      }

      await apiClient.put('/company/settings', settingsPayload);

      await apiClient.put('/company/tariff', {
        'basePrice': double.tryParse(_basePriceController.text) ?? 0,
        'pricePerKm': double.tryParse(_pricePerKmController.text) ?? 0,
        'airportSurcharge':
            double.tryParse(_airportSurchargeController.text) ?? 0,
        'nightSurcharge': double.tryParse(_nightSurchargeController.text) ?? 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= AppDimensions.breakpointDesktop;

    return Column(
      children: [
        _buildGraphiteHeader(isDesktop),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator.adaptive())
              : _error != null
              ? _buildError()
              : isDesktop
              ? _buildDesktopLayout()
              : _buildMobileContent(),
        ),
      ],
    );
  }

  // ─── Graphite header ──────────────────────────────────────────────────────

  Widget _buildGraphiteHeader(bool isDesktop) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Company Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (_isSaving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.save_outlined, color: Colors.white),
                    onPressed: _saveSettings,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Error state ──────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(_error!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadSettings, child: const Text('Retry')),
        ],
      ),
    );
  }

  // ─── Desktop layout: left nav + content ──────────────────────────────────

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLeftNav(),
        const VerticalDivider(width: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: _buildNavContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildLeftNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 220,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _navItems.length; i++) _buildNavTile(i, isDark),
        ],
      ),
    );
  }

  Widget _buildNavTile(int index, bool isDark) {
    final isActive = _activeNav == index;
    return GestureDetector(
      onTap: () => setState(() => _activeNav = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withAlpha(isDark ? 30 : 20)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border(
                  left: const BorderSide(color: AppColors.accent, width: 3),
                )
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(isActive ? 9 : 12, 10, 12, 10),
          child: Row(
            children: [
              Icon(
                _navItems[index].icon,
                size: 18,
                color: isActive
                    ? AppColors.accent
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                _navItems[index].label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? AppColors.accent
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavContent() {
    switch (_activeNav) {
      case 0:
        return _buildCompanyProfileContent();
      case 2:
        return _buildComplianceContent();
      case 3:
        return _buildBillingContent();
      default:
        return _buildComingSoon(_navItems[_activeNav].label);
    }
  }

  // ─── Mobile fallback: scrollable content ─────────────────────────────────

  Widget _buildMobileContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Company Profile'),
        const SizedBox(height: 16),
        _buildProfileFormGrid(),
        const SizedBox(height: 24),
        _buildSectionTitle('Compliance & Security'),
        const SizedBox(height: 12),
        _buildComplianceCards(),
        const SizedBox(height: 24),
        _buildSectionTitle('General Settings'),
        const SizedBox(height: 12),
        _buildTextField(
          _commissionController,
          'Commission Rate (%)',
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _cancellationFeeController,
          'Cancellation Fee (€)',
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _noShowFeeController,
          'No-Show Fee (€)',
          TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildTimePickers(),
        const SizedBox(height: 24),
        _buildSectionTitle('Tariff Settings'),
        const SizedBox(height: 12),
        _buildTextField(
          _basePriceController,
          'Base Price (€)',
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _pricePerKmController,
          'Price per Km (€)',
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _airportSurchargeController,
          'Airport Surcharge (€)',
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _nightSurchargeController,
          'Night Surcharge (€)',
          TextInputType.number,
        ),
        const SizedBox(height: 24),
        _buildSaveButtons(),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Company Profile section ──────────────────────────────────────────────

  Widget _buildCompanyProfileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Company profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Legal entity information displayed on invoices and reports.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _buildProfileFormGrid(),
        const SizedBox(height: 32),
        _buildSaveButtons(),
      ],
    );
  }

  Widget _buildProfileFormGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 560;
        if (twoCol) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildFormField(_legalNameController, 'Legal name'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildFormField(_vatIdController, 'VAT ID')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildFormField(
                      _defaultCurrencyController,
                      'Default currency',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFormField(_timezoneController, 'Timezone'),
                  ),
                ],
              ),
            ],
          );
        }
        return Column(
          children: [
            _buildFormField(_legalNameController, 'Legal name'),
            const SizedBox(height: 12),
            _buildFormField(_vatIdController, 'VAT ID'),
            const SizedBox(height: 12),
            _buildFormField(_defaultCurrencyController, 'Default currency'),
            const SizedBox(height: 12),
            _buildFormField(_timezoneController, 'Timezone'),
          ],
        );
      },
    );
  }

  Widget _buildFormField(TextEditingController ctrl, String label) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borderPrimary),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borderPrimary),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
      ),
    );
  }

  // ─── Compliance section ───────────────────────────────────────────────────

  Widget _buildComplianceContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compliance & Security',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Data privacy, access management, and audit controls.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _buildComplianceCards(),
      ],
    );
  }

  Widget _buildComplianceCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final twoCol = constraints.maxWidth >= 480;
        final cards = [
          _ComplianceCard(
            icon: Icons.download_outlined,
            iconBg: isDark
                ? AppColors.rideCompletedBgDark
                : AppColors.successBg,
            iconColor: const Color(0xFF22C55E),
            title: 'GDPR export',
            subtitle: 'Download all personal data',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GdprScreen()),
            ),
          ),
          _ComplianceCard(
            icon: Icons.history_outlined,
            iconBg: isDark ? AppColors.rideAssignedBgDark : AppColors.infoBg,
            iconColor: const Color(0xFF3B82F6),
            title: 'Audit log',
            subtitle: 'Review system activity',
            onTap: null, // TODO: audit log screen not yet implemented
          ),
          _ComplianceCard(
            icon: Icons.devices_outlined,
            iconBg: isDark
                ? AppColors.surfaceVariantDark
                : AppColors.primarySurface,
            iconColor: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
            title: 'Active sessions',
            subtitle: 'Manage logged-in devices',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SessionManagementScreen(),
              ),
            ),
          ),
          _ComplianceCard(
            icon: Icons.block_outlined,
            iconBg: isDark ? AppColors.rideCancelledBgDark : AppColors.errorBg,
            iconColor: const Color(0xFFEF4444),
            title: 'Blacklist',
            subtitle: 'Manage blocked accounts',
            onTap: null, // TODO: blacklist screen not yet implemented
          ),
        ];

        if (twoCol) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildComplianceCardWidget(cards[0])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildComplianceCardWidget(cards[1])),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildComplianceCardWidget(cards[2])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildComplianceCardWidget(cards[3])),
                ],
              ),
            ],
          );
        }
        return Column(
          children: cards
              .map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildComplianceCardWidget(c),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildComplianceCardWidget(_ComplianceCard card) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canTap = card.onTap != null;
    return GestureDetector(
      onTap: card.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: card.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(card.icon, size: 18, color: card.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: canTap
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (canTap)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            else
              Text(
                'TODO',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Billing & DATEV section ──────────────────────────────────────────────

  Widget _buildBillingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Billing & DATEV',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Tariff configuration and DATEV export settings.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Tariff Settings'),
        const SizedBox(height: 12),
        _buildTextField(
          _basePriceController,
          'Base Price (€)',
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _pricePerKmController,
          'Price per Km (€)',
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _airportSurchargeController,
          'Airport Surcharge (€)',
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _nightSurchargeController,
          'Night Surcharge (€)',
          TextInputType.number,
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('DATEV Integration'),
        const SizedBox(height: 4),
        Text(
          'Beraternummer und Mandantennummer werden im EXTF-Buchungsstapel-Header verwendet.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _datevBeraternummerController,
          'Beraternummer (max. 7 Stellen)',
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _datevMandantennummerController,
          'Mandantennummer (max. 5 Stellen)',
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _datevSachkontenlaengeController,
          'Sachkontenlänge (Standard: 4)',
          TextInputType.number,
        ),
        const SizedBox(height: 32),
        _buildSaveButtons(),
      ],
    );
  }

  // ─── Coming soon placeholder ──────────────────────────────────────────────

  Widget _buildComingSoon(String label) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Icon(
              Icons.construction_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '$label coming soon',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Shared field / section helpers ──────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    TextInputType type,
  ) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildTimePickers() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _workStart,
              );
              if (picked != null) setState(() => _workStart = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Work Start',
                border: OutlineInputBorder(),
              ),
              child: Text(_workStart.format(context)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _workEnd,
              );
              if (picked != null) setState(() => _workEnd = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Work End',
                border: OutlineInputBorder(),
              ),
              child: Text(_workEnd.format(context)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Cancel / Save buttons ────────────────────────────────────────────────

  Widget _buildSaveButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Cancel — outlined graphite
        SizedBox(
          height: 40,
          child: OutlinedButton(
            onPressed: _isSaving ? null : _loadSettings,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.borderSecondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(width: 12),
        // Save — graphite filled
        SizedBox(
          height: 40,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save', style: TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

class _ComplianceCard {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ComplianceCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
