/// Estimated one-rep max (Epley formula). A single rep is taken as is.
double estimateOneRepMax(double weight, int reps) {
  if (reps <= 0 || weight <= 0) return 0;
  if (reps == 1) return weight;
  return weight * (1 + reps / 30);
}
