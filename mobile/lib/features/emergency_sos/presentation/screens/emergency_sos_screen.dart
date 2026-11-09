import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/camp_bottom_nav.dart';
import '../widgets/emergency_contact_card.dart';
import '../widgets/emergency_dispatch_card.dart';
import '../widgets/offline_medical_id_card.dart';
import '../widgets/sos_header_bar.dart';
import '../widgets/sos_hold_button.dart';
import '../widgets/sos_location_card.dart';

/// CAMP Emergency SOS Screen
/// Honest emergency assistance screen backed exclusively by phone GPS and cellular dialer/SMS.
class EmergencySosScreen extends StatelessWidget {
  const EmergencySosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.clay,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Color(0xFFF3F5F9),
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 1. Top Header Bar (Back button, CAMP •, SOS READY badge)
                  SosHeaderBar(),

                  // 2. Scrollable Cards Stream
                  Expanded(
                    child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card 1: Concentric SOS Trigger Button & Signal Pill
                          SosHoldButton(),

                          SizedBox(height: 14),

                          // Card 2: Current Location & Topographic Preview
                          SosLocationCard(),

                          SizedBox(height: 14),

                          // Card 3: Emergency Response Services Picker & Dialer (1122 default)
                          EmergencyDispatchCard(),

                          SizedBox(height: 14),

                          // Card 4: Emergency Contact (Call & SMS GPS Alert, or Empty State)
                          EmergencyContactCard(),

                          SizedBox(height: 14),

                          // Card 5: Offline Medical ID
                          OfflineMedicalIdCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Floating Bottom Navigation Dock (Unselected state)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: CampBottomNav(
                  selected: null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
