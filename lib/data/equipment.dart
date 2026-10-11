/// Equipment the user can have. Bodyweight exercises need none of these.
class Equipment {
  static const barbell = 'barbell';
  static const dumbbell = 'dumbbell';
  static const bench = 'bench';
  static const cable = 'cable';
  static const machine = 'machine';
  static const pullupBar = 'pullup_bar';
  static const dipBars = 'dip_bars';

  static const all = [barbell, dumbbell, bench, cable, machine, pullupBar, dipBars];

  static const labels = {
    barbell: 'Barbell + rack',
    dumbbell: 'Dumbbells',
    bench: 'Bench',
    cable: 'Cable station',
    machine: 'Machines',
    pullupBar: 'Pull-up bar',
    dipBars: 'Dip bars',
  };

  /// Short name for "Needs ..." labels.
  static String shortLabel(String code) => switch (code) {
        barbell => 'barbell',
        dumbbell => 'dumbbells',
        bench => 'a bench',
        cable => 'a cable station',
        machine => 'a machine',
        pullupBar => 'a pull-up bar',
        dipBars => 'dip bars',
        _ => code,
      };
}

/// Quick setups for onboarding and settings: (name, description, equipment).
const equipmentPresets = <(String, String, List<String>)>[
  ('Full gym', 'Everything: barbells, machines, cables', Equipment.all),
  ('Home gym', 'Barbell, dumbbells, bench, pull-up bar',
      [Equipment.barbell, Equipment.dumbbell, Equipment.bench, Equipment.pullupBar]),
  ('Dumbbells', 'Dumbbells and a bench', [Equipment.dumbbell, Equipment.bench]),
  ('Bar only', 'Bodyweight plus a pull-up bar and dip bars', [Equipment.pullupBar, Equipment.dipBars]),
  ('Bodyweight', 'No equipment at all', <String>[]),
];

/// What each built-in exercise needs, by name. Missing = bodyweight only.
const builtinEquipment = <String, List<String>>{
  'Bench Press (Barbell)': [Equipment.barbell, Equipment.bench],
  'Incline Bench Press (Barbell)': [Equipment.barbell, Equipment.bench],
  'Dumbbell Flys': [Equipment.dumbbell, Equipment.bench],
  'Chest Press (Machine)': [Equipment.machine],
  'Dips (Chest Focus)': [Equipment.dipBars],
  'Squat (Barbell)': [Equipment.barbell],
  'Leg Press': [Equipment.machine],
  'Leg Extension': [Equipment.machine],
  'Leg Curl': [Equipment.machine],
  'Lunges (Dumbbell)': [Equipment.dumbbell],
  'Bulgarian Split Squats': [Equipment.bench],
  'Deadlift (Barbell)': [Equipment.barbell],
  'Pull Up': [Equipment.pullupBar],
  'Chin Up': [Equipment.pullupBar],
  'Lat Pulldown': [Equipment.cable],
  'Barbell Row': [Equipment.barbell],
  'Seated Cable Row': [Equipment.cable],
  'Dumbbell Row': [Equipment.dumbbell, Equipment.bench],
  'Australian Pull Ups': [Equipment.pullupBar],
  'Muscle Up': [Equipment.pullupBar],
  'Overhead Press (Barbell)': [Equipment.barbell],
  'Lateral Raise (Dumbbell)': [Equipment.dumbbell],
  'Front Raise (Dumbbell)': [Equipment.dumbbell],
  'Shoulder Press (Dumbbell)': [Equipment.dumbbell],
  'Rear Delt Fly (Machine)': [Equipment.machine],
  'Bicep Curl (Dumbbell)': [Equipment.dumbbell],
  'Hammer Curl (Dumbbell)': [Equipment.dumbbell],
  'Tricep Pushdown (Cable)': [Equipment.cable],
  'Tricep Dip': [Equipment.dipBars],
  'Preacher Curl': [Equipment.dumbbell, Equipment.bench],
  'Skull Crushers': [Equipment.dumbbell, Equipment.bench],
  'Leg Raise': [Equipment.pullupBar],
  'L-Sit': [Equipment.dipBars],
};

/// True when every piece of [needs] is in [available].
bool hasEquipmentFor(List<String> needs, Set<String> available) => needs.every(available.contains);

/// What's missing for [needs], for "Needs barbell" labels.
List<String> missingEquipment(List<String> needs, Set<String> available) =>
    needs.where((e) => !available.contains(e)).toList();
