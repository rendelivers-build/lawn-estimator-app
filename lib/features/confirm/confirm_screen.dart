/// Confirmation screen: one camera photo proves the outlined area matches
/// the real lawn. The photo is stored in the app's private documents
/// directory and never leaves the device.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:lawn_estimator/core/units.dart';
import 'package:lawn_estimator/features/measure/draft_provider.dart';

class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key});

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  final _noteController = TextEditingController();
  bool _takingPhoto = false;
  bool _photoAccepted = false;
  bool _matchesLawn = false;

  @override
  void initState() {
    super.initState();
    _noteController.text = ref.read(estimateDraftProvider).note ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Captures a photo and saves a copy into the app documents directory
  /// under a random filename, then records it on the draft.
  Future<void> _takePhoto() async {
    if (_takingPhoto) return;
    setState(() => _takingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) {
        // User cancelled the camera.
        if (mounted) setState(() => _takingPhoto = false);
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final saved = await File(picked.path)
          .copy('${dir.path}/${const Uuid().v4()}.jpg');
      ref.read(estimateDraftProvider.notifier).setPhoto(saved.path);
      if (!mounted) return;
      setState(() {
        _takingPhoto = false;
        // A fresh photo must be reviewed and re-confirmed.
        _photoAccepted = false;
        _matchesLawn = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _takingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Could not take photo. Try again.')),
      );
    }
  }

  void _continue({required bool confirmed}) {
    ref.read(estimateDraftProvider.notifier).setConfirmed(confirmed);
    Navigator.pushNamed(context, '/materials');
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(estimateDraftProvider);
    final photoPath = draft.photoPath;
    final canContinueWithPhoto = photoPath != null &&
        _photoAccepted &&
        _matchesLawn &&
        !_takingPhoto;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm lawn')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(draft),
          const SizedBox(height: 12),
          const Text(
            'Take one photo to confirm the lawn you outlined. '
            'The photo stays in this app on this device.',
          ),
          const SizedBox(height: 12),
          if (photoPath == null) _buildTakePhotoButton() else _buildPhotoCard(photoPath),
          if (photoPath != null && _photoAccepted) _buildMatchCheckbox(),
          const SizedBox(height: 8),
          _buildNoteField(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed:
                canContinueWithPhoto ? () => _continue(confirmed: true) : null,
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => _continue(confirmed: false),
            child: const Text('Continue without photo'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(EstimateDraft draft) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.grass),
        title: Text(formatFt2(draft.totalAreaFt2)),
        subtitle: Text(draft.addressLabel ?? 'No address'),
      ),
    );
  }

  Widget _buildTakePhotoButton() {
    return ElevatedButton.icon(
      onPressed: _takingPhoto ? null : _takePhoto,
      icon: _takingPhoto
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.camera_alt),
      label: Text(_takingPhoto ? 'Opening camera…' : 'Take photo'),
    );
  }

  Widget _buildPhotoCard(String photoPath) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.file(
            File(photoPath),
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 220,
              child: Center(
                child: Text('Could not load the photo. Please retake it.'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _photoAccepted
                ? Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _takingPhoto ? null : _takePhoto,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake'),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: _takingPhoto ? null : _takePhoto,
                        child: const Text('Retake'),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            setState(() => _photoAccepted = true),
                        child: const Text('Keep'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCheckbox() {
    return CheckboxListTile(
      value: _matchesLawn,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: const Text('The outlined area matches the lawn shown.'),
      onChanged: (value) => setState(() => _matchesLawn = value ?? false),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Note (optional)',
        hintText: 'e.g. steep slope on the north side',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) => ref
          .read(estimateDraftProvider.notifier)
          .setNote(value.isEmpty ? null : value),
    );
  }
}
