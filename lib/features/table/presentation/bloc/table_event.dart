import 'package:equatable/equatable.dart';

abstract class TableEvent extends Equatable {
  const TableEvent();

  @override
  List<Object> get props => [];
}

class LoadTables extends TableEvent {}

class CreateTable extends TableEvent {
  final String namaMeja;

  const CreateTable({required this.namaMeja});

  @override
  List<Object> get props => [namaMeja];
}

class UpdateTable extends TableEvent {
  final int id;
  final String namaMeja;
  final String status;

  const UpdateTable({required this.id, required this.namaMeja, required this.status});

  @override
  List<Object> get props => [id, namaMeja, status];
}

class DeleteTable extends TableEvent {
  final int id;

  const DeleteTable({required this.id});

  @override
  List<Object> get props => [id];
}

class ClearTable extends TableEvent {
  final int id;

  const ClearTable({required this.id});

  @override
  List<Object> get props => [id];
}
