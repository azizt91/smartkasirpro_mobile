import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mobile_app/core/network/auth_interceptor.dart'; // Import

import 'package:mobile_app/core/services/printer_service.dart';
import 'package:mobile_app/core/services/shift_service.dart';
import 'package:mobile_app/core/database/database_helper.dart';

// Auth
import 'package:mobile_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mobile_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';

// Product
import 'package:mobile_app/features/product/data/datasources/product_local_data_source.dart';
import 'package:mobile_app/features/product/data/datasources/product_remote_data_source.dart';
import 'package:mobile_app/features/product/data/repositories/product_repository_impl.dart';
import 'package:mobile_app/features/product/data/repositories/sync_repository_impl.dart';
import 'package:mobile_app/features/product/domain/repositories/product_repository.dart';
import 'package:mobile_app/features/product/presentation/bloc/product_bloc.dart';

// Transaction
import 'package:mobile_app/features/transaction/data/datasources/transaction_local_data_source.dart';
import 'package:mobile_app/features/transaction/data/datasources/transaction_remote_data_source.dart';
import 'package:mobile_app/features/transaction/data/repositories/transaction_repository_impl.dart';
// Note: TransactionRepository interface is in the same file as Impl
// import 'features/transaction/domain/repositories/transaction_repository.dart'; // REMOVED

// Dashboard
import 'package:mobile_app/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:mobile_app/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:mobile_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:mobile_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';

// Stock
import 'package:mobile_app/features/stock/data/datasources/stock_local_data_source.dart';
import 'package:mobile_app/features/stock/data/datasources/stock_remote_data_source.dart';
import 'package:mobile_app/features/stock/data/repositories/stock_repository_impl.dart';
import 'package:mobile_app/features/stock/presentation/bloc/stock_bloc.dart';

// History
import 'package:mobile_app/features/history/presentation/bloc/history_bloc.dart';

// Receivable
// All classes are in one file for Receivable
import 'package:mobile_app/features/receivable/data/repositories/receivable_repository_impl.dart';
import 'package:mobile_app/features/receivable/presentation/bloc/receivable_bloc.dart';

// Expense
// Data Sources are in one file
import 'package:mobile_app/features/expense/data/datasources/expense_data_source.dart';
import 'package:mobile_app/features/expense/data/repositories/expense_repository_impl.dart';
import 'package:mobile_app/features/expense/domain/repositories/expense_repository.dart'; // Import Interface
import 'package:mobile_app/features/expense/presentation/bloc/expense_bloc.dart';

// POS
import 'package:mobile_app/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:mobile_app/features/pos/data/repositories/customer_repository.dart';
import 'package:mobile_app/features/others/presentation/bloc/customer_bloc.dart'; // Import

// Kitchen
import 'package:mobile_app/features/kitchen/presentation/bloc/kitchen_bloc.dart';

// Notification Imports
import 'package:mobile_app/features/notification/data/datasources/notification_remote_data_source.dart';
import 'package:mobile_app/features/notification/data/repositories/notification_repository.dart';
import 'package:mobile_app/features/notification/presentation/bloc/notification_bloc.dart';


final sl = GetIt.instance;

Future<void> init() async {
  // Key Objects
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton<PrinterService>(() => PrinterService());
  sl.registerLazySingleton<ShiftService>(() => ShiftService(dio: sl()));

  sl.registerLazySingleton(() {
    final dio = Dio();
    dio.options.baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000/api';
    dio.options.connectTimeout = const Duration(seconds: 90);
    dio.options.receiveTimeout = const Duration(seconds: 90);
    dio.options.headers = {
       'Accept': 'application/json',
       'Content-Type': 'application/json',
    };
    dio.interceptors.add(AuthInterceptor(secureStorage: sl()));
    
    // Log Interceptor for debugging
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
    ));

    return dio;
  });
  
  // -- AuthInterceptor --
  // We can just use the registerLazySingleton logic inside dio factory or register it separately if needed by others
  // But here we instantiating it directly inside Dio factory as it depends on secureStorage which is already registered.


  // -- Auth --
  sl.registerFactory(() => AuthBloc(loginUseCase: sl(), authRepository: sl()));
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(remoteDataSource: sl(), secureStorage: sl(), databaseHelper: DatabaseHelper.instance));
  sl.registerLazySingleton<AuthRemoteDataSource>(() => AuthRemoteDataSourceImpl(dio: sl()));

  // -- Product --
  sl.registerFactory(() => ProductBloc(productRepository: sl(), syncRepository: sl()));
  sl.registerLazySingleton<ProductLocalDataSource>(() => ProductLocalDataSourceImpl(databaseHelper: DatabaseHelper.instance, sharedPreferences: sl()));
  sl.registerLazySingleton<ProductRemoteDataSource>(() => ProductRemoteDataSourceImpl(dio: sl()));
  sl.registerLazySingleton<ProductRepository>(() => ProductRepositoryImpl(localDataSource: sl()));
  sl.registerLazySingleton<SyncRepository>(() => SyncRepositoryImpl(localDataSource: sl(), remoteDataSource: sl(), transactionRepository: sl()));

  // -- Transaction --
  sl.registerLazySingleton<TransactionLocalDataSource>(() => TransactionLocalDataSourceImpl(databaseHelper: DatabaseHelper.instance));
  sl.registerLazySingleton<TransactionRemoteDataSource>(() => TransactionRemoteDataSourceImpl(dio: sl()));
  // TransactionRepository is defined in the same file as Impl
  sl.registerLazySingleton<TransactionRepository>(() => TransactionRepositoryImpl(localDataSource: sl(), remoteDataSource: sl()));

  // -- Dashboard --
  sl.registerFactory(() => DashboardBloc(repository: sl()));
  sl.registerLazySingleton<DashboardRemoteDataSource>(() => DashboardRemoteDataSourceImpl(dio: sl()));
  sl.registerLazySingleton<DashboardRepository>(() => DashboardRepositoryImpl(remoteDataSource: sl(), transactionLocalDataSource: sl()));

  // -- POS --
  // Customer Repo
  sl.registerLazySingleton<CustomerRepository>(() => CustomerRepository(dio: sl(), secureStorage: sl()));
  
  sl.registerFactory(() => PosBloc(
    productRepository: sl(), 
    transactionRepository: sl(),
    customerRepository: sl(), // Inject CustomerRepo
  ));

  // -- Kitchen --
  sl.registerFactory(() => KitchenBloc(transactionRepository: sl()));

  // -- Stock --
  sl.registerFactory(() => StockBloc(repository: sl()));
  sl.registerLazySingleton<StockLocalDataSource>(() => StockLocalDataSourceImpl(databaseHelper: DatabaseHelper.instance));
  sl.registerLazySingleton<StockRemoteDataSource>(() => StockRemoteDataSourceImpl(dio: sl()));
  sl.registerLazySingleton<StockRepositoryImpl>(() => StockRepositoryImpl(localDataSource: sl(), remoteDataSource: sl()));

  // -- History --
  sl.registerFactory(() => HistoryBloc(repository: sl()));

  // -- Others / Customer --
  sl.registerFactory(() => CustomerBloc(repository: sl()));

  // -- Receivable --
  sl.registerFactory(() => ReceivableBloc(repository: sl()));
  sl.registerLazySingleton<ReceivableLocalDataSource>(() => ReceivableLocalDataSourceImpl(databaseHelper: DatabaseHelper.instance));
  sl.registerLazySingleton<ReceivableRemoteDataSource>(() => ReceivableRemoteDataSourceImpl(dio: sl()));
  sl.registerLazySingleton<ReceivableRepositoryImpl>(() => ReceivableRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()));

  // -- Expense --
  sl.registerFactory(() => ExpenseBloc(repository: sl()));
  sl.registerLazySingleton<ExpenseLocalDataSource>(() => ExpenseLocalDataSourceImpl(databaseHelper: DatabaseHelper.instance));
  sl.registerLazySingleton<ExpenseRemoteDataSource>(() => ExpenseRemoteDataSourceImpl(dio: sl()));
  // Removed duplicate RemoteDataSource line
  sl.registerLazySingleton<ExpenseRepository>(() => ExpenseRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()));

  // -- Notification --
  sl.registerFactory(() => NotificationBloc(repository: sl()));
  sl.registerLazySingleton<NotificationRemoteDataSource>(() => NotificationRemoteDataSourceImpl(dio: sl()));
  sl.registerLazySingleton<NotificationRepository>(() => NotificationRepositoryImpl(remoteDataSource: sl()));
}
