import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lawn_estimator/features/ads/ad_config.dart';
import 'package:lawn_estimator/features/ads/ads_service.dart';
import 'package:lawn_estimator/features/billing/billing_service.dart';

/// Bottom banner slot for the free tier.
///
/// Drop into a Scaffold as `bottomNavigationBar: const AdBannerSlot()`.
/// Renders nothing (zero height) when the user is Pro, and collapses while
/// the ad is loading or if it fails to load — the app layout never shows an
/// empty ad box.
class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({super.key});

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (AdsService.instance.adsEnabled) {
      _load();
    }
    BillingService.instance.addListener(_onBillingChanged);
  }

  void _onBillingChanged() {
    // User upgraded mid-session: drop the ad immediately.
    if (!AdsService.instance.adsEnabled && mounted) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _loaded = false;
      setState(() {});
    }
  }

  void _load() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _loaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    BillingService.instance.removeListener(_onBillingChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BillingService.instance,
      builder: (context, _) {
        if (!AdsService.instance.adsEnabled || !_loaded || _bannerAd == null) {
          return const SizedBox.shrink();
        }
        return SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: AdSize.banner.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        );
      },
    );
  }
}
