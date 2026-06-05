import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  final _commissionController = TextEditingController();
  final _defaultCurrencyController = TextEditingController(text: 'EUR');
  final _cancellationFeeController = TextEditingController();
  final _noShowFeeController = TextEditingController();
  TimeOfDay _workStart = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 22, minute: 0);

  final _basePriceController = TextEditingController();
  final _pricePerKmController = TextEditingController();
  final _airportSurchargeController = TextEditingController();
  final _nightSurchargeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _commissionController.dispose();
    _defaultCurrencyController.dispose();
    _cancellationFeeController.dispose();
    _noShowFeeController.dispose();
    _basePriceController.dispose();
    _pricePerKmController.dispose();
    _airportSurchargeController.dispose();
    _nightSurchargeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final settingsResponse = await apiClient.get('/company/settings');
      final tariffResponse = await apiClient.get('/company/tariff');

      if (settingsResponse.statusCode == 200) {
        final settings = jsonDecode(settingsResponse.body);
        _commissionController.text = (settings['commissionRate'] ?? 0).toString();
        _defaultCurrencyController.text = settings['defaultCurrency'] ?? 'EUR';
        _cancellationFeeController.text = (settings['cancellationFee'] ?? 0).toString();
        _noShowFeeController.text = (settings['noShowFee'] ?? 0).toString();
        if (settings['workStartHour'] != null) {
          _workStart = TimeOfDay(hour: settings['workStartHour'], minute: settings['workStartMinute'] ?? 0);
        }
        if (settings['workEndHour'] != null) {
          _workEnd = TimeOfDay(hour: settings['workEndHour'], minute: settings['workEndMinute'] ?? 0);
        }
      }

      if (tariffResponse.statusCode == 200) {
        final tariff = jsonDecode(tariffResponse.body);
        _basePriceController.text = (tariff['basePrice'] ?? 0).toString();
        _pricePerKmController.text = (tariff['pricePerKm'] ?? 0).toString();
        _airportSurchargeController.text = (tariff['airportSurcharge'] ?? 0).toString();
        _nightSurchargeController.text = (tariff['nightSurcharge'] ?? 0).toString();
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

      await apiClient.put('/company/settings', {
        'commissionRate': double.tryParse(_commissionController.text) ?? 0,
        'defaultCurrency': _defaultCurrencyController.text,
        'cancellationFee': double.tryParse(_cancellationFeeController.text) ?? 0,
        'noShowFee': double.tryParse(_noShowFeeController.text) ?? 0,
        'workStartHour': _workStart.hour,
        'workStartMinute': _workStart.minute,
        'workEndHour': _workEnd.hour,
        'workEndMinute': _workEnd.minute,
      });

      await apiClient.put('/company/tariff', {
        'basePrice': double.tryParse(_basePriceController.text) ?? 0,
        'pricePerKm': double.tryParse(_pricePerKmController.text) ?? 0,
        'airportSurcharge': double.tryParse(_airportSurchargeController.text) ?? 0,
        'nightSurcharge': double.tryParse(_nightSurchargeController.text) ?? 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(_error!),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadSettings, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _buildContent(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.dispatcherGradient),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.business, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Company Settings',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (_isSaving)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            else
              IconButton(
                icon: const Icon(Icons.save, color: Colors.white, size: 22),
                onPressed: _saveSettings,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('General Settings'),
        const SizedBox(height: 12),
        _buildTextField(_commissionController, 'Commission Rate (%)', TextInputType.number),
        const SizedBox(height: 12),
        _buildTextField(_defaultCurrencyController, 'Default Currency', TextInputType.text),
        const SizedBox(height: 12),
        _buildTextField(_cancellationFeeController, 'Cancellation Fee (\u20AC)', TextInputType.number),
        const SizedBox(height: 12),
        _buildTextField(_noShowFeeController, 'No-Show Fee (\u20AC)', TextInputType.number),
        const SizedBox(height: 16),
        _buildTimePickers(),
        const SizedBox(height: 24),
        _buildSectionTitle('Tariff Settings'),
        const SizedBox(height: 12),
        _buildTextField(_basePriceController, 'Base Price (\u20AC)', TextInputType.number),
        const SizedBox(height: 12),
        _buildTextField(_pricePerKmController, 'Price per Km (\u20AC)', TextInputType.number),
        const SizedBox(height: 12),
        _buildTextField(_airportSurchargeController, 'Airport Surcharge (\u20AC)', TextInputType.number),
        const SizedBox(height: 12),
        _buildTextField(_nightSurchargeController, 'Night Surcharge (\u20AC)', TextInputType.number),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dispatcherColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, TextInputType type) {
    return TextField(
      controller: controller,
      keyboardType: type,
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
              final picked = await showTimePicker(context: context, initialTime: _workStart);
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
              final picked = await showTimePicker(context: context, initialTime: _workEnd);
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
}
