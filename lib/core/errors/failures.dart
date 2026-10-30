import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure(this.message, {this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];

  @override
  String toString() => message;
}

class ApiKeyFailure extends Failure {
  const ApiKeyFailure(super.message, {super.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.statusCode});
}

class RateLimitFailure extends Failure {
  const RateLimitFailure(super.message, {super.statusCode});
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

class SttFailure extends Failure {
  const SttFailure(super.message);
}

class TtsFailure extends Failure {
  const TtsFailure(super.message);
}

class StorageFailure extends Failure {
  const StorageFailure(super.message);
}
