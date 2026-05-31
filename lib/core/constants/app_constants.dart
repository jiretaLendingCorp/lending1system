// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  static const String companyName    = 'Jireta Loans & Credit Corp. 1996';
  static const String companyShort   = 'Jireta Loans';
  static const String companyAddress = 'Sta. Barbara, Pangasinan';
  static const String companyTagline = 'Your Trusted Lending Partner Since 1996';

  static const String supabaseUrl     = 'https://xyhqvpbrxbgiduobkbhl.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5aHF2cGJyeGJnaWR1b2JrYmhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyMzE3ODcsImV4cCI6MjA5NTgwNzc4N30.u9OXN9vScW9gEeCdHewQJoJRErwraDEIoIO63W3jLqs';

  static String get edgeFunctionsUrl => '$supabaseUrl/functions/v1';

  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  static const String bucketProfiles   = 'profile-pictures';
  static const String bucketDocuments  = 'lender-documents';
  static const String bucketCiPhotos   = 'ci-report-photos';
  static const String bucketReceipts   = 'payment-receipts';
  static const String bucketSignatures = 'signatures';

  static const double minLoanAmount   = 5000.0;
  static const double maxLoanAmount   = 500000.0;
  static const double defaultInterest = 10.0;

  static const int lenderSessionTimeoutMinutes = 10;

  static const int maxFileSizeMb    = 10;
  static const int maxFileSizeBytes = 10 * 1024 * 1024;
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedDocExtensions   = ['jpg', 'jpeg', 'png', 'pdf'];
  static const List<String> allowedMimeTypes = [
    'image/jpeg', 'image/png', 'application/pdf',
  ];

  static const int defaultPageSize = 20;
  static const int maxPageSize     = 100;

  static const int minPasswordLength = 8;
  static const int minNameLength     = 2;
  static const int maxNameLength     = 100;
  static const int phoneNumberLength = 11;
  static const int minRemarksLength  = 10;

  static final RegExp phoneRegex    = RegExp(r'^(09|\+639)\d{9}$');
  static final RegExp emailRegex    = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&_#^()\-+=])[A-Za-z\d@$!%*?&_#^()\-+=]{8,}$',
  );

  static const Duration fastAnim   = Duration(milliseconds: 200);
  static const Duration normalAnim = Duration(milliseconds: 350);
  static const Duration slowAnim   = Duration(milliseconds: 500);
  static const Duration pageAnim   = Duration(milliseconds: 400);

  static const String channelLoans         = 'loans-realtime';
  static const String channelCollections   = 'collections-realtime';
  static const String channelNotifications = 'notifications-realtime';
  static const String channelPayments      = 'payments-realtime';
  static const String channelRiders        = 'riders-realtime';

  static const String keyThemeMode     = 'theme_mode';
  static const String keyOnboarded     = 'onboarded';
  static const String keyLastUserId    = 'last_user_id';
  static const String keyBiometricAuth = 'biometric_auth';

  static const String routeSplash         = '/';
  static const String routeWebLogin       = '/web/login';
  static const String routeMobileLogin    = '/mobile/login';
  static const String routeRegister       = '/mobile/register';
  static const String routeForgotPassword = '/forgot-password';

  static const String routeWebDashboard   = '/web/dashboard';
  static const String routeWebEmployees   = '/web/employees';
  static const String routeWebRiders      = '/web/riders';
  static const String routeWebLenders     = '/web/lenders';
  static const String routeWebLoans       = '/web/loans';
  static const String routeWebLoanDetail  = '/web/loans/:id';
  static const String routeWebCollections = '/web/collections';
  static const String routeWebCI          = '/web/ci';
  static const String routeWebReports     = '/web/reports';
  static const String routeWebSettings    = '/web/settings';
  static const String routeWebAuditLogs   = '/web/audit-logs';
  static const String routeWebProfile     = '/web/profile';

  static const String routeRiderDashboard     = '/rider/dashboard';
  static const String routeRiderAssignments   = '/rider/assignments';
  static const String routeRiderMap           = '/rider/map/:assignmentId';
  static const String routeRiderCI            = '/rider/ci/:assignmentId';
  static const String routeRiderCollect       = '/rider/collect/:collectionId';
  static const String routeRiderHistory       = '/rider/history';
  static const String routeRiderProfile       = '/rider/profile';
  static const String routeRiderNotifications = '/rider/notifications';

  static const String routeLenderDashboard     = '/lender/dashboard';
  static const String routeLenderApply         = '/lender/apply';
  static const String routeLenderLoans         = '/lender/loans';
  static const String routeLenderLoanDetail    = '/lender/loans/:id';
  static const String routeLenderPay           = '/lender/pay/:loanId';
  static const String routeLenderDocuments     = '/lender/documents';
  static const String routeLenderHistory       = '/lender/history';
  static const String routeLenderProfile       = '/lender/profile';
  static const String routeLenderNotifications = '/lender/notifications';
  static const String routeLenderCodeHistory   = '/lender/code-history';
}