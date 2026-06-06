abstract interface class UseCase<Output extends Object, Input extends Object> {
  Future<Output> call(Input input);
}
