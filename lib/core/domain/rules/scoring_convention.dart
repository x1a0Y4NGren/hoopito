/// The meaning of the scoring buttons, frozen in each match's rule snapshot.
/// A missing convention remains the legacy, unrestricted scoring contract.
enum ScoringConvention {
  standard,
  onePerBasket,
  oneAndTwo;

  List<int> get scoreButtons => switch (this) {
    standard => const [1, 2, 3],
    onePerBasket => const [1],
    oneAndTwo => const [1, 2],
  };
}
