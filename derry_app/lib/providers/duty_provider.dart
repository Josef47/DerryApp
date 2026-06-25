import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/duty_model.dart';
import '../services/duty_service.dart';

final dutyServiceProvider = Provider<DutyService>((ref) => DutyService());

final dutyZonesProvider = StreamProvider<List<DutyZoneModel>>((ref) {
  return ref.watch(dutyServiceProvider).watchZones();
});

final currentWeekAssignmentsProvider =
    StreamProvider<List<DutyAssignmentModel>>((ref) {
  final weekLabel = AppConstants.currentWeekLabel();
  return ref.watch(dutyServiceProvider).watchAssignmentsForWeek(weekLabel);
});
