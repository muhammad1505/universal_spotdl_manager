import 'package:flutter/widgets.dart';

import '../../widgets/environment_status_card.dart';

class EnvironmentWarningBanner extends StatelessWidget {
  const EnvironmentWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnvironmentStatusCard(showActions: false);
  }
}
