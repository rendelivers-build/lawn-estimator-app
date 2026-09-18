/// Auto-save for the in-progress estimate draft.
///
/// The draft is written to a small JSON file in the app documents directory
/// whenever it changes (debounced by the caller) and whenever the app is
/// backgrounded. On launch, the home screen offers to resume the saved
/// draft, so an interruption — a phone call, backing out mid-flow, the OS
/// killing the app — never loses the measurement, photo, or pricing work.
library;

import 'dart:convert';
import 'dart:io';

import 'package:lawn_estimator/features/measure/draft_provider.dart';
import 'package:path_provider/path_provider.dart';

const _fileName = 'draft_autosave.json';

Future<File> _draftFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/$_fileName');
}

/// Persists [draft]; deletes the file when there is nothing worth resuming.
Future<void> saveDraft(EstimateDraft draft) async {
  try {
    final file = await _draftFile();
    if (!draft.hasContent) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.writeAsString(jsonEncode(draft.toMap()));
  } catch (_) {
    // Auto-save must never break the estimate flow.
  }
}

/// Loads the auto-saved draft, or null when there is none / it is unusable.
/// Drops the photo reference when its file is gone.
Future<EstimateDraft?> loadDraft() async {
  try {
    final file = await _draftFile();
    if (!await file.exists()) return null;
    final map =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final draft = EstimateDraft.fromMap(map);
    if (draft == null || !draft.hasContent) return null;
    if (draft.photoPath != null &&
        !await File(draft.photoPath!).exists()) {
      return draft.copyWith(clearPhoto: true);
    }
    return draft;
  } catch (_) {
    return null;
  }
}

/// Deletes the auto-saved draft (estimate saved or explicitly discarded).
Future<void> clearDraft() async {
  try {
    final file = await _draftFile();
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Best effort; a stale file just means one more resume prompt.
  }
}
