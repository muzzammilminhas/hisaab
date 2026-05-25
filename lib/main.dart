import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

// ── Hive Models (Part 2) ──────────────────────────────────────────────────────
// Each import brings in both the model class AND its generated adapter
// because the .g.dart files use `part of 'xxx_model.dart'`
import 'models/member_model.dart';   // Member  + MemberAdapter  (typeId: 0)
import 'models/expense_model.dart';  // Expense + ExpenseAdapter (typeId: 1)
import 'models/trip_model.dart';     // Trip    + TripAdapter    (typeId: 2)

// ── State Management (Part 3) ─────────────────────────────────────────────────
import 'providers/trip_provider.dart';

// ── Root UI Screen (Part 4) ───────────────────────────────────────────────────
import 'views/home/home_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// ENTRY POINT
///
/// Boot sequence:
///   1. Ensure Flutter engine is ready for async work
///   2. Lock orientation to portrait (expense app doesn't need landscape)
///   3. Initialise Hive with the correct Flutter app-documents path
///   4. Register the three TypeAdapters (Member → 0, Expense → 1, Trip → 2)
///   5. Open the single 'trips_box' Hive box used by TripProvider
///   6. Mount the app with Provider + MaterialApp
/// ─────────────────────────────────────────────────────────────────────────────
Future<void> main() async {
  // Required before any async work before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — the layout is optimised for vertical scrolling
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── 1. Initialise Hive ─────────────────────────────────────────────────────
  // initFlutter() is an extension from hive_flutter — it resolves the correct
  // app documents directory on Android (/data/data/<pkg>/files/hive)
  await Hive.initFlutter();

  // ── 2. Register TypeAdapters ───────────────────────────────────────────────
  // Adapters MUST be registered before opening any box that stores that type.
  // Registration order does not matter; typeId uniqueness does.
  //
  // typeId 0 → Member    (member_model.g.dart  :: MemberAdapter)
  // typeId 1 → Expense   (expense_model.g.dart :: ExpenseAdapter)
  // typeId 2 → Trip      (trip_model.g.dart    :: TripAdapter)
  //
  // Trip embeds List<Member> and List<Expense>, so all three adapters must
  // be registered before the 'trips_box' box is opened below.
  Hive.registerAdapter(MemberAdapter());
  Hive.registerAdapter(ExpenseAdapter());
  Hive.registerAdapter(TripAdapter());

  // ── 3. Open the root Hive box ──────────────────────────────────────────────
  // One box holds ALL Trip documents (document-oriented / NoSQL style).
  // TripProvider accesses this box via Hive.box<Trip>('trips_box') — it must
  // already be open before TripProvider._init() runs (which it will be here).
  await Hive.openBox<Trip>('trips_box');

  runApp(const HisaabApp());
}

/// Root widget — stateless, responsible only for wiring theme and providers.
class HisaabApp extends StatelessWidget {
  const HisaabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // TripProvider is created once at app start and lives for the full
      // app lifecycle. It reads from the already-open 'trips_box' in its
      // constructor via _init() → _loadTrips().
      create: (_) => TripProvider(),
      child: MaterialApp(
        title: 'Hisaab',
        debugShowCheckedModeBanner: false,

        // ── Themes ──────────────────────────────────────────────────────────
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),

        // Automatically follows the device system setting.
        // The user can override in Settings > Display on Android.
        themeMode: ThemeMode.system,

        home: const HomeScreen(),
      ),
    );
  }

  /// Builds a full Material 3 [ThemeData] from a single seed colour.
  ///
  /// [ColorScheme.fromSeed] generates the entire M3 tonal palette — every
  /// token used across all Part 2–5 files (surfaceContainerHighest,
  /// onSurfaceVariant, primaryContainer, outlineVariant, etc.) is derived
  /// automatically from this one seed.
  ThemeData _buildTheme(Brightness brightness) {
    // Seed: deep indigo/blue — evokes maps, travel, and navigation.
    // Change this one color to completely re-skin the entire app.
    const Color seedColor = Color(0xFF4A6CF7);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // ── AppBar ─────────────────────────────────────────────────────────────
      // elevation: 0 gives a flat look; scrolledUnderElevation adds a subtle
      // shadow when content scrolls beneath — used in HomeScreen SliverAppBar
      // and TripDashboard NestedScrollView.
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),

      // ── Cards ──────────────────────────────────────────────────────────────
      // Used by: TripCard, _ExpenseTile, _MemberSummaryCard, _SettlementCard
      // CardTheme was renamed to CardThemeData in Flutter 3.22+
      cardTheme: CardThemeData(
        elevation: 1,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ── Floating Action Button ─────────────────────────────────────────────
      // Used by: HomeScreen FAB ("New Trip") and TripDashboard FAB ("Add Expense")
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 3,
      ),

      // ── Input Fields ───────────────────────────────────────────────────────
      // Shared style for ALL TextFormField widgets across:
      //   AddEditTripSheet, AddEditExpenseSheet, ManageMembersSheet
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
      ),

      // ── Chips ──────────────────────────────────────────────────────────────
      // Used by: MemberSelectChip in AddEditExpenseSheet (split-among section)
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),

      // ── Bottom Sheets ──────────────────────────────────────────────────────
      // All three sheets (AddEditTrip, AddEditExpense, ManageMembers) use
      // showModalBottomSheet with backgroundColor: Colors.transparent, so
      // the container itself controls the background. This theme entry
      // handles any system-level sheet chrome.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: false, // We draw our own handle bar in each sheet
      ),

      // ── Dialogs ────────────────────────────────────────────────────────────
      // Used by: DeleteConfirmDialog and the rename-member AlertDialog
      // DialogTheme was renamed to DialogThemeData in Flutter 3.22+
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        surfaceTintColor: colorScheme.surfaceTint,
      ),

      // ── Popup Menu ─────────────────────────────────────────────────────────
      // Used by: TripCard context menu and TripDashboard app bar overflow menu
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 3,
      ),

      // ── Tab Bar ────────────────────────────────────────────────────────────
      // Used by: TripDashboard — "Expenses" and "Balances" tabs
      // TabBarTheme was renamed to TabBarThemeData in Flutter 3.22+
      tabBarTheme: TabBarThemeData(
        indicatorColor: colorScheme.primary,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: colorScheme.outlineVariant,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ── List Tile ──────────────────────────────────────────────────────────
      // Used by: ManageMembersSheet member list
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),

      // ── Snack Bar ──────────────────────────────────────────────────────────
      // Used by: AddEditExpenseSheet validation messages
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
    );
  }
}
