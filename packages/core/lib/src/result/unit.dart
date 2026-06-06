final class Unit {
  const Unit();

  static const value = Unit();

  @override
  bool operator ==(Object other) {
    return other is Unit;
  }

  @override
  int get hashCode => 0;
}
