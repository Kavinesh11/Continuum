import 'package:flutter/material.dart';
import '../state/demo_state.dart';
import '../theme/app_theme.dart';

/// Top-of-screen banner shown when a demo flag is active.
/// Listens to [DemoState] and disappears when no flags are set.
class DemoBanner extends StatelessWidget {
  const DemoBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DemoState.instance,
      builder: (context, _) {
        final demo = DemoState.instance;
        final messages = <_BannerSpec>[];

        if (demo.killSwitchActive) {
          messages.add(
            const _BannerSpec(
              text: 'PAYOUT_KILL_SWITCH active — payouts paused for safety review',
              color: AppTheme.dangerRed,
              icon: Icons.security_rounded,
            ),
          );
        }
        if (demo.reserveFloorBreached) {
          messages.add(
            const _BannerSpec(
              text: 'Reserve runway 87 days — autopay paused on new policies',
              color: AppTheme.warningOrange,
              icon: Icons.account_balance_wallet_outlined,
            ),
          );
        }
        if (demo.zoneEnrollmentLocked) {
          messages.add(
            const _BannerSpec(
              text: 'Zone enrollment locked — adverse selection guard active',
              color: AppTheme.warningOrange,
              icon: Icons.location_off_rounded,
            ),
          );
        }

        if (messages.isEmpty) return const SizedBox.shrink();

        return Column(
          children: messages
              .map(
                (m) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: m.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: m.color.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(m.icon, color: m.color, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.text,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: m.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _BannerSpec {
  final String text;
  final Color color;
  final IconData icon;

  const _BannerSpec({
    required this.text,
    required this.color,
    required this.icon,
  });
}
