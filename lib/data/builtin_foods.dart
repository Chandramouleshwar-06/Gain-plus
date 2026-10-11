import '../models/food.dart';

/// Common foods, available offline. Values are approximate, for typical
/// home-style portions; packaged foods are better found with online search.
Food _f(String name, String serving, double grams, double kcal, double protein, double carbs, double fat) => Food(
      id: 'builtin-food-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}',
      name: name,
      servingName: serving,
      servingGrams: grams,
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      source: 'builtin',
    );

final builtinFoods = <Food>[
  // Breads and grains
  _f('Roti / chapati', '1 medium', 40, 110, 3.5, 19, 2.5),
  _f('Phulka', '1 piece', 30, 80, 2.7, 15, 0.8),
  _f('Plain paratha', '1 piece', 80, 260, 5, 36, 10),
  _f('Aloo paratha', '1 piece', 120, 300, 6, 42, 12),
  _f('Steamed rice', '1 cup cooked', 160, 205, 4.3, 45, 0.4),
  _f('Jeera rice', '1 cup', 160, 250, 4.5, 45, 6),
  _f('Brown rice', '1 cup cooked', 195, 215, 5, 45, 1.8),
  _f('Khichdi', '1 cup', 200, 240, 9, 38, 5),
  _f('Poha', '1 cup', 150, 250, 5, 42, 7),
  _f('Upma', '1 cup', 180, 250, 6, 36, 9),
  _f('Oats (dry)', '40 g', 40, 150, 5, 27, 2.7),
  _f('White bread', '1 slice', 25, 67, 2, 12.5, 0.8),
  _f('Brown bread', '1 slice', 28, 70, 3.6, 12, 1),

  // South Indian
  _f('Idli', '1 piece', 40, 58, 2, 12, 0.2),
  _f('Plain dosa', '1 medium', 90, 170, 4, 28, 5),
  _f('Masala dosa', '1 piece', 180, 350, 7, 48, 14),
  _f('Sambar', '1 katori (150 g)', 150, 120, 5, 17, 3.5),

  // Dal, curries, sabzi
  _f('Dal (toor / moong)', '1 katori (150 g)', 150, 150, 8, 20, 4),
  _f('Rajma curry', '1 katori (150 g)', 150, 190, 9, 25, 6),
  _f('Chole', '1 katori (150 g)', 150, 230, 10, 30, 8),
  _f('Moong dal cheela', '1 piece', 70, 120, 7, 15, 3.5),
  _f('Mixed veg sabzi', '1 katori (150 g)', 150, 120, 3, 14, 6),
  _f('Aloo sabzi', '1 katori (150 g)', 150, 170, 3, 24, 7),
  _f('Palak paneer', '1 katori (150 g)', 150, 260, 12, 9, 20),
  _f('Paneer butter masala', '1 katori (150 g)', 150, 350, 12, 12, 28),
  _f('Sprouts salad', '1 cup', 100, 80, 5, 13, 1),

  // Protein
  _f('Paneer', '100 g', 100, 265, 18, 3.6, 20),
  _f('Tofu', '100 g', 100, 76, 8, 1.9, 4.8),
  _f('Soya chunks (dry)', '50 g', 50, 173, 26, 17, 0.3),
  _f('Boiled egg', '1 large', 50, 78, 6.3, 0.6, 5.3),
  _f('Omelette (2 eggs)', '1 omelette', 120, 190, 13, 1.5, 14),
  _f('Chicken breast (cooked)', '100 g', 100, 165, 31, 0, 3.6),
  _f('Chicken curry', '1 katori (150 g)', 150, 250, 22, 6, 15),
  _f('Tandoori chicken', '2 pieces', 150, 260, 36, 4, 11),
  _f('Fish curry', '1 katori (150 g)', 150, 200, 20, 5, 11),
  _f('Chicken biryani', '1 plate', 300, 550, 25, 65, 20),
  _f('Whey protein', '1 scoop (30 g)', 30, 120, 24, 3, 1.5),

  // Dairy and drinks
  _f('Curd / dahi', '1 cup', 200, 120, 7, 9, 6),
  _f('Milk (toned)', '1 glass (250 ml)', 250, 145, 8, 12, 7),
  _f('Sweet lassi', '1 glass (250 ml)', 250, 230, 7, 35, 6),
  _f('Tea with milk and sugar', '1 cup', 150, 70, 2, 10, 2.5),
  _f('Coffee with milk and sugar', '1 cup', 150, 80, 2.5, 11, 3),
  _f('Ghee', '1 tsp', 5, 45, 0, 0, 5),

  // Fruit, nuts, snacks, sweets
  _f('Banana', '1 medium', 118, 105, 1.3, 27, 0.4),
  _f('Apple', '1 medium', 180, 95, 0.5, 25, 0.3),
  _f('Peanuts', '30 g', 30, 170, 7.7, 4.8, 14.6),
  _f('Almonds', '10 pieces', 12, 70, 2.5, 2.6, 6),
  _f('Peanut butter', '1 tbsp', 16, 95, 3.5, 3.5, 8),
  _f('Samosa', '1 piece', 100, 260, 4, 30, 14),
  _f('Pav bhaji', '1 plate', 300, 500, 12, 65, 22),
  _f('Gulab jamun', '1 piece', 40, 150, 2, 22, 6),
];
