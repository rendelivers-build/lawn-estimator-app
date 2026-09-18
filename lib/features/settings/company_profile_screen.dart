/// Company profile screen: the owner enters their business identity once,
/// and it prints as the letterhead on every estimate.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lawn_estimator/data/estimate_repository.dart';
import 'package:lawn_estimator/models/models.dart';

/// Edits the single company-profile row (id 1).
class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() =>
      _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends ConsumerState<CompanyProfileScreen> {
  final _repo = EstimateRepository();
  late Future<CompanyProfile> _profileFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _repo.loadCompanyProfile();
  }

  Future<void> _save(CompanyProfile profile) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repo.saveCompanyProfile(profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company profile saved.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Save company profile failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company profile')),
      body: FutureBuilder<CompanyProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: const Text('Could not load profile. Try again.'),
            );
          }
          return _ProfileForm(
            initial: snapshot.data ?? const CompanyProfile(),
            saving: _saving,
            onSave: _save,
          );
        },
      ),
    );
  }
}

/// The editable form. Controllers are created once from the initial profile
/// so typing is never clobbered by rebuilds.
class _ProfileForm extends StatefulWidget {
  final CompanyProfile initial;
  final bool saving;
  final Future<void> Function(CompanyProfile) onSave;

  const _ProfileForm({
    required this.initial,
    required this.saving,
    required this.onSave,
  });

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.businessName,
  );
  late final TextEditingController _street = TextEditingController(
    text: widget.initial.street,
  );
  late final TextEditingController _city = TextEditingController(
    text: widget.initial.city,
  );
  late final TextEditingController _state = TextEditingController(
    text: widget.initial.state,
  );
  late final TextEditingController _zip = TextEditingController(
    text: widget.initial.zip,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initial.phone,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.initial.email,
  );
  late final TextEditingController _laborRate = TextEditingController(
    text: widget.initial.laborRate > 0
        ? _trimNumber(widget.initial.laborRate)
        : '',
  );

  @override
  void dispose() {
    _name.dispose();
    _street.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _phone.dispose();
    _email.dispose();
    _laborRate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'This prints at the top of every estimate as your letterhead. '
              'Fill in what you want customers to see.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        _field(_name, 'Business name'),
        const SizedBox(height: 12),
        _field(_street, 'Street address'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(flex: 3, child: _field(_city, 'City')),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _field(_state, 'State')),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _field(_zip, 'ZIP')),
          ],
        ),
        const SizedBox(height: 12),
        _field(
          _phone,
          'Phone',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _field(
          _email,
          'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _field(
          _laborRate,
          'Labor rate (USD per man-hour)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: widget.saving
              ? null
              : () => widget.onSave(
                    CompanyProfile(
                      businessName: _name.text.trim(),
                      street: _street.text.trim(),
                      city: _city.text.trim(),
                      state: _state.text.trim(),
                      zip: _zip.text.trim(),
                      phone: _phone.text.trim(),
                      email: _email.text.trim(),
                      laborRate:
                          double.tryParse(_laborRate.text.trim()) ?? 0,
                    ),
                  ),
          child: Text(widget.saving ? 'Saving…' : 'Save company profile'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  static String _trimNumber(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}
