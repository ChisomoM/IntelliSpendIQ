import 'package:intellispendiq/domain/models/enums.dart';

/// User-facing labels for [BudgetCadence].
abstract final class BudgetCadenceLabels {
  static String title(BudgetCadence cadence) => switch (cadence) {
    BudgetCadence.calendarMonth => 'Calendar month',
    BudgetCadence.payday => 'Payday cycle',
    BudgetCadence.weekly => 'Weekly',
    BudgetCadence.biweekly => 'Every 2 weeks',
    BudgetCadence.everyFourWeeks => 'Every 4 weeks',
    BudgetCadence.custom => 'Custom',
  };

  static String subtitle(BudgetCadence cadence) => switch (cadence) {
    BudgetCadence.calendarMonth => '1st to the last day of each month',
    BudgetCadence.payday => 'Same day each month to the next',
    BudgetCadence.weekly => 'Seven days from your chosen weekday',
    BudgetCadence.biweekly => 'Fourteen days from your anchor date',
    BudgetCadence.everyFourWeeks => 'Twenty-eight days from your anchor date',
    BudgetCadence.custom => 'One-off date ranges',
  };

  static String weekday(int weekday) => switch (weekday) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    DateTime.sunday => 'Sunday',
    _ => 'Day $weekday',
  };
}
