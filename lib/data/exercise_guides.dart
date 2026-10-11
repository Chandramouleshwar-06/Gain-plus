/// How to do an exercise: setup, the movement, cues and common mistakes.
class ExerciseGuide {
  final String setup;
  final List<String> steps;
  final List<String> cues;
  final List<String> mistakes;

  const ExerciseGuide({required this.setup, required this.steps, required this.cues, required this.mistakes});
}

/// Guides for the built-in exercises, by name.
ExerciseGuide? guideFor(String exerciseName) => _guides[exerciseName];

const _guides = <String, ExerciseGuide>{
  // Chest
  'Bench Press (Barbell)': ExerciseGuide(
    setup: 'Lie on the bench with your eyes under the bar, feet flat and shoulder blades squeezed together. '
        'Grip a little wider than shoulder width.',
    steps: [
      'Unrack the bar and hold it over your shoulders with straight arms.',
      'Lower it under control to your mid-chest, elbows about 45-70° from your body.',
      'Touch your chest lightly, then press back up and slightly back over your shoulders.',
    ],
    cues: ['Keep your shoulder blades pinned and a slight arch in your upper back.', 'Drive your feet into the floor.', 'Wrists straight, stacked over your elbows.'],
    mistakes: ['Bouncing the bar off your chest.', 'Flaring elbows straight out to the sides.', 'Lifting your hips off the bench.'],
  ),
  'Incline Bench Press (Barbell)': ExerciseGuide(
    setup: 'Set the bench to 30-45°. Lie back with shoulder blades squeezed and feet flat; grip just outside shoulder width.',
    steps: [
      'Unrack and hold the bar above your upper chest.',
      'Lower it to just below your collarbones.',
      'Press back up until your arms are straight.',
    ],
    cues: ['Keep your chest up towards the bar.', 'Elbows slightly tucked, not flared.'],
    mistakes: ['Setting the bench too steep (it becomes a shoulder press).', 'Lowering the bar to your neck or mid-chest.'],
  ),
  'Dumbbell Flys': ExerciseGuide(
    setup: 'Lie on a flat bench holding dumbbells above your chest, palms facing each other, elbows slightly bent.',
    steps: [
      'Open your arms in a wide arc until you feel a stretch across your chest.',
      'Keep the same small bend in your elbows throughout.',
      'Bring the weights back together over your chest, as if hugging a tree.',
    ],
    cues: ['Think of moving your upper arms, not your hands.', 'Stop at a comfortable stretch, around chest level.'],
    mistakes: ['Bending the elbows more and turning it into a press.', 'Going too heavy and dropping too deep.'],
  ),
  'Push Ups': ExerciseGuide(
    setup: 'Hands slightly wider than your shoulders, body in a straight line from head to heels.',
    steps: [
      'Lower your chest towards the floor, elbows about 45° from your body.',
      'Go until your chest is just above the floor.',
      'Push back up to straight arms.',
    ],
    cues: ['Squeeze your glutes and brace your abs.', 'Hands under or just outside your shoulders.'],
    mistakes: ['Hips sagging or piking up.', 'Half reps that stop well short of the floor.'],
  ),
  'Chest Press (Machine)': ExerciseGuide(
    setup: 'Adjust the seat so the handles line up with your mid-chest. Sit back with shoulder blades against the pad.',
    steps: [
      'Press the handles forward until your arms are almost straight.',
      'Pause briefly, then let them come back slowly until you feel a chest stretch.',
    ],
    cues: ['Keep your back on the pad.', 'Control the way back; don\'t let the stack crash.'],
    mistakes: ['Seat too low or high, so the shoulders take over.', 'Locking out hard at the top.'],
  ),
  'Diamond Push Ups': ExerciseGuide(
    setup: 'Push-up position with your hands together under your chest, thumbs and index fingers forming a diamond.',
    steps: [
      'Lower your chest towards your hands, elbows close to your body.',
      'Touch or nearly touch your hands.',
      'Press back up to straight arms.',
    ],
    cues: ['Keep your body rigid like a plank.', 'Elbows track back, not out.'],
    mistakes: ['Sagging hips.', 'Flaring elbows wide, which strains the wrists and shoulders.'],
  ),
  'Dips (Chest Focus)': ExerciseGuide(
    setup: 'Support yourself on parallel bars with straight arms, then lean your torso forward and bend your knees.',
    steps: [
      'Lower yourself by bending your elbows, letting them flare slightly.',
      'Go until your shoulders are just below your elbows, or to a comfortable stretch.',
      'Press back up, staying leaned forward.',
    ],
    cues: ['Lean forward to work the chest more.', 'Shoulders down, away from your ears.'],
    mistakes: ['Dropping too deep too soon (hard on the shoulders).', 'Staying upright, which shifts it to the triceps.'],
  ),

  // Legs
  'Squat (Barbell)': ExerciseGuide(
    setup: 'Bar on your upper back (not your neck), feet about shoulder width, toes turned out a little.',
    steps: [
      'Brace your core and take a breath.',
      'Sit down and back, knees moving out in line with your toes.',
      'Go until your hip crease is at or below knee height, or as deep as you can with a flat back.',
      'Drive up through your whole foot to standing.',
    ],
    cues: ['Chest up, back flat.', 'Knees follow your toes.', 'Keep your heels down.'],
    mistakes: ['Knees caving in.', 'Heels lifting.', 'Rounding the lower back at the bottom.'],
  ),
  'Leg Press': ExerciseGuide(
    setup: 'Sit with your back and hips flat on the pad, feet shoulder width in the middle of the platform.',
    steps: [
      'Release the safeties and lower the platform by bending your knees.',
      'Go until your knees are around 90° or just past, without your hips lifting.',
      'Press back up without locking your knees.',
    ],
    cues: ['Push through your heels and mid-foot.', 'Knees in line with your toes.'],
    mistakes: ['Lowering so far that your lower back rounds off the pad.', 'Snapping your knees straight at the top.'],
  ),
  'Leg Extension': ExerciseGuide(
    setup: 'Adjust the seat so your knees line up with the machine\'s pivot and the pad sits on your lower shins.',
    steps: [
      'Straighten your legs until they\'re fully extended.',
      'Squeeze your quads for a moment.',
      'Lower slowly back down.',
    ],
    cues: ['Hold the handles and keep your hips down.', 'Slow on the way down.'],
    mistakes: ['Swinging the weight up.', 'Letting the stack drop between reps.'],
  ),
  'Leg Curl': ExerciseGuide(
    setup: 'Line your knees up with the pivot and set the pad just above your heels.',
    steps: [
      'Curl your heels towards your glutes as far as you can.',
      'Squeeze your hamstrings briefly.',
      'Lower slowly to straight legs.',
    ],
    cues: ['Keep your hips pressed into the pad.', 'Control the lowering.'],
    mistakes: ['Hips lifting to cheat the weight up.', 'Short, jerky reps.'],
  ),
  'Lunges (Dumbbell)': ExerciseGuide(
    setup: 'Stand tall with a dumbbell in each hand at your sides.',
    steps: [
      'Take a long step forward.',
      'Lower until your back knee nearly touches the floor and your front shin is roughly upright.',
      'Push through your front heel to step back, then switch legs.',
    ],
    cues: ['Torso upright.', 'Front knee tracks over your toes.'],
    mistakes: ['Steps too short, so the front knee shoots forward.', 'Front knee caving in.'],
  ),
  'Calf Raise': ExerciseGuide(
    setup: 'Stand with the balls of your feet on a step or calf-raise machine, heels hanging off.',
    steps: [
      'Lower your heels for a full stretch.',
      'Rise up onto your toes as high as you can.',
      'Pause at the top, then lower slowly.',
    ],
    cues: ['Pause at the bottom and top.', 'Keep your knees straight but not locked.'],
    mistakes: ['Bouncing through short reps.', 'Rolling onto the outside of your feet.'],
  ),
  'Pistol Squats': ExerciseGuide(
    setup: 'Stand on one leg with the other leg straight out in front. Hold a support at first if you need to.',
    steps: [
      'Sit down on the standing leg, reaching your arms forward for balance.',
      'Go as low as you can while keeping your heel down.',
      'Stand back up without letting the knee cave in.',
    ],
    cues: ['Keep the heel of the standing foot flat.', 'Reach forward to counterbalance.'],
    mistakes: ['Knee collapsing inward.', 'Dropping into the bottom without control.'],
  ),
  'Bulgarian Split Squats': ExerciseGuide(
    setup: 'Stand a stride in front of a bench and rest the top of your back foot on it.',
    steps: [
      'Lower straight down until your front thigh is about parallel to the floor.',
      'Keep most of your weight on the front leg.',
      'Drive up through the front heel.',
    ],
    cues: ['Torso upright for quads, leaning slightly forward for glutes.', 'Front knee follows your toes.'],
    mistakes: ['Front foot too close to the bench.', 'Pushing off the back leg.'],
  ),

  // Back
  'Deadlift (Barbell)': ExerciseGuide(
    setup: 'Stand with the bar over your mid-foot, feet hip width. Hinge down and grip just outside your legs.',
    steps: [
      'Pull your shoulders down, chest up and back flat; take the slack out of the bar.',
      'Push the floor away, keeping the bar against your legs.',
      'Stand tall with your hips and knees locked out at the same time.',
      'Lower by pushing your hips back, then bending your knees once the bar passes them.',
    ],
    cues: ['Brace your core before every rep.', 'Bar stays close to your body.', 'Hips and shoulders rise together.'],
    mistakes: ['Rounding the lower back.', 'Jerking the bar off the floor.', 'Leaning back at the top.'],
  ),
  'Pull Up': ExerciseGuide(
    setup: 'Hang from a bar with an overhand grip, hands a little wider than your shoulders.',
    steps: [
      'Pull your shoulder blades down and back.',
      'Pull yourself up until your chin is over the bar.',
      'Lower all the way to straight arms under control.',
    ],
    cues: ['Lead with your chest.', 'Think of driving your elbows down to your sides.'],
    mistakes: ['Kicking or swinging.', 'Half reps that don\'t reach straight arms.'],
  ),
  'Chin Up': ExerciseGuide(
    setup: 'Hang from a bar with an underhand grip, hands about shoulder width.',
    steps: [
      'Pull your shoulder blades down.',
      'Pull up until your chin clears the bar.',
      'Lower slowly to straight arms.',
    ],
    cues: ['Squeeze your biceps and lats together.', 'Keep your body still.'],
    mistakes: ['Swinging for momentum.', 'Stopping short of the bottom.'],
  ),
  'Lat Pulldown': ExerciseGuide(
    setup: 'Sit with your thighs under the pads and grip the bar a little wider than your shoulders.',
    steps: [
      'Lean back slightly and pull the bar to your upper chest.',
      'Squeeze your shoulder blades down and together.',
      'Let the bar rise slowly until your arms are straight.',
    ],
    cues: ['Pull with your elbows, not your hands.', 'Chest up towards the bar.'],
    mistakes: ['Leaning far back and rowing the weight.', 'Pulling the bar behind your neck.'],
  ),
  'Barbell Row': ExerciseGuide(
    setup: 'Hold the bar with an overhand grip, hinge forward until your torso is around 45° or lower, back flat.',
    steps: [
      'Let the bar hang below your shoulders.',
      'Row it to your lower chest or upper stomach.',
      'Squeeze your shoulder blades, then lower under control.',
    ],
    cues: ['Keep your torso angle fixed.', 'Elbows drive back past your body.'],
    mistakes: ['Standing up more with each rep.', 'Rounding the back.', 'Jerking the weight with your hips.'],
  ),
  'Seated Cable Row': ExerciseGuide(
    setup: 'Sit with feet on the platform, knees slightly bent, holding the handle with straight arms and a tall back.',
    steps: [
      'Pull the handle to your stomach.',
      'Squeeze your shoulder blades together.',
      'Return slowly until your arms are straight and you feel a stretch.',
    ],
    cues: ['Sit tall; chest up.', 'Elbows close to your body.'],
    mistakes: ['Rocking back and forth.', 'Shrugging your shoulders up.'],
  ),
  'Dumbbell Row': ExerciseGuide(
    setup: 'Put one knee and hand on a bench, back flat, holding a dumbbell in the other hand.',
    steps: [
      'Let the dumbbell hang straight down.',
      'Row it towards your hip.',
      'Lower slowly to a full stretch.',
    ],
    cues: ['Pull towards your hip, not your chest.', 'Keep your shoulders square to the floor.'],
    mistakes: ['Twisting your torso to lift.', 'Short reps.'],
  ),
  'Australian Pull Ups': ExerciseGuide(
    setup: 'Lie under a low bar (or rings) at about waist height. Grip it with straight arms, body straight, heels on the floor.',
    steps: [
      'Pull your chest up to the bar.',
      'Squeeze your shoulder blades together at the top.',
      'Lower to straight arms.',
    ],
    cues: ['Body stays in one straight line.', 'Lower the bar or bend your knees to make it easier.'],
    mistakes: ['Hips sagging.', 'Reaching with your chin instead of pulling your chest up.'],
  ),
  'Muscle Up': ExerciseGuide(
    setup: 'Hang from a bar with a slightly narrower than shoulder-width overhand grip. Build up with strong pull-ups and dips first.',
    steps: [
      'Pull explosively, driving the bar towards your hips.',
      'As your chest reaches the bar, lean forward and rotate your wrists over it.',
      'Press up to straight arms on top of the bar.',
      'Lower back down under control.',
    ],
    cues: ['Pull high and fast: aim for your hips, not your chin.', 'Lean forward hard at the transition.'],
    mistakes: ['Pulling only to the chin, which makes the transition impossible.', 'One arm going over before the other.'],
  ),

  // Shoulders
  'Overhead Press (Barbell)': ExerciseGuide(
    setup: 'Stand with the bar on your front shoulders, hands just outside shoulder width, elbows slightly in front of the bar.',
    steps: [
      'Brace your core and squeeze your glutes.',
      'Press the bar straight up, moving your head back slightly to let it pass.',
      'Lock out overhead with the bar over your mid-foot, then lower to your shoulders.',
    ],
    cues: ['Squeeze your glutes so your lower back doesn\'t arch.', 'Push your head through once the bar passes it.'],
    mistakes: ['Leaning back a lot to press.', 'Pressing the bar forward instead of straight up.'],
  ),
  'Lateral Raise (Dumbbell)': ExerciseGuide(
    setup: 'Stand with a light dumbbell in each hand at your sides, elbows slightly bent.',
    steps: [
      'Raise your arms out to the sides until they\'re about shoulder height.',
      'Pause briefly.',
      'Lower slowly.',
    ],
    cues: ['Lead with your elbows.', 'Think "out", not "up".'],
    mistakes: ['Swinging the weight up with your body.', 'Shrugging your shoulders to your ears.'],
  ),
  'Front Raise (Dumbbell)': ExerciseGuide(
    setup: 'Stand with a dumbbell in each hand in front of your thighs.',
    steps: [
      'Raise one or both arms forward to shoulder height, elbows slightly bent.',
      'Pause, then lower slowly.',
    ],
    cues: ['Keep your torso still.', 'Stop at shoulder height.'],
    mistakes: ['Leaning back to swing the weight.', 'Lifting far above your head.'],
  ),
  'Shoulder Press (Dumbbell)': ExerciseGuide(
    setup: 'Sit on an upright bench (or stand) with dumbbells at shoulder height, palms forward.',
    steps: [
      'Press the dumbbells up until your arms are straight.',
      'Bring them close together at the top without clanking.',
      'Lower back to shoulder height.',
    ],
    cues: ['Wrists stacked over elbows.', 'Ribs down; don\'t arch your back.'],
    mistakes: ['Cutting the range short.', 'Arching hard off the bench.'],
  ),
  'Rear Delt Fly (Machine)': ExerciseGuide(
    setup: 'Sit facing the pad with the handles at shoulder height; set the arms so they start in front of you.',
    steps: [
      'With slightly bent elbows, sweep your arms back and out.',
      'Stop when your arms are in line with your body.',
      'Return slowly.',
    ],
    cues: ['Think of pushing your hands out wide, not squeezing your shoulder blades hard.', 'Chest stays on the pad.'],
    mistakes: ['Using too much weight and jerking.', 'Shrugging up.'],
  ),
  'Handstand Push Ups': ExerciseGuide(
    setup: 'Kick up into a handstand against a wall, hands a little wider than your shoulders. Master pike push-ups first.',
    steps: [
      'Lower your head towards the floor under control.',
      'Lightly touch your head (or a pad) to the floor, forming a tripod with your hands.',
      'Press back up to straight arms.',
    ],
    cues: ['Brace your core and squeeze your legs together.', 'Elbows angled slightly forward, not flared.'],
    mistakes: ['Dropping onto your head.', 'Arching your back against the wall.'],
  ),
  'Pike Push Ups': ExerciseGuide(
    setup: 'Start in a push-up position, then walk your feet in and lift your hips high so your body forms an upside-down V.',
    steps: [
      'Bend your elbows and lower the top of your head towards the floor in front of your hands.',
      'Press back up to straight arms.',
    ],
    cues: ['Keep your hips high.', 'Raise your feet on a box to make it harder.'],
    mistakes: ['Hips dropping into a normal push-up.', 'Elbows flaring straight out.'],
  ),

  // Arms
  'Bicep Curl (Dumbbell)': ExerciseGuide(
    setup: 'Stand with a dumbbell in each hand, arms straight, palms facing forward.',
    steps: [
      'Curl the weights up by bending your elbows.',
      'Squeeze at the top.',
      'Lower slowly to straight arms.',
    ],
    cues: ['Elbows stay pinned at your sides.', 'Full range: straight arms at the bottom.'],
    mistakes: ['Swinging your body.', 'Elbows drifting forward.'],
  ),
  'Hammer Curl (Dumbbell)': ExerciseGuide(
    setup: 'Stand holding dumbbells at your sides with palms facing each other.',
    steps: [
      'Curl the weights up, keeping your palms facing in.',
      'Pause at the top.',
      'Lower slowly.',
    ],
    cues: ['Thumbs point up throughout.', 'Elbows still.'],
    mistakes: ['Swinging.', 'Rotating your wrists into a normal curl.'],
  ),
  'Tricep Pushdown (Cable)': ExerciseGuide(
    setup: 'Face a high cable with a bar or rope. Grip it with elbows at your sides, bent about 90°.',
    steps: [
      'Push down until your arms are straight.',
      'Squeeze your triceps.',
      'Let it come back up to 90° without moving your elbows.',
    ],
    cues: ['Elbows pinned to your sides.', 'Spread the rope at the bottom if using one.'],
    mistakes: ['Leaning over and pushing with your body.', 'Elbows drifting forward and back.'],
  ),
  'Tricep Dip': ExerciseGuide(
    setup: 'Support yourself on parallel bars with straight arms and an upright torso.',
    steps: [
      'Bend your elbows to lower yourself, keeping them pointing back.',
      'Go until your elbows are about 90°.',
      'Press back up to straight arms.',
    ],
    cues: ['Stay upright to focus on the triceps.', 'Shoulders down.'],
    mistakes: ['Going so deep it hurts your shoulders.', 'Elbows flaring out.'],
  ),
  'Preacher Curl': ExerciseGuide(
    setup: 'Sit at the preacher bench with your upper arms flat on the pad, holding an EZ bar or dumbbells.',
    steps: [
      'Curl the weight up towards your shoulders.',
      'Squeeze at the top.',
      'Lower slowly until your arms are almost straight.',
    ],
    cues: ['Armpits snug against the top of the pad.', 'Slow on the way down.'],
    mistakes: ['Dropping fast to full lockout (hard on the elbows).', 'Lifting your elbows off the pad.'],
  ),
  'Skull Crushers': ExerciseGuide(
    setup: 'Lie on a bench holding an EZ bar or dumbbells above your chest with straight arms.',
    steps: [
      'Bend only at the elbows to lower the weight towards your forehead or just behind your head.',
      'Press back up to straight arms.',
    ],
    cues: ['Upper arms stay still, angled slightly back.', 'Elbows point to the ceiling, not out.'],
    mistakes: ['Turning it into a press by moving your upper arms.', 'Elbows flaring wide.'],
  ),

  // Core and full body
  'Plank': ExerciseGuide(
    setup: 'Forearms on the floor under your shoulders, legs straight, toes on the floor.',
    steps: [
      'Lift your hips so your body forms a straight line from head to heels.',
      'Hold, breathing steadily.',
    ],
    cues: ['Squeeze your glutes and brace like you\'re about to be poked in the stomach.', 'Look at the floor.'],
    mistakes: ['Hips sagging.', 'Hips piked high.', 'Holding your breath.'],
  ),
  'Crunches': ExerciseGuide(
    setup: 'Lie on your back, knees bent, feet flat, hands lightly behind your head or across your chest.',
    steps: [
      'Curl your shoulders off the floor by tightening your abs.',
      'Pause at the top.',
      'Lower slowly.',
    ],
    cues: ['Think of bringing your ribs towards your hips.', 'Keep your chin off your chest.'],
    mistakes: ['Pulling on your neck.', 'Rushing reps with momentum.'],
  ),
  'Leg Raise': ExerciseGuide(
    setup: 'Lie on your back (or hang from a bar) with legs straight.',
    steps: [
      'Lift your legs, keeping them as straight as you can.',
      'Curl your hips up slightly at the top.',
      'Lower slowly without letting your lower back arch.',
    ],
    cues: ['Press your lower back into the floor.', 'Bend your knees to make it easier.'],
    mistakes: ['Arching your lower back.', 'Swinging the legs.'],
  ),
  'L-Sit': ExerciseGuide(
    setup: 'Sit between parallettes, dip bars or on the floor with hands beside your hips.',
    steps: [
      'Press down to lift your body, arms straight.',
      'Lift your legs straight out in front, parallel to the floor.',
      'Hold.',
    ],
    cues: ['Push your shoulders down hard.', 'Tuck your knees to make it easier.'],
    mistakes: ['Shrugging your shoulders up.', 'Bent arms.'],
  ),
  'Burpees': ExerciseGuide(
    setup: 'Stand with feet hip width.',
    steps: [
      'Squat down and put your hands on the floor.',
      'Jump your feet back into a push-up position (add a push-up if you like).',
      'Jump your feet back to your hands.',
      'Jump up with your arms overhead.',
    ],
    cues: ['Land softly.', 'Keep your core tight in the plank.'],
    mistakes: ['Hips sagging when your feet land back.', 'Sloppy form as you tire: slow down instead.'],
  ),
  'Hollow Body Hold': ExerciseGuide(
    setup: 'Lie on your back with arms overhead and legs straight.',
    steps: [
      'Press your lower back into the floor.',
      'Lift your arms, shoulders and legs a few inches off the floor.',
      'Hold the banana shape.',
    ],
    cues: ['Lower back stays glued to the floor.', 'Bend your knees or bring arms forward to make it easier.'],
    mistakes: ['Lower back lifting off the floor.', 'Holding your breath.'],
  ),
};
