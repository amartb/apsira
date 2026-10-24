// domain_packages: clock is not on VIATICUM's allowlist.
import 'package:clock/clock.dart';

// forbidden_calls: the system-time group stays.
DateTime now() => DateTime.now();
