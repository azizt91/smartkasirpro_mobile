import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/transaction/data/repositories/transaction_repository_impl.dart';

// Events
abstract class KitchenEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoadKitchenOrders extends KitchenEvent {
  final bool isAutoRefresh;
  LoadKitchenOrders({this.isAutoRefresh = false});
  @override
  List<Object> get props => [isAutoRefresh];
}

class UpdateOrderStatus extends KitchenEvent {
  final String transactionCode;
  final String newStatus;

  UpdateOrderStatus(this.transactionCode, this.newStatus);

  @override
  List<Object> get props => [transactionCode, newStatus];
}

// State
class KitchenState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> orders;

  const KitchenState({
    this.isLoading = false,
    this.error,
    this.orders = const [],
  });

  KitchenState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? orders,
  }) {
    return KitchenState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // Don't persist errors necessarily
      orders: orders ?? this.orders,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, orders];
}

// Bloc
class KitchenBloc extends Bloc<KitchenEvent, KitchenState> {
  final TransactionRepository transactionRepository;

  KitchenBloc({required this.transactionRepository}) : super(const KitchenState()) {
    on<LoadKitchenOrders>(_onLoadKitchenOrders);
    on<UpdateOrderStatus>(_onUpdateOrderStatus);
  }

  Future<void> _onLoadKitchenOrders(LoadKitchenOrders event, Emitter<KitchenState> emit) async {
    // Only show loading spinner for user-initiated refresh (not auto-refresh)
    if (!event.isAutoRefresh) {
      emit(state.copyWith(isLoading: true, error: null));
    }
    final result = await transactionRepository.getKitchenOrders();
    
    result.fold(
      (failure) {
        // Silently ignore background auto-refresh errors to avoid spamming user
        if (event.isAutoRefresh) {
          // Keep existing data, don't emit error
          return;
        }
        emit(state.copyWith(isLoading: false, error: failure.message));
      },
      (orders) => emit(state.copyWith(isLoading: false, orders: orders)),
    );
  }

  Future<void> _onUpdateOrderStatus(UpdateOrderStatus event, Emitter<KitchenState> emit) async {
    // Optionally emit a localized loading state or just freeze the UI
    final result = await transactionRepository.updateOrderStatus(event.transactionCode, event.newStatus);
    
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)), // Only emit error, don't clear list
      (_) {
        // Optimistically update the list or just reload
        add(LoadKitchenOrders()); // Easy way
      }
    );
  }
}
