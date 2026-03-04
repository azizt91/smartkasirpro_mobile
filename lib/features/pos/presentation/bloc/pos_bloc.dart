import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../product/data/models/product_model.dart';
import '../../../product/data/models/category_model.dart'; // Import CategoryModel
import '../../../product/domain/repositories/product_repository.dart';
import 'package:mobile_app/features/transaction/data/repositories/transaction_repository_impl.dart';
import '../../data/models/customer_model.dart'; // Import CustomerModel
import '../../data/repositories/customer_repository.dart'; // Import CustomerRepository

// Events
abstract class PosEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoadPosData extends PosEvent {}
class FilterProducts extends PosEvent {
  final int? categoryId;
  final String query;
  FilterProducts({this.categoryId, this.query = ''});
  @override
  List<Object> get props => [categoryId ?? -1, query];
}
class AddToCart extends PosEvent {
  final ProductModel product;
  final int quantity;
  final int? employeeId;
  final String? employeeName;

  AddToCart(this.product, {this.quantity = 1, this.employeeId, this.employeeName});
  @override
  List<Object> get props => [product, quantity, employeeId ?? -1, employeeName ?? ''];
}
class UpdateCartQuanity extends PosEvent {
  final ProductModel product;
  final int quantity;
  UpdateCartQuanity(this.product, this.quantity);
  @override
  List<Object> get props => [product, quantity];
}
class RemoveFromCart extends PosEvent {
  final ProductModel product;
  RemoveFromCart(this.product);
  @override
  List<Object> get props => [product];
}
class ClearCart extends PosEvent {}
class SubmitTransaction extends PosEvent {
  final String paymentMethod;
  final String? paymentChannel;
  final double amountPaid;
  final String? customerName;
  final int? customerId; 
  final String? note;
  final DateTime? transactionDate;
  final int? pointsRedeemed;
  final int? pointExchangeRate;
  final int? tableId;
  final bool? isTakeaway;
  final String? pendingOrderCode;

  SubmitTransaction({
    required this.paymentMethod, 
    this.paymentChannel,
    required this.amountPaid,
    this.customerName,
    this.customerId,
    this.note,
    this.transactionDate,
    this.pointsRedeemed = 0,
    this.pointExchangeRate = 100,
    this.tableId,
    this.isTakeaway,
    this.pendingOrderCode,
  });
  
  @override
  List<Object> get props => [paymentMethod, paymentChannel ?? '', amountPaid, customerName ?? '', customerId ?? -1, note ?? '', transactionDate.toString(), pointsRedeemed ?? 0, pointExchangeRate ?? 100, tableId ?? -1, isTakeaway ?? false, pendingOrderCode ?? ''];
}

class ScanBarcode extends PosEvent {
  final String barcode;
  ScanBarcode(this.barcode);
  @override
  List<Object> get props => [barcode];
}

class AddCustomer extends PosEvent {
  final String name;
  final String? phone;
  AddCustomer({required this.name, this.phone});
  @override
  List<Object> get props => [name, phone ?? ''];
}

// RESTO MODE EVENTS
class FetchPendingOrders extends PosEvent {}
class BukaProsesPesanan extends PosEvent {
  final Map<String, dynamic> order;
  BukaProsesPesanan(this.order);
  @override
  List<Object> get props => [order];
}
class CancelPendingOrder extends PosEvent {
  final String transactionCode;
  CancelPendingOrder(this.transactionCode);
  @override
  List<Object> get props => [transactionCode];
}

// States
class CartItem extends Equatable {
  final ProductModel product;
  final int quantity;
  final int? employeeId;
  final String? employeeName;
  
  const CartItem({
    required this.product, 
    required this.quantity,
    this.employeeId,
    this.employeeName,
  });
  
  double get subtotal => product.sellingPrice * quantity;

  CartItem copyWith({int? quantity, int? employeeId, String? employeeName}) {
    return CartItem(
      product: product, 
      quantity: quantity ?? this.quantity,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
    );
  }

  @override
  List<Object> get props => [product, quantity, employeeId ?? -1, employeeName ?? ''];
}

class PosState extends Equatable {
  final List<ProductModel> allProducts;
  final List<ProductModel> filteredProducts;
  final List<CategoryModel> categories; 
  final List<CustomerModel> customers; 
  final List<Map<String, dynamic>> employees; 
  final List<Map<String, dynamic>> tables;
  final List<CartItem> cartItems;
  final int selectedCategoryId; 
  final String searchQuery;
  final bool isLoading;
  final String? error;
  final bool isSuccess; 
  final Map<String, dynamic>? lastTransaction; 
  final List<Map<String, dynamic>> pendingOrders;
  // Pending order metadata (set by BukaProsesPesanan)
  final String? pendingOrderCode;
  final String? pendingCustomerName;
  final int? pendingTableId;

  const PosState({
    this.allProducts = const [],
    this.filteredProducts = const [],
    this.categories = const [],
    this.customers = const [], 
    this.employees = const [], 
    this.tables = const [],
    this.cartItems = const [],
    this.selectedCategoryId = 0,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.lastTransaction,
    this.pendingOrders = const [],
    this.pendingOrderCode,
    this.pendingCustomerName,
    this.pendingTableId,
  });

  double get subtotal => cartItems.fold(0, (sum, item) => sum + item.subtotal);
  double get total => subtotal; 

  PosState copyWith({
    List<ProductModel>? allProducts,
    List<ProductModel>? filteredProducts,
    List<CategoryModel>? categories,
    List<CustomerModel>? customers, 
    List<Map<String, dynamic>>? employees, 
    List<Map<String, dynamic>>? tables, 
    List<CartItem>? cartItems,
    int? selectedCategoryId,
    String? searchQuery,
    bool? isLoading,
    String? error,
    bool? isSuccess,
    Map<String, dynamic>? lastTransaction,
    List<Map<String, dynamic>>? pendingOrders,
    String? pendingOrderCode,
    String? pendingCustomerName,
    int? pendingTableId,
    bool clearPendingOrder = false,
  }) {
    return PosState(
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      categories: categories ?? this.categories,
      customers: customers ?? this.customers, 
      employees: employees ?? this.employees,
      tables: tables ?? this.tables,
      cartItems: cartItems ?? this.cartItems,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      lastTransaction: lastTransaction ?? this.lastTransaction,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      pendingOrderCode: clearPendingOrder ? null : (pendingOrderCode ?? this.pendingOrderCode),
      pendingCustomerName: clearPendingOrder ? null : (pendingCustomerName ?? this.pendingCustomerName),
      pendingTableId: clearPendingOrder ? null : (pendingTableId ?? this.pendingTableId),
    );
  }

  @override
  List<Object?> get props => [allProducts, filteredProducts, categories, customers, employees, tables, cartItems, selectedCategoryId, searchQuery, isLoading, error, isSuccess, lastTransaction, pendingOrders, pendingOrderCode, pendingCustomerName, pendingTableId];
}

// Bloc
class PosBloc extends Bloc<PosEvent, PosState> {
  final ProductRepository productRepository;
  final TransactionRepository transactionRepository; 
  final CustomerRepository customerRepository; // Inject

  PosBloc({
    required this.productRepository,
    required this.transactionRepository,
    required this.customerRepository,
  }) : super(const PosState()) {
    on<LoadPosData>(_onLoadData);
    on<FilterProducts>(_onFilterProducts);
    on<AddToCart>(_onAddToCart);
    on<UpdateCartQuanity>(_onUpdateCartQuantity);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<ClearCart>(_onClearCart);
    on<SubmitTransaction>(_onSubmitTransaction);
    on<ScanBarcode>(_onScanBarcode);
    on<AddCustomer>(_onAddCustomer);
    on<FetchPendingOrders>(_onFetchPendingOrders);
    on<BukaProsesPesanan>(_onBukaProsesPesanan);
    on<CancelPendingOrder>(_onCancelPendingOrder);
  }

  Future<void> _onLoadData(LoadPosData event, Emitter<PosState> emit) async {
    emit(state.copyWith(isLoading: true));
    
    // Load Products & Categories
    final productsResult = await productRepository.getProducts();
    final categoriesResult = await productRepository.getCategories();
    final customersResult = await customerRepository.getCustomers(); 
    final employeesResult = await customerRepository.getEmployees(); 
    final tablesResult = await customerRepository.getTables(); // NEW
    
    final products = productsResult.getOrElse(() => []);
    final categories = categoriesResult.getOrElse(() => []);
    final customers = customersResult.getOrElse(() => []); 
    final employees = employeesResult.getOrElse(() => []); 
    final tables = tablesResult.getOrElse(() => []); // NEW
    
    print('DEBUG: PosBloc Loaded ${customers.length} Customers, ${tables.length} Tables');
    
    emit(state.copyWith(
      isLoading: false,
      allProducts: products,
      filteredProducts: products,
      categories: categories,
      customers: customers,
      employees: employees,
      tables: tables, // NEW
      isSuccess: false, // Reset transient flags
      error: null,
    ));
  }

  void _onFilterProducts(FilterProducts event, Emitter<PosState> emit) {
    final categoryId = event.categoryId ?? state.selectedCategoryId;
    final query = event.query; 
    
    // Logic to filter
    List<ProductModel> filtered = state.allProducts.where((p) {
      final matchCategory = categoryId == 0 || p.categoryId == categoryId;
      final matchQuery = p.name.toLowerCase().contains(query.toLowerCase()) || 
                         (p.barcode != null && p.barcode!.contains(query));
      return matchCategory && matchQuery;
    }).toList();

    emit(state.copyWith(
      selectedCategoryId: categoryId,
      searchQuery: query,
      filteredProducts: filtered,
    ));
  }

  void _onAddToCart(AddToCart event, Emitter<PosState> emit) {
    // For services (jasa), we don't merge them purely by product ID if they might have different employees.
    // However, if we simplify: identical product + identical employee = merge.
    final existingIndex = state.cartItems.indexWhere((item) => 
        item.product.id == event.product.id && 
        item.employeeId == event.employeeId
    );

    List<CartItem> newCart;
    if (existingIndex >= 0) {
      newCart = List.from(state.cartItems);
      final item = newCart[existingIndex];
      newCart[existingIndex] = item.copyWith(quantity: item.quantity + event.quantity);
    } else {
      newCart = List.from(state.cartItems)..add(CartItem(
        product: event.product, 
        quantity: event.quantity,
        employeeId: event.employeeId,
        employeeName: event.employeeName,
      ));
    }
    emit(state.copyWith(cartItems: newCart));
  }

  void _onUpdateCartQuantity(UpdateCartQuanity event, Emitter<PosState> emit) {
    if (event.quantity <= 0) {
      add(RemoveFromCart(event.product));
      return;
    }
    final existingIndex = state.cartItems.indexWhere((item) => item.product.id == event.product.id);
    if (existingIndex >= 0) {
      final newCart = List<CartItem>.from(state.cartItems);
      newCart[existingIndex] = newCart[existingIndex].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: newCart));
    }
  }

  void _onRemoveFromCart(RemoveFromCart event, Emitter<PosState> emit) {
    final newCart = state.cartItems.where((item) => item.product.id != event.product.id).toList();
    emit(state.copyWith(cartItems: newCart));
  }
  
  void _onClearCart(ClearCart event, Emitter<PosState> emit) {
    emit(state.copyWith(cartItems: [], clearPendingOrder: true));
  }

  Future<void> _onSubmitTransaction(SubmitTransaction event, Emitter<PosState> emit) async {
    emit(state.copyWith(isLoading: true));
    
    final itemsList = state.cartItems.map((item) => {
        'product_name': item.product.name, 
        'product_id': item.product.id,
        'quantity': item.quantity,
        'price': item.product.sellingPrice, 
        'subtotal': item.subtotal, 
        'employee_id': item.employeeId,
        'employee_name': item.employeeName,
      }).toList();

    final int pointRxRate = event.pointExchangeRate ?? 100;
    final double pointsDiscountAmount = (event.pointsRedeemed ?? 0) * pointRxRate.toDouble();
    double newTotal = state.total - pointsDiscountAmount;
    if (newTotal < 0) newTotal = 0;

    final transactionData = {
      'transaction_code': 'OFFLINE-${DateTime.now().millisecondsSinceEpoch}', 
      'items': itemsList, 
      'payment_method': event.paymentMethod,
      'payment_channel': event.paymentChannel,
      'amount_paid': event.amountPaid,
      'customer_name': event.customerName,
      'customer_id': event.customerId,
      'points_discount_amount': pointsDiscountAmount,
      'total_amount': newTotal,
      'change_amount': event.paymentMethod == 'utang' ? 0 : (event.amountPaid - newTotal),
      'note': event.note,
      'created_at': event.transactionDate != null ? event.transactionDate!.toIso8601String() : DateTime.now().toIso8601String(), // Use backdate
    };
    
    final apiData = {
      'items': itemsList.map((e) => {
        'product_id': e['product_id'], 
        'quantity': e['quantity'],
        'product_name': e['product_name'],
        'employee_id': e['employee_id'],
      }).toList(),
      'payment_method': event.paymentMethod,
      'payment_channel': event.paymentChannel,
      'amount_paid': event.amountPaid,
      'customer_name': event.customerName,
      'customer_id': event.customerId,
      'points_redeemed': event.pointsRedeemed,
      'note': event.note,
      'created_at': transactionData['created_at'],
      'table_id': event.tableId,
      'is_takeaway': event.isTakeaway,
      'pending_order_code': event.pendingOrderCode ?? state.pendingOrderCode,
    };

    final result = await transactionRepository.submitTransaction(apiData);
    
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (serverData) {
        // If server returned data, use its transaction_code (TRX...) 
        // instead of the OFFLINE-... placeholder
        final printData = Map<String, dynamic>.from(transactionData);
        if (serverData != null) {
          printData['transaction_code'] = serverData['transaction_code'] ?? transactionData['transaction_code'];
          // Also update items with server data if available
          if (serverData['items'] != null) {
            printData['items'] = serverData['items'];
          }
          // Propagate Payment Gateway data if present
          if (serverData['payment'] != null) {
            printData['payment'] = serverData['payment'];
            printData['status'] = 'pending';
          }
        }

        emit(state.copyWith(
            isLoading: false, 
            isSuccess: true, 
            cartItems: [],
            lastTransaction: printData,
            clearPendingOrder: true,
        ));
        // Reload products to reflect updated stock
        add(LoadPosData());
      },
    );
  }


  void _onScanBarcode(ScanBarcode event, Emitter<PosState> emit) {
    // plain barcode string
    final barcode = event.barcode.trim();
    if (barcode.isEmpty) return;

    try {
      final product = state.allProducts.firstWhere((p) => p.barcode == barcode);
      add(AddToCart(product));
       // Optional: Clear error if successful
      emit(state.copyWith(error: null));
      // Better to use a one-off error mechanism or clear it on next action.
    } catch (e) {
      emit(state.copyWith(error: 'Product not found for barcode: $barcode'));
    }
  }

  Future<void> _onAddCustomer(AddCustomer event, Emitter<PosState> emit) async {
    emit(state.copyWith(isLoading: true));
    final result = await customerRepository.createCustomer(event.name, event.phone);
    
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (newCustomer) {
        final updatedList = List<CustomerModel>.from(state.customers)..insert(0, newCustomer);
        emit(state.copyWith(
          isLoading: false, 
          customers: updatedList,
          // We can optionally set a flag or just let the UI react to the new list 
          // The UI (PaymentModal) might need to know which one was added to auto-select it.
          // But since we prepend it, index 0 is the new one.
        ));
      }
    );
  }

  Future<void> _onFetchPendingOrders(FetchPendingOrders event, Emitter<PosState> emit) async {
    final result = await transactionRepository.getPendingOrders();
    result.fold(
      (failure) {
        // Silently ignore background polling errors to avoid spamming SnackBars
        print('DEBUG: FetchPendingOrders failed silently: ${failure.message}');
      },
      (orders) => emit(state.copyWith(pendingOrders: orders))
    );
  }

  void _onBukaProsesPesanan(BukaProsesPesanan event, Emitter<PosState> emit) {
    final order = event.order;
    // Clears the current cart and replaces it with the order items
    final List<dynamic> itemsRaw = order['items'] ?? [];
    List<CartItem> newCartItems = [];
    
    for (var raw in itemsRaw) {
      try {
        final product = state.allProducts.firstWhere(
          (p) => p.name == raw['name'] || p.id == raw['id'],
          orElse: () => ProductModel(
            id: raw['id'] ?? 0,
            categoryId: 0,
            name: raw['name'],
            type: raw['type'] ?? 'barang',
            purchasePrice: 0.0,
            sellingPrice: (raw['price'] as num).toDouble(),
            stock: 999,
            minimumStock: 0,
            isLowStock: false,
          )
        );
        newCartItems.add(CartItem(product: product, quantity: raw['qty'] ?? 1));
      } catch (e) {
        print("Error parsing item for order ${order['transaction_code']}: $e");
      }
    }

    // Extract table_id from the order
    int? tableId;
    if (order['table_id'] != null) {
      tableId = order['table_id'] is int ? order['table_id'] : int.tryParse(order['table_id'].toString());
    }

    emit(state.copyWith(
      cartItems: newCartItems,
      pendingOrderCode: order['transaction_code'],
      pendingCustomerName: order['customer_name'],
      pendingTableId: tableId,
    ));
  }

  Future<void> _onCancelPendingOrder(CancelPendingOrder event, Emitter<PosState> emit) async {
    final result = await transactionRepository.updateOrderStatus(event.transactionCode, 'cancelled');
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) {
         // Reload orders if cancel was successful
         add(FetchPendingOrders());
      }
    );
  }
}
