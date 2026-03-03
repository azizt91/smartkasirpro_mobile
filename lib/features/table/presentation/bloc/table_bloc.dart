import 'package:flutter_bloc/flutter_bloc.dart';
import 'table_event.dart';
import 'table_state.dart';
import '../../data/repositories/table_repository.dart';

class TableBloc extends Bloc<TableEvent, TableState> {
  final TableRepository repository;

  TableBloc({required this.repository}) : super(TableInitial()) {
    on<LoadTables>(_onLoadTables);
    on<CreateTable>(_onCreateTable);
    on<UpdateTable>(_onUpdateTable);
    on<DeleteTable>(_onDeleteTable);
    on<ClearTable>(_onClearTable);
  }

  Future<void> _onLoadTables(LoadTables event, Emitter<TableState> emit) async {
    emit(TableLoading());
    final result = await repository.getTables();
    result.fold(
      (failure) => emit(TableError(message: failure.message)),
      (tables) => emit(TableLoaded(tables: tables)),
    );
  }

  Future<void> _onCreateTable(CreateTable event, Emitter<TableState> emit) async {
    emit(TableLoading());
    final result = await repository.createTable(event.namaMeja);
    result.fold(
      (failure) {
        emit(TableError(message: failure.message));
        add(LoadTables()); // Refresh list
      },
      (_) {
        emit(const TableOperationSuccess(message: 'Meja berhasil ditambahkan'));
        add(LoadTables()); // Refresh list
      },
    );
  }

  Future<void> _onUpdateTable(UpdateTable event, Emitter<TableState> emit) async {
    emit(TableLoading());
    final result = await repository.updateTable(event.id, event.namaMeja, event.status);
    result.fold(
      (failure) {
        emit(TableError(message: failure.message));
        add(LoadTables()); // Refresh list
      },
      (_) {
        emit(const TableOperationSuccess(message: 'Meja berhasil diperbarui'));
        add(LoadTables()); // Refresh list
      },
    );
  }

  Future<void> _onDeleteTable(DeleteTable event, Emitter<TableState> emit) async {
    emit(TableLoading());
    final result = await repository.deleteTable(event.id);
    result.fold(
      (failure) {
        emit(TableError(message: failure.message));
        add(LoadTables()); // Refresh list
      },
      (_) {
        emit(const TableOperationSuccess(message: 'Meja berhasil dihapus'));
        add(LoadTables()); // Refresh list
      },
    );
  }

  Future<void> _onClearTable(ClearTable event, Emitter<TableState> emit) async {
    emit(TableLoading());
    final result = await repository.clearTable(event.id);
    result.fold(
      (failure) {
        emit(TableError(message: failure.message));
        add(LoadTables()); // Refresh list
      },
      (_) {
        emit(const TableOperationSuccess(message: 'Meja berhasil dikosongkan'));
        add(LoadTables()); // Refresh list
      },
    );
  }
}
