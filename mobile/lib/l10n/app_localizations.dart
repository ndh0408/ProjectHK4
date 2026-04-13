import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// The app name
  ///
  /// In en, this message translates to:
  /// **'LUMA'**
  String get appName;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Explore tab label
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// My Events tab label
  ///
  /// In en, this message translates to:
  /// **'My Events'**
  String get myEvents;

  /// Alerts tab label
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// Profile tab label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Your Events section title
  ///
  /// In en, this message translates to:
  /// **'Your Events'**
  String get yourEvents;

  /// View all button text
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// Picked for You section title
  ///
  /// In en, this message translates to:
  /// **'Picked for You'**
  String get pickedForYou;

  /// Nearby filter option
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// All the World filter option
  ///
  /// In en, this message translates to:
  /// **'All the World'**
  String get allTheWorld;

  /// No upcoming events title
  ///
  /// In en, this message translates to:
  /// **'No Upcoming Events'**
  String get noUpcomingEvents;

  /// No upcoming events subtitle
  ///
  /// In en, this message translates to:
  /// **'Events you are hosting or going to will show up here.'**
  String get noUpcomingEventsSubtitle;

  /// No events found message
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get noEventsFound;

  /// Try changing filter suggestion
  ///
  /// In en, this message translates to:
  /// **'Try changing the location filter'**
  String get tryChangingFilter;

  /// Today label
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Tomorrow label
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// Registered badge text
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get registered;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Logout button text
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Welcome back title
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// Sign in subtitle
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// Don't have account text
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// Sign up link/button
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Or continue with text
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get orContinueWith;

  /// Settings title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Vietnamese language name
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get vietnamese;

  /// Notifications title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Messages tab
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// Send button
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Type message placeholder
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// Delete action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirm action
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Error title
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Retry action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Loading text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Contact host button
  ///
  /// In en, this message translates to:
  /// **'Contact Host'**
  String get contactHost;

  /// Register button
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Unregister button
  ///
  /// In en, this message translates to:
  /// **'Unregister'**
  String get unregister;

  /// Event details title
  ///
  /// In en, this message translates to:
  /// **'Event Details'**
  String get eventDetails;

  /// About section
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Location label
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Date and time label
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateAndTime;

  /// Host label
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// Guests label
  ///
  /// In en, this message translates to:
  /// **'Guests'**
  String get guests;

  /// Ask question button
  ///
  /// In en, this message translates to:
  /// **'Ask a Question'**
  String get askQuestion;

  /// Edit profile button
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// Full name field
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// Phone field
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Create event button
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get createEvent;

  /// Event title field
  ///
  /// In en, this message translates to:
  /// **'Event Title'**
  String get eventTitle;

  /// Description field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Start date field
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// End date field
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// Capacity field
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get capacity;

  /// Price field
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// Free price label
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// Paid label
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// Pending status
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Approved status
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// Rejected status
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// Delete chat dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Chat'**
  String get deleteChat;

  /// Delete chat confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this chat?'**
  String get deleteChatConfirm;

  /// Chat deleted message
  ///
  /// In en, this message translates to:
  /// **'Chat deleted'**
  String get chatDeleted;

  /// Conversation deleted message
  ///
  /// In en, this message translates to:
  /// **'Conversation deleted'**
  String get conversationDeleted;

  /// Continue with email button
  ///
  /// In en, this message translates to:
  /// **'Continue with Email'**
  String get continueWithEmail;

  /// Create account button
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Sign in button
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Already have account text
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Login screen title
  ///
  /// In en, this message translates to:
  /// **'Delightful events'**
  String get delightfulEvents;

  /// Login screen subtitle
  ///
  /// In en, this message translates to:
  /// **'start here'**
  String get startHere;

  /// Login screen description
  ///
  /// In en, this message translates to:
  /// **'Discover events, subscribe to calendars and manage events you are going to.'**
  String get loginDescription;

  /// Email validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// Invalid email validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// Password validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// Password too short validation message
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// Full name validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get pleaseEnterFullName;

  /// Upcoming events section
  ///
  /// In en, this message translates to:
  /// **'Upcoming Events'**
  String get upcomingEvents;

  /// Past events section
  ///
  /// In en, this message translates to:
  /// **'Past Events'**
  String get pastEvents;

  /// Search events placeholder
  ///
  /// In en, this message translates to:
  /// **'Search events'**
  String get searchEvents;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @organisers.
  ///
  /// In en, this message translates to:
  /// **'Organisers'**
  String get organisers;

  /// No description provided for @cities.
  ///
  /// In en, this message translates to:
  /// **'Cities'**
  String get cities;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @conversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get conversations;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @paymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment Success'**
  String get paymentSuccess;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment Cancelled'**
  String get paymentCancelled;

  /// No description provided for @registrationForm.
  ///
  /// In en, this message translates to:
  /// **'Registration Form'**
  String get registrationForm;

  /// No description provided for @myCreatedEvents.
  ///
  /// In en, this message translates to:
  /// **'My Created Events'**
  String get myCreatedEvents;

  /// No description provided for @editEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get editEvent;

  /// No description provided for @eventRegistrations.
  ///
  /// In en, this message translates to:
  /// **'Registrations'**
  String get eventRegistrations;

  /// No description provided for @speakerEvents.
  ///
  /// In en, this message translates to:
  /// **'Speaker Events'**
  String get speakerEvents;

  /// No description provided for @ticket.
  ///
  /// In en, this message translates to:
  /// **'Ticket'**
  String get ticket;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get verifyOtp;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get enterOtp;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @descriptionEditor.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionEditor;

  /// No description provided for @organiserProfile.
  ///
  /// In en, this message translates to:
  /// **'Organiser Profile'**
  String get organiserProfile;

  /// No description provided for @waitlist.
  ///
  /// In en, this message translates to:
  /// **'Waitlist'**
  String get waitlist;

  /// No description provided for @almostFull.
  ///
  /// In en, this message translates to:
  /// **'Almost Full'**
  String get almostFull;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No Notifications'**
  String get noNotifications;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No Messages'**
  String get noMessages;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No Conversations'**
  String get noConversations;

  /// No description provided for @popularEvents.
  ///
  /// In en, this message translates to:
  /// **'Popular Events'**
  String get popularEvents;

  /// No description provided for @browseByCategory.
  ///
  /// In en, this message translates to:
  /// **'Browse by Category'**
  String get browseByCategory;

  /// No description provided for @featuredCalendars.
  ///
  /// In en, this message translates to:
  /// **'Featured Calendars'**
  String get featuredCalendars;

  /// No description provided for @noUpcomingEventsShort.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events'**
  String get noUpcomingEventsShort;

  /// No description provided for @soldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold Out'**
  String get soldOut;

  /// No description provided for @confirmRegistration.
  ///
  /// In en, this message translates to:
  /// **'Confirm Registration'**
  String get confirmRegistration;

  /// No description provided for @joinWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join Waitlist'**
  String get joinWaitlist;

  /// No description provided for @youAreRegistered.
  ///
  /// In en, this message translates to:
  /// **'You are registered'**
  String get youAreRegistered;

  /// No description provided for @paymentRequired.
  ///
  /// In en, this message translates to:
  /// **'Payment Required'**
  String get paymentRequired;

  /// No description provided for @onWaitingList.
  ///
  /// In en, this message translates to:
  /// **'On Waiting List'**
  String get onWaitingList;

  /// No description provided for @waitingListPosition.
  ///
  /// In en, this message translates to:
  /// **'Waiting List #{position}'**
  String waitingListPosition(Object position);

  /// No description provided for @pendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get pendingApproval;

  /// No description provided for @registrationRejected.
  ///
  /// In en, this message translates to:
  /// **'Registration Rejected'**
  String get registrationRejected;

  /// No description provided for @registrationConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Registration confirmed'**
  String get registrationConfirmed;

  /// No description provided for @eventOrganiser.
  ///
  /// In en, this message translates to:
  /// **'Event Organiser'**
  String get eventOrganiser;

  /// No description provided for @tapToViewProfile.
  ///
  /// In en, this message translates to:
  /// **'Tap to view profile'**
  String get tapToViewProfile;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @aboutThisEvent.
  ///
  /// In en, this message translates to:
  /// **'About This Event'**
  String get aboutThisEvent;

  /// No description provided for @speakers.
  ///
  /// In en, this message translates to:
  /// **'Speakers'**
  String get speakers;

  /// No description provided for @tapToSeeEvents.
  ///
  /// In en, this message translates to:
  /// **'Tap to see events'**
  String get tapToSeeEvents;

  /// No description provided for @youAreTheOrganiser.
  ///
  /// In en, this message translates to:
  /// **'You are the organiser'**
  String get youAreTheOrganiser;

  /// No description provided for @registrations.
  ///
  /// In en, this message translates to:
  /// **'Registrations'**
  String get registrations;

  /// No description provided for @openMaps.
  ///
  /// In en, this message translates to:
  /// **'Open Maps'**
  String get openMaps;

  /// No description provided for @tapToOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Tap to open in Maps'**
  String get tapToOpenInMaps;

  /// No description provided for @deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete Message'**
  String get deleteMessage;

  /// No description provided for @deleteMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message?'**
  String get deleteMessageConfirm;

  /// No description provided for @thisMessageWasDeleted.
  ///
  /// In en, this message translates to:
  /// **'This message was deleted'**
  String get thisMessageWasDeleted;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @sendMessageToStart.
  ///
  /// In en, this message translates to:
  /// **'Send a message to start the conversation'**
  String get sendMessageToStart;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String members(int count);

  /// No description provided for @imageUploadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Image uploaded successfully'**
  String get imageUploadedSuccessfully;

  /// No description provided for @failedToUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload image'**
  String get failedToUploadImage;

  /// No description provided for @eventName.
  ///
  /// In en, this message translates to:
  /// **'Event Name'**
  String get eventName;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @chooseLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose Location'**
  String get chooseLocation;

  /// No description provided for @venueName.
  ///
  /// In en, this message translates to:
  /// **'Venue name'**
  String get venueName;

  /// No description provided for @latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get longitude;

  /// No description provided for @tapOnMapOrEnterCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Tap on map or enter coordinates manually'**
  String get tapOnMapOrEnterCoordinates;

  /// No description provided for @saveLocation.
  ///
  /// In en, this message translates to:
  /// **'Save Location'**
  String get saveLocation;

  /// No description provided for @addDescription.
  ///
  /// In en, this message translates to:
  /// **'Add Description'**
  String get addDescription;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get selectCategory;

  /// No description provided for @loadingCategories.
  ///
  /// In en, this message translates to:
  /// **'Loading categories...'**
  String get loadingCategories;

  /// No description provided for @selectCity.
  ///
  /// In en, this message translates to:
  /// **'Select City'**
  String get selectCity;

  /// No description provided for @loadingCities.
  ///
  /// In en, this message translates to:
  /// **'Loading cities...'**
  String get loadingCities;

  /// No description provided for @ticketing.
  ///
  /// In en, this message translates to:
  /// **'Ticketing'**
  String get ticketing;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @freeEvent.
  ///
  /// In en, this message translates to:
  /// **'Free Event'**
  String get freeEvent;

  /// No description provided for @ticketPrice.
  ///
  /// In en, this message translates to:
  /// **'Ticket Price'**
  String get ticketPrice;

  /// No description provided for @eventVisibility.
  ///
  /// In en, this message translates to:
  /// **'Event Visibility'**
  String get eventVisibility;

  /// No description provided for @visibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get visibility;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// No description provided for @anyoneCanDiscover.
  ///
  /// In en, this message translates to:
  /// **'Anyone can discover this event'**
  String get anyoneCanDiscover;

  /// No description provided for @onlyPeopleWithLink.
  ///
  /// In en, this message translates to:
  /// **'Only people with link can see'**
  String get onlyPeopleWithLink;

  /// No description provided for @anyoneCanSeeAndJoin.
  ///
  /// In en, this message translates to:
  /// **'Anyone can see and join'**
  String get anyoneCanSeeAndJoin;

  /// No description provided for @onlyInvitedCanSee.
  ///
  /// In en, this message translates to:
  /// **'Only invited people can see'**
  String get onlyInvitedCanSee;

  /// No description provided for @eventCapacity.
  ///
  /// In en, this message translates to:
  /// **'Event Capacity'**
  String get eventCapacity;

  /// No description provided for @unlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// No description provided for @maximumAttendees.
  ///
  /// In en, this message translates to:
  /// **'Maximum attendees'**
  String get maximumAttendees;

  /// No description provided for @leaveEmptyForUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for unlimited'**
  String get leaveEmptyForUnlimited;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @addCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Add Cover Image'**
  String get addCoverImage;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploaded;

  /// No description provided for @eventCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Event created successfully! Waiting for approval.'**
  String get eventCreatedSuccessfully;

  /// No description provided for @eventUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Event updated successfully!'**
  String get eventUpdatedSuccessfully;

  /// No description provided for @eventUpdatedAndResubmitted.
  ///
  /// In en, this message translates to:
  /// **'Event updated and resubmitted for approval!'**
  String get eventUpdatedAndResubmitted;

  /// No description provided for @saveResubmit.
  ///
  /// In en, this message translates to:
  /// **'Save & Resubmit'**
  String get saveResubmit;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @eventWasRejected.
  ///
  /// In en, this message translates to:
  /// **'Event was rejected'**
  String get eventWasRejected;

  /// No description provided for @pleaseUpdateAndResubmit.
  ///
  /// In en, this message translates to:
  /// **'Please update your event and save to resubmit for approval.'**
  String get pleaseUpdateAndResubmit;

  /// No description provided for @pleaseEnterEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter event title'**
  String get pleaseEnterEventTitle;

  /// No description provided for @pleaseSelectStartAndEndTime.
  ///
  /// In en, this message translates to:
  /// **'Please select start and end time'**
  String get pleaseSelectStartAndEndTime;

  /// No description provided for @completePayment.
  ///
  /// In en, this message translates to:
  /// **'Complete Payment'**
  String get completePayment;

  /// No description provided for @newWindowOpened.
  ///
  /// In en, this message translates to:
  /// **'A new window has opened for payment.'**
  String get newWindowOpened;

  /// No description provided for @afterCompletingPayment.
  ///
  /// In en, this message translates to:
  /// **'After completing payment:'**
  String get afterCompletingPayment;

  /// No description provided for @youWillBeRedirected.
  ///
  /// In en, this message translates to:
  /// **'You will be redirected back'**
  String get youWillBeRedirected;

  /// No description provided for @yourRegistrationConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Your registration will be confirmed'**
  String get yourRegistrationConfirmed;

  /// No description provided for @checkPopupBlocker.
  ///
  /// In en, this message translates to:
  /// **'If the payment window did not open, please check your popup blocker.'**
  String get checkPopupBlocker;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @iveCompletedPayment.
  ///
  /// In en, this message translates to:
  /// **'I\'ve Completed Payment'**
  String get iveCompletedPayment;

  /// No description provided for @paymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful!'**
  String get paymentSuccessful;

  /// No description provided for @yourRegistrationHasBeenConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Your registration has been confirmed.'**
  String get yourRegistrationHasBeenConfirmed;

  /// No description provided for @viewMyTicket.
  ///
  /// In en, this message translates to:
  /// **'View My Ticket'**
  String get viewMyTicket;

  /// No description provided for @paymentNotYetConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Payment not yet confirmed. Please complete payment in the opened window.'**
  String get paymentNotYetConfirmed;

  /// No description provided for @paymentNotReady.
  ///
  /// In en, this message translates to:
  /// **'Payment not ready. Please wait...'**
  String get paymentNotReady;

  /// No description provided for @paymentCancelledByUser.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get paymentCancelledByUser;

  /// No description provided for @processingPayment.
  ///
  /// In en, this message translates to:
  /// **'Processing payment...'**
  String get processingPayment;

  /// No description provided for @registrationFee.
  ///
  /// In en, this message translates to:
  /// **'Registration Fee'**
  String get registrationFee;

  /// No description provided for @paymentReady.
  ///
  /// In en, this message translates to:
  /// **'Payment ready. Click the button below to proceed.'**
  String get paymentReady;

  /// No description provided for @paymentReadyWeb.
  ///
  /// In en, this message translates to:
  /// **'Payment ready. Click the button below to open secure checkout.'**
  String get paymentReadyWeb;

  /// No description provided for @paymentWillOpenInNewWindow.
  ///
  /// In en, this message translates to:
  /// **'Payment will open in a new window'**
  String get paymentWillOpenInNewWindow;

  /// No description provided for @securePaymentByStripe.
  ///
  /// In en, this message translates to:
  /// **'Secure payment powered by Stripe'**
  String get securePaymentByStripe;

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// No description provided for @checkPaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Check Payment Status'**
  String get checkPaymentStatus;

  /// No description provided for @testMode.
  ///
  /// In en, this message translates to:
  /// **'Test Mode'**
  String get testMode;

  /// No description provided for @useTestCard.
  ///
  /// In en, this message translates to:
  /// **'Use test card: 4242 4242 4242 4242'**
  String get useTestCard;

  /// No description provided for @testCardExpiry.
  ///
  /// In en, this message translates to:
  /// **'Exp: Any future date | CVC: Any 3 digits'**
  String get testCardExpiry;

  /// No description provided for @alreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'You are already registered for this event!'**
  String get alreadyRegistered;

  /// No description provided for @successfullyRegistered.
  ///
  /// In en, this message translates to:
  /// **'Successfully registered!'**
  String get successfullyRegistered;

  /// No description provided for @addedToWaitlistSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Added to waitlist successfully!'**
  String get addedToWaitlistSuccessfully;

  /// No description provided for @loadingQuestions.
  ///
  /// In en, this message translates to:
  /// **'Loading questions...'**
  String get loadingQuestions;

  /// No description provided for @noQuestions.
  ///
  /// In en, this message translates to:
  /// **'No Questions'**
  String get noQuestions;

  /// No description provided for @noQuestionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Questions you ask about events will appear here'**
  String get noQuestionsSubtitle;

  /// No description provided for @fillOutFormToComplete.
  ///
  /// In en, this message translates to:
  /// **'Please fill out the form below to complete your registration.'**
  String get fillOutFormToComplete;

  /// No description provided for @enterYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Enter your answer'**
  String get enterYourAnswer;

  /// No description provided for @submitRegistration.
  ///
  /// In en, this message translates to:
  /// **'Submit Registration'**
  String get submitRegistration;

  /// No description provided for @continueToPayment.
  ///
  /// In en, this message translates to:
  /// **'Continue to Payment'**
  String get continueToPayment;

  /// No description provided for @pleaseEnterYourQuestion.
  ///
  /// In en, this message translates to:
  /// **'Please enter your question'**
  String get pleaseEnterYourQuestion;

  /// No description provided for @questionSentSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Question sent successfully!'**
  String get questionSentSuccessfully;

  /// No description provided for @enterQuestionForHost.
  ///
  /// In en, this message translates to:
  /// **'Please enter your question for the host...'**
  String get enterQuestionForHost;

  /// No description provided for @eventDescription.
  ///
  /// In en, this message translates to:
  /// **'Event Description'**
  String get eventDescription;

  /// No description provided for @write.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get write;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @italic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get italic;

  /// No description provided for @strikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get strikethrough;

  /// No description provided for @heading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get heading;

  /// No description provided for @bulletList.
  ///
  /// In en, this message translates to:
  /// **'Bullet List'**
  String get bulletList;

  /// No description provided for @numberedList.
  ///
  /// In en, this message translates to:
  /// **'Numbered List'**
  String get numberedList;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @quote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get quote;

  /// No description provided for @horizontalRule.
  ///
  /// In en, this message translates to:
  /// **'Horizontal Rule'**
  String get horizontalRule;

  /// No description provided for @insertLink.
  ///
  /// In en, this message translates to:
  /// **'Insert Link'**
  String get insertLink;

  /// No description provided for @linkText.
  ///
  /// In en, this message translates to:
  /// **'Link Text'**
  String get linkText;

  /// No description provided for @url.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get url;

  /// No description provided for @insert.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get insert;

  /// No description provided for @nothingToPreview.
  ///
  /// In en, this message translates to:
  /// **'Nothing to preview'**
  String get nothingToPreview;

  /// No description provided for @startWritingToPreview.
  ///
  /// In en, this message translates to:
  /// **'Start writing to see the preview'**
  String get startWritingToPreview;

  /// No description provided for @supportsMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Supports Markdown formatting'**
  String get supportsMarkdown;

  /// No description provided for @characters.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String characters(int count);

  /// No description provided for @describeYourEvent.
  ///
  /// In en, this message translates to:
  /// **'Describe your event...'**
  String get describeYourEvent;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write Review'**
  String get writeReview;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @comment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get comment;

  /// No description provided for @writeYourReview.
  ///
  /// In en, this message translates to:
  /// **'Write your review...'**
  String get writeYourReview;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get submitReview;

  /// No description provided for @reviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted successfully!'**
  String get reviewSubmitted;

  /// No description provided for @pleaseSelectRating.
  ///
  /// In en, this message translates to:
  /// **'Please select a rating'**
  String get pleaseSelectRating;

  /// No description provided for @noReviews.
  ///
  /// In en, this message translates to:
  /// **'No Reviews'**
  String get noReviews;

  /// No description provided for @noReviewsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Be the first to review this event'**
  String get noReviewsSubtitle;

  /// No description provided for @seeAllReviews.
  ///
  /// In en, this message translates to:
  /// **'See All Reviews'**
  String get seeAllReviews;

  /// No description provided for @tapToRate.
  ///
  /// In en, this message translates to:
  /// **'Tap to rate'**
  String get tapToRate;

  /// No description provided for @ratingPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get ratingPoor;

  /// No description provided for @ratingFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get ratingFair;

  /// No description provided for @ratingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ratingGood;

  /// No description provided for @ratingVeryGood.
  ///
  /// In en, this message translates to:
  /// **'Very Good'**
  String get ratingVeryGood;

  /// No description provided for @ratingExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get ratingExcellent;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String reviewsCount(int count);

  /// No description provided for @signature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get signature;

  /// No description provided for @uploadSignature.
  ///
  /// In en, this message translates to:
  /// **'Upload Signature'**
  String get uploadSignature;

  /// No description provided for @signatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Your signature will appear on certificates you issue'**
  String get signatureDescription;

  /// No description provided for @signatureUploaded.
  ///
  /// In en, this message translates to:
  /// **'Signature uploaded successfully'**
  String get signatureUploaded;

  /// No description provided for @removeSignature.
  ///
  /// In en, this message translates to:
  /// **'Remove Signature'**
  String get removeSignature;

  /// No description provided for @tapToUploadSignature.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload your signature'**
  String get tapToUploadSignature;

  /// No description provided for @addToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add to Calendar'**
  String get addToCalendar;

  /// No description provided for @couldNotOpenCalendar.
  ///
  /// In en, this message translates to:
  /// **'Could not open calendar app'**
  String get couldNotOpenCalendar;

  /// No description provided for @emailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get emailNotifications;

  /// No description provided for @emailNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Receive important updates via email'**
  String get emailNotificationsDescription;

  /// No description provided for @eventReminders.
  ///
  /// In en, this message translates to:
  /// **'Event Reminders'**
  String get eventReminders;

  /// No description provided for @eventRemindersDescription.
  ///
  /// In en, this message translates to:
  /// **'Get email reminders before your events'**
  String get eventRemindersDescription;

  /// No description provided for @notificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences'**
  String get notificationPreferences;

  /// No description provided for @emailPreferencesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Email preferences updated'**
  String get emailPreferencesUpdated;

  /// No description provided for @scanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQrCode;

  /// No description provided for @pointCameraAtQr.
  ///
  /// In en, this message translates to:
  /// **'Point camera at attendee\'s QR code'**
  String get pointCameraAtQr;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @toggleFlash.
  ///
  /// In en, this message translates to:
  /// **'Toggle Flash'**
  String get toggleFlash;

  /// No description provided for @switchCamera.
  ///
  /// In en, this message translates to:
  /// **'Switch Camera'**
  String get switchCamera;

  /// No description provided for @checkInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check-in Successful'**
  String get checkInSuccess;

  /// No description provided for @checkInFailed.
  ///
  /// In en, this message translates to:
  /// **'Check-in Failed'**
  String get checkInFailed;

  /// No description provided for @checkedInSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'has been checked in successfully'**
  String get checkedInSuccessfully;

  /// No description provided for @alreadyCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'This attendee has already been checked in'**
  String get alreadyCheckedIn;

  /// No description provided for @invalidQrCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR code'**
  String get invalidQrCode;

  /// No description provided for @registrationNotApproved.
  ///
  /// In en, this message translates to:
  /// **'Registration is not approved'**
  String get registrationNotApproved;

  /// No description provided for @scanNext.
  ///
  /// In en, this message translates to:
  /// **'Scan Next'**
  String get scanNext;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @checkedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked In'**
  String get checkedIn;

  /// No description provided for @checkedInAt.
  ///
  /// In en, this message translates to:
  /// **'Checked in at'**
  String get checkedInAt;

  /// No description provided for @showQrAtEntrance.
  ///
  /// In en, this message translates to:
  /// **'Show this QR code at the entrance'**
  String get showQrAtEntrance;

  /// No description provided for @youHaveCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'You have checked in to this event'**
  String get youHaveCheckedIn;

  /// No description provided for @savedEvents.
  ///
  /// In en, this message translates to:
  /// **'Saved Events'**
  String get savedEvents;

  /// No description provided for @noSavedEvents.
  ///
  /// In en, this message translates to:
  /// **'No Saved Events'**
  String get noSavedEvents;

  /// No description provided for @noSavedEventsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmark events you\'re interested in to find them here later'**
  String get noSavedEventsSubtitle;

  /// No description provided for @addedToSaved.
  ///
  /// In en, this message translates to:
  /// **'Added to saved events'**
  String get addedToSaved;

  /// No description provided for @removedFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved events'**
  String get removedFromSaved;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @myQuestions.
  ///
  /// In en, this message translates to:
  /// **'My Questions'**
  String get myQuestions;

  /// No description provided for @answered.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get answered;

  /// No description provided for @answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @reportReview.
  ///
  /// In en, this message translates to:
  /// **'Report Review'**
  String get reportReview;

  /// No description provided for @selectReason.
  ///
  /// In en, this message translates to:
  /// **'Select a reason for reporting'**
  String get selectReason;

  /// No description provided for @additionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional Details'**
  String get additionalDetails;

  /// No description provided for @optionalDescription.
  ///
  /// In en, this message translates to:
  /// **'Provide more details (optional)'**
  String get optionalDescription;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted successfully'**
  String get reportSubmitted;

  /// No description provided for @alreadyReported.
  ///
  /// In en, this message translates to:
  /// **'You have already reported this review'**
  String get alreadyReported;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report'**
  String get reportFailed;

  /// No description provided for @reasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get reasonSpam;

  /// No description provided for @reasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate Content'**
  String get reasonInappropriate;

  /// No description provided for @reasonFakeReview.
  ///
  /// In en, this message translates to:
  /// **'Fake Review'**
  String get reasonFakeReview;

  /// No description provided for @reasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get reasonHarassment;

  /// No description provided for @reasonOffTopic.
  ///
  /// In en, this message translates to:
  /// **'Off Topic'**
  String get reasonOffTopic;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reasonOther;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
