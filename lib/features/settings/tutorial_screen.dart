/// First-run tutorial: a short walkthrough of the whole estimating flow,
/// shown once until the user opts out with "Don't show this again".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lawn_estimator/features/settings/app_settings_provider.dart';

/// One tutorial page: icon, title, and body copy.
class _TutorialPage {
  final IconData icon;
  final String title;
  final String body;

  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.body,
  });
}

/// The tutorial pages. Public so tests can guard the locked wording
/// (Brandon's wife's "Hold pins to move" phrasing must stay verbatim).
const tutorialPages = [
  _TutorialPage(
    icon: Icons.search,
    title: 'Find the address',
    body:
        'Type the property address and pick it from the list. '
        'Addresses you use get saved, so repeat jobs are one tap away.',
  ),
  _TutorialPage(
    icon: Icons.map_outlined,
    title: 'Outline the lawn',
    body:
        'In "Draw" mode, tap the satellite map to drop points around the '
        'lawn. Hold pins to move them and fine-tune the outline. '
        'The app measures the area live.',
  ),
  _TutorialPage(
    icon: Icons.camera_alt_outlined,
    title: 'Confirm with a photo',
    body:
        'Snap a photo of the lawn — or the front of the house — so you and '
        'the crew know exactly which lawn was measured.',
  ),
  _TutorialPage(
    icon: Icons.shopping_cart_outlined,
    title: 'Pick materials',
    body:
        'The app does the math for sod, seed, fertilizer, and weed & feed '
        'from your measured area. Open any material or service the first '
        'time to learn what it is, why it matters, and how often it is done. '
        'Each explainer shows once — tap the (i) on any card to see it again.',
  ),
  _TutorialPage(
    icon: Icons.receipt_long_outlined,
    title: 'Price and send',
    body:
        'Add labor and services like mowing, adjust prices, save the '
        'estimate, then print or email a professional-looking invoice.',
  ),
];

/// Full-screen PageView walkthrough with a "Don't show this again" opt-out.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _dontShowAgain = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_dontShowAgain) {
      await ref.read(appSettingsProvider.notifier).setTutorialSeen(true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == tutorialPages.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Lawn Estimator'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: tutorialPages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, index) {
                final page = tutorialPages[index];
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        page.icon,
                        size: 96,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        page.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        page.body,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              tutorialPages.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _dontShowAgain,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 32),
            title: const Text("Don't show this again"),
            onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: last
                    ? _finish
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                child: Text(last ? 'Get started' : 'Next'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
