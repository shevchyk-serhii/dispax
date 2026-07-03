import 'dart:convert';
import '../modules/core/services/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../l10n/app_localizations.dart';
import '../utils/parse_amount.dart';
import 'gdpr_screen.dart';
import 'session_management_screen.dart';

// Left-nav item descriptor
class _NavItem {
  final String label;
  final IconData icon;

  const _NavItem(this.label, this.icon);
}

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  int _activeNav = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  Object? _error;

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

  List<_NavItem> _buildNavItems(AppLocalizations l10n) => [
    _NavItem(l10n.navItemCompany, Icons.business_outlined),
    _NavItem(l10n.navItemUsersRoles, Icons.people_outline),
    _NavItem(l10n.navItemCompliance, Icons.security_outlined),
    _NavItem(l10n.navItemBillingDatev, Icons.receipt_long_outlined),
    _NavItem(l10n.navItemGeofences, Icons.map_outlined),
  ];

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
      // The screen may have been closed while the requests were in flight —
      // touching controllers/setState on a disposed State crashes.
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e;
      });
    }
  }

  /// Reads a money/rate field accepting both "12.50" and the German "12,50".
  /// An empty field means 0; garbage returns null so the save can abort
  /// instead of silently zeroing the value.
  double? _amountOf(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return 0;
    return parseAmount(text);
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;

    final commissionRate = _amountOf(_commissionController);
    final cancellationFee = _amountOf(_cancellationFeeController);
    final noShowFee = _amountOf(_noShowFeeController);
    final basePrice = _amountOf(_basePriceController);
    final pricePerKm = _amountOf(_pricePerKmController);
    final airportSurcharge = _amountOf(_airportSurchargeController);
    final nightSurcharge = _amountOf(_nightSurchargeController);
    final amounts = [
      commissionRate,
      cancellationFee,
      noShowFee,
      basePrice,
      pricePerKm,
      airportSurcharge,
      nightSurcharge,
    ];
    if (amounts.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.invalidAmountError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final apiClient = context.read<AuthBloc>().apiClient;

      final datevSachkontenlaengeRaw = _datevSachkontenlaengeController.text
          .trim();
      final datevSachkontenlaenge = datevSachkontenlaengeRaw.isNotEmpty
          ? int.tryParse(datevSachkontenlaengeRaw)
          : null;

      final settingsPayload = <String, dynamic>{
        'commissionRate': commissionRate,
        'defaultCurrency': _defaultCurrencyController.text,
        'cancellationFee': cancellationFee,
        'noShowFee': noShowFee,
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
        'basePrice': basePrice,
        'pricePerKm': pricePerKm,
        'airportSurcharge': airportSurcharge,
        'nightSurcharge': nightSurcharge,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.settingsSavedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToSaveSettings(
                friendlyError(e, AppLocalizations.of(context)!),
              ),
            ),
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
    final l10n = AppLocalizations.of(context)!;
    final navItems = _buildNavItems(l10n);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= AppDimensions.breakpointDesktop;

    return Column(
      children: [
        _buildGraphiteHeader(l10n),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator.adaptive())
              : _error != null
              ? _buildError(l10n)
              : isDesktop
              ? _buildDesktopLayout(l10n, navItems)
              : _buildMobileContent(l10n, navItems),
        ),
      ],
    );
  }

  // --- Graphite header ---

  Widget _buildGraphiteHeader(AppLocalizations l10n) {
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
                Expanded(
                  child: Text(
                    l10n.companySettingsTitle,
                    style: const TextStyle(
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

  // --- Error state ---

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(friendlyError(_error, l10n)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadSettings, child: Text(l10n.retry)),
        ],
      ),
    );
  }

  // --- Desktop layout: left nav + content ---

  Widget _buildDesktopLayout(AppLocalizations l10n, List<_NavItem> navItems) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLeftNav(l10n, navItems),
        const VerticalDivider(width: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: _buildNavContent(l10n, navItems),
          ),
        ),
      ],
    );
  }

  Widget _buildLeftNav(AppLocalizations l10n, List<_NavItem> navItems) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 220,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < navItems.length; i++)
            _buildNavTile(i, isDark, navItems),
        ],
      ),
    );
  }

  Widget _buildNavTile(int index, bool isDark, List<_NavItem> navItems) {
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
                navItems[index].icon,
                size: 18,
                color: isActive
                    ? AppColors.accent
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                navItems[index].label,
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

  Widget _buildNavContent(AppLocalizations l10n, List<_NavItem> navItems) {
    switch (_activeNav) {
      case 0:
        return _buildCompanyProfileContent(l10n);
      case 2:
        return _buildComplianceContent(l10n);
      case 3:
        return _buildBillingContent(l10n);
      default:
        return _buildComingSoon(l10n, navItems[_activeNav].label);
    }
  }

  // --- Mobile fallback: scrollable content ---

  Widget _buildMobileContent(AppLocalizations l10n, List<_NavItem> navItems) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle(l10n.settingsCompanyProfile),
        const SizedBox(height: 16),
        _buildProfileFormGrid(l10n),
        const SizedBox(height: 24),
        _buildSectionTitle(l10n.complianceSectionTitle),
        const SizedBox(height: 12),
        _buildComplianceCards(l10n),
        const SizedBox(height: 24),
        _buildSectionTitle(l10n.generalSettingsSectionTitle),
        const SizedBox(height: 12),
        _buildTextField(
          _commissionController,
          l10n.commissionRateLabel,
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _cancellationFeeController,
          l10n.cancellationFeeSettingsLabel,
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _noShowFeeController,
          l10n.noShowFeeLabel,
          TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildTimePickers(l10n),
        const SizedBox(height: 24),
        _buildSectionTitle(l10n.tariffSettingsSectionTitle),
        const SizedBox(height: 12),
        _buildTextField(
          _basePriceController,
          l10n.basePriceLabel,
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _pricePerKmController,
          l10n.pricePerKmLabel,
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _airportSurchargeController,
          l10n.airportSurchargeLabel,
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _nightSurchargeController,
          l10n.nightSurchargeLabel,
          TextInputType.number,
        ),
        const SizedBox(height: 24),
        _buildSaveButtons(l10n),
        const SizedBox(height: 24),
      ],
    );
  }

  // --- Company Profile section ---

  Widget _buildCompanyProfileContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.companyProfileSectionTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.companyProfileSubtitle,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _buildProfileFormGrid(l10n),
        const SizedBox(height: 32),
        _buildSaveButtons(l10n),
      ],
    );
  }

  Widget _buildProfileFormGrid(AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 560;
        if (twoCol) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildFormField(
                      _legalNameController,
                      l10n.legalNameLabel,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFormField(_vatIdController, l10n.vatIdLabel),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildFormField(
                      _defaultCurrencyController,
                      l10n.defaultCurrencyLabel,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFormField(
                      _timezoneController,
                      l10n.timezoneLabel,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Column(
          children: [
            _buildFormField(_legalNameController, l10n.legalNameLabel),
            const SizedBox(height: 12),
            _buildFormField(_vatIdController, l10n.vatIdLabel),
            const SizedBox(height: 12),
            _buildFormField(
              _defaultCurrencyController,
              l10n.defaultCurrencyLabel,
            ),
            const SizedBox(height: 12),
            _buildFormField(_timezoneController, l10n.timezoneLabel),
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

  // --- Compliance section ---

  Widget _buildComplianceContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.complianceSectionTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.complianceSubtitle,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _buildComplianceCards(l10n),
      ],
    );
  }

  Widget _buildComplianceCards(AppLocalizations l10n) {
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
            title: l10n.gdprExportTitle,
            subtitle: l10n.gdprExportSubtitle,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GdprScreen()),
            ),
          ),
          _ComplianceCard(
            icon: Icons.history_outlined,
            iconBg: isDark ? AppColors.rideAssignedBgDark : AppColors.infoBg,
            iconColor: const Color(0xFF3B82F6),
            title: l10n.auditLogTitle,
            subtitle: l10n.auditLogSubtitle,
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
            title: l10n.activeSessionsCardTitle,
            subtitle: l10n.activeSessionsCardSubtitle,
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
            title: l10n.blacklistCardTitle,
            subtitle: l10n.blacklistCardSubtitle,
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

  // --- Billing & DATEV section ---

  Widget _buildBillingContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.billingDatevSectionTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.billingDatevSubtitle,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(l10n.tariffSettingsSectionTitle),
        const SizedBox(height: 12),
        _buildTextField(
          _basePriceController,
          l10n.basePriceLabel,
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _pricePerKmController,
          l10n.pricePerKmLabel,
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _airportSurchargeController,
          l10n.airportSurchargeLabel,
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _nightSurchargeController,
          l10n.nightSurchargeLabel,
          TextInputType.number,
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(l10n.datevIntegrationSectionTitle),
        const SizedBox(height: 4),
        Text(
          l10n.datevIntegrationSubtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        // DATEV technical labels intentionally hardcoded (German field names)
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
        _buildSaveButtons(l10n),
      ],
    );
  }

  // --- Coming soon placeholder ---

  Widget _buildComingSoon(AppLocalizations l10n, String label) {
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
              l10n.comingSoonLabel(label),
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

  // --- Shared field / section helpers ---

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

  Widget _buildTimePickers(AppLocalizations l10n) {
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
              decoration: InputDecoration(
                labelText: l10n.workStartLabel,
                border: const OutlineInputBorder(),
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
              decoration: InputDecoration(
                labelText: l10n.workEndLabel,
                border: const OutlineInputBorder(),
              ),
              child: Text(_workEnd.format(context)),
            ),
          ),
        ),
      ],
    );
  }

  // --- Cancel / Save buttons ---

  Widget _buildSaveButtons(AppLocalizations l10n) {
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
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 14)),
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
                : Text(l10n.save, style: const TextStyle(fontSize: 14)),
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
