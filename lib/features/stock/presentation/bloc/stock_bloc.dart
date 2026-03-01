import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/features/product/data/models/product_model.dart';
import 'package:mobile_app/features/product/data/models/category_model.dart'; // Import CategoryModel
import '../../data/models/stock_movement_model.dart';
import '../../data/repositories/stock_repository_impl.dart';

// Events
abstract class StockEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoadStockProducts extends StockEvent {
  // We will load all products initially, filtering is done in memory or via repository if needed.
  // The repository currently supports isLowStockOnly. To support Empty/Safe, we might need to fetch all and filter in Bloc,
  // or update Repository. Since we can't see Repository easily to change it, let's fetch ALL and filter in memory.
  LoadStockProducts();
}

class FilterStock extends StockEvent {
  final String filterType; // 'all', 'empty', 'low', 'safe'
  final String query;
  
  FilterStock({this.filterType = 'all', this.query = ''});
}

class LoadStockDetail extends StockEvent {
  final int productId;
  LoadStockDetail(this.productId);
}

class AdjustStock extends StockEvent {
  final int productId;
  final String type;
  final int quantity;
  final String notes;

  AdjustStock({
    required this.productId,
    required this.type,
    required this.quantity,
    required this.notes,
  });
}

// States
abstract class StockState extends Equatable {
  @override
  List<Object> get props => [];
}

class StockInitial extends StockState {}

class StockLoading extends StockState {}

class StockLoaded extends StockState {
  final List<ProductModel> products;
  final List<ProductModel> filteredProducts;
  final String currentFilter; // 'all', 'empty', 'low', 'safe'
  final String searchQuery;

  StockLoaded({
    required this.products, 
    required this.filteredProducts,
    this.currentFilter = 'all',
    this.searchQuery = '',
  });
  
  StockLoaded copyWith({
    List<ProductModel>? products,
    List<ProductModel>? filteredProducts,
    String? currentFilter,
    String? searchQuery,
  }) {
    return StockLoaded(
      products: products ?? this.products,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      currentFilter: currentFilter ?? this.currentFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object> get props => [products, filteredProducts, currentFilter, searchQuery];
}

class StockDetailLoaded extends StockState {
  final List<StockMovementModel> movements;
  
  StockDetailLoaded({required this.movements});
  
  @override
  List<Object> get props => [movements];
}

class StockError extends StockState {
  final String message;
  StockError(this.message);
  @override
  List<Object> get props => [message];
}

class StockAdjustmentSuccess extends StockState {}

// Bloc
class StockBloc extends Bloc<StockEvent, StockState> {
  final StockRepositoryImpl repository;

  StockBloc({required this.repository}) : super(StockInitial()) {
    on<LoadStockProducts>(_onLoadProducts);
    on<FilterStock>(_onFilterStock);
    on<LoadStockDetail>(_onLoadDetail);
    on<AdjustStock>(_onAdjustStock);
  }

  Future<void> _onLoadProducts(LoadStockProducts event, Emitter<StockState> emit) async {
    emit(StockLoading());
    print('StockBloc: Loading ALL stocks directly from repository...');
    // Always fetch ALL stocks so we can filter in memory for 'safe', 'low', 'empty'
    final result = await repository.getStocks(isLowStockOnly: false);
    
    result.fold(
      (failure) {
        print('StockBloc Error: ${failure.message}');
        emit(StockError(failure.message));
      },
      (products) {
        // Filter out jasa (service) products — they don't have physical stock
        final stockProducts = products.where((p) => p.type != 'jasa').toList();
        print('StockBloc Success: Loaded ${products.length} products (${stockProducts.length} non-jasa)');
        emit(StockLoaded(
          products: stockProducts, 
          filteredProducts: stockProducts, // Initially all (non-jasa)
          currentFilter: 'all'
        ));
      },
    );
  }

  void _onFilterStock(FilterStock event, Emitter<StockState> emit) {
    if (state is StockLoaded) {
      final currentState = state as StockLoaded;
      
      // Use the new filterType if provided, otherwise keep current.
      // If event.filterType is empty string (default?), careful. Constructor defaults to 'all'.
      // But we should use event properties.
      // If we are just searching, we might pass the same filterType or not?
      // Let's assume the UI sends the current selected filterType every time or we store it.
      // Better: The Event should probably update ONLY what changed, but simplicity: pass both.
      
      String filter = event.filterType;
      String query = event.query;
      
      // If we want to support partial updates we'd need nullable in event.
      // But let's assume UI passes full state or we merge.
      // Actually standard pattern: if we just search, UI might pass current filter.
      
      List<ProductModel> filtered = currentState.products.where((p) {
        bool matchFilter = true;
        if (filter == 'empty') {
            matchFilter = (p.stock <= 0);
        } else if (filter == 'low') {
            matchFilter = (p.stock > 0 && p.stock <= p.minimumStock);
        } else if (filter == 'safe') {
            matchFilter = (p.stock > p.minimumStock);
        }
        
        final matchQuery = p.name.toLowerCase().contains(query.toLowerCase()) || 
                           (p.barcode != null && p.barcode!.contains(query));
        return matchFilter && matchQuery;
      }).toList();

      emit(currentState.copyWith(
        filteredProducts: filtered,
        currentFilter: filter,
        searchQuery: query,
      ));
    }
  }

  Future<void> _onLoadDetail(LoadStockDetail event, Emitter<StockState> emit) async {
     emit(StockLoading());
     final result = await repository.getStockMovements(event.productId);
     
     result.fold(
      (failure) => emit(StockError(failure.message)),
      (movements) => emit(StockDetailLoaded(movements: movements)),
    );
  }

  Future<void> _onAdjustStock(AdjustStock event, Emitter<StockState> emit) async {
    emit(StockLoading());
    final result = await repository.adjustStock(event.productId, event.type, event.quantity, event.notes);
    
    result.fold(
      (failure) => emit(StockError(failure.message)),
      (_) {
          emit(StockAdjustmentSuccess());
      }
    );
  }
}
