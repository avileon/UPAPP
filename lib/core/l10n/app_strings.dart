/// All user-facing copy, in one place, for both supported locales.
///
/// Hebrew is the reference copy — English is a translation of it, not the
/// other way round. Anything with a value inside it is a function field so
/// word order stays natural in both languages instead of being glued together
/// with `+` at the call site.
library;

class AppStrings {
  const AppStrings({
    required this.localeCode,
    required this.tagline,
    required this.start,
    required this.cont,
    required this.cancel,
    required this.done,
    required this.later,
    required this.introTitle,
    required this.introBody,
    required this.introPoint1Title,
    required this.introPoint1Body,
    required this.introPoint2Title,
    required this.introPoint2Body,
    required this.introPoint3Title,
    required this.introPoint3Body,
    required this.ageGate,
    required this.phoneTitle,
    required this.phoneBody,
    required this.phoneHint,
    required this.sendCode,
    required this.otpTitle,
    required this.otpSentTo,
    required this.otpDemoHint,
    required this.resend,
    required this.verify,
    required this.profileTitle,
    required this.firstName,
    required this.birthDate,
    required this.birthDayHint,
    required this.birthMonthHint,
    required this.birthYearHint,
    required this.iAm,
    required this.interestedIn,
    required this.genderMale,
    required this.genderFemale,
    required this.genderOther,
    required this.prefMen,
    required this.prefWomen,
    required this.prefEveryone,
    required this.bioLabel,
    required this.bioHint,
    required this.photosTitle,
    required this.photosBody,
    required this.addPhoto,
    required this.mainPhoto,
    required this.removePhoto,
    required this.uploading,
    required this.photosNoneYet,
    required this.permsTitle,
    required this.permBluetoothTitle,
    required this.permBluetoothBody,
    required this.permNotifTitle,
    required this.permNotifBody,
    required this.permLocationNote,
    required this.allowAndContinue,
    required this.goLive,
    required this.stopLive,
    required this.invisibleTitle,
    required this.invisibleBody,
    required this.visibleTitle,
    required this.visibleBody,
    required this.bluetoothOn,
    required this.bluetoothOff,
    required this.visibleFor,
    required this.durationLabel,
    required this.minutesShort,
    required this.seeNearby,
    required this.nearbyTitle,
    required this.nearbyBody,
    required this.nearbyQuietTitle,
    required this.nearbyQuietBody,
    required this.notLiveTitle,
    required this.notLiveBody,
    required this.nearYouNow,
    required this.upSentLabel,
    required this.upBack,
    required this.pass,
    required this.passedAway,
    required this.matchTitle,
    required this.sayHi,
    required this.keepLooking,
    required this.chatsTitle,
    required this.noMatchesTitle,
    required this.noMatchesBody,
    required this.newTag,
    required this.messageHint,
    required this.chatOpener,
    required this.realityTitle,
    required this.realityNote,
    required this.realityYes,
    required this.realitySomewhat,
    required this.realityNo,
    required this.realityThanks,
    required this.verifiedBadge,
    required this.myProfile,
    required this.editPhotos,
    required this.editDetails,
    required this.settingsTitle,
    required this.sectionApp,
    required this.sectionPrivacy,
    required this.sectionSafety,
    required this.sectionAccount,
    required this.settingLanguage,
    required this.settingAppearance,
    required this.settingLiveDuration,
    required this.settingHideContacts,
    required this.sectionServer,
    required this.serverUrlLabel,
    required this.serverUrlHint,
    required this.serverUrlBody,
    required this.serverStatusMock,
    required this.serverStatusChecking,
    required this.serverStatusOk,
    required this.serverStatusFail,
    required this.serverSave,
    required this.venueLabel,
    required this.venueHint,
    required this.venueBody,
    required this.venueTitle,
    required this.venueScanHint,
    required this.venueNoCode,
    required this.venueNoServer,
    required this.venueRoom,
    required this.venueNoCodeShort,
    required this.venueSavedIn,
    required this.venueThenGoLive,
    required this.venueLiveJoined,
    required this.roomNotLive,
    required this.roomAlone,
    required this.roomOthers,
    required this.quietNoRoomBody,
    required this.quietEmptyRoomBody,
    required this.quietFilteredBody,
    required this.copyLink,
    required this.linkCopied,
    required this.devCodeLabel,
    required this.errorOffline,
    required this.errorUnderAge,
    required this.errorOtpWrong,
    required this.errorRateLimited,
    required this.errorGeneric,
    required this.blockedList,
    required this.reportAndHelp,
    required this.privacyPolicy,
    required this.termsOfUse,
    required this.logOut,
    required this.deleteAccount,
    required this.deleteConfirmTitle,
    required this.deleteConfirmBody,
    required this.deleteYes,
    required this.block,
    required this.report,
    required this.unmatch,
    required this.reportSent,
    required this.themeDark,
    required this.themeLight,
    required this.themeSystem,
    required this.on,
    required this.off,
    required this.demoTitle,
    required this.demoBody,
    required this.demoDiscover,
    required this.demoIncomingUp,
    required this.demoForceMatch,
    required this.demoReset,
    required this.tabHome,
    required this.tabNearby,
    required this.tabChats,
    required this.tabMe,
    required this.back,
    required this.more,
    required this.upSentTo,
    required this.matchBody,
    required this.realityBody,
    required this.blockedDone,
    required this.peopleNearby,
    required this.incomingUps,
    required this.ageYears,
  });

  final String localeCode;

  final String tagline;
  final String start;
  final String cont;
  final String cancel;
  final String done;
  final String later;

  final String introTitle;
  final String introBody;
  final String introPoint1Title;
  final String introPoint1Body;
  final String introPoint2Title;
  final String introPoint2Body;
  final String introPoint3Title;
  final String introPoint3Body;
  final String ageGate;

  final String phoneTitle;
  final String phoneBody;
  final String phoneHint;
  final String sendCode;
  final String otpTitle;
  final String otpSentTo;
  final String otpDemoHint;
  final String resend;
  final String verify;

  final String profileTitle;
  final String firstName;
  final String birthDate;
  final String birthDayHint;
  final String birthMonthHint;
  final String birthYearHint;
  final String iAm;
  final String interestedIn;
  final String genderMale;
  final String genderFemale;
  final String genderOther;
  final String prefMen;
  final String prefWomen;
  final String prefEveryone;
  final String bioLabel;
  final String bioHint;

  final String photosTitle;
  final String photosBody;
  final String addPhoto;
  final String mainPhoto;
  final String removePhoto;
  final String uploading;
  final String photosNoneYet;

  final String permsTitle;
  final String permBluetoothTitle;
  final String permBluetoothBody;
  final String permNotifTitle;
  final String permNotifBody;
  final String permLocationNote;
  final String allowAndContinue;

  final String goLive;
  final String stopLive;
  final String invisibleTitle;
  final String invisibleBody;
  final String visibleTitle;
  final String visibleBody;
  final String bluetoothOn;
  final String bluetoothOff;
  final String visibleFor;
  final String durationLabel;
  final String minutesShort;
  final String seeNearby;

  final String nearbyTitle;
  final String nearbyBody;
  final String nearbyQuietTitle;
  final String nearbyQuietBody;
  final String notLiveTitle;
  final String notLiveBody;
  final String nearYouNow;

  final String upSentLabel;
  final String upBack;
  final String pass;
  final String passedAway;

  final String matchTitle;
  final String sayHi;
  final String keepLooking;

  final String chatsTitle;
  final String noMatchesTitle;
  final String noMatchesBody;
  final String newTag;
  final String messageHint;
  final String chatOpener;

  final String realityTitle;
  final String realityNote;
  final String realityYes;
  final String realitySomewhat;
  final String realityNo;
  final String realityThanks;
  final String verifiedBadge;

  final String myProfile;
  final String editPhotos;
  final String editDetails;

  final String settingsTitle;
  final String sectionApp;
  final String sectionPrivacy;
  final String sectionSafety;
  final String sectionAccount;
  final String settingLanguage;
  final String settingAppearance;
  final String settingLiveDuration;
  final String settingHideContacts;
  final String sectionServer;
  final String serverUrlLabel;
  final String serverUrlHint;
  final String serverUrlBody;
  final String serverStatusMock;
  final String serverStatusChecking;
  final String serverStatusOk;
  final String serverStatusFail;
  final String serverSave;
  final String venueLabel;
  final String venueHint;
  final String venueBody;
  final String venueTitle;
  final String venueScanHint;
  final String venueNoCode;
  final String venueNoServer;
  final String venueRoom;
  final String venueNoCodeShort;

  /// What the venue screen says the moment a code is saved, and what has to
  /// happen next. Saving a code is not joining a room — Live is — and a screen
  /// that does not say so leaves people staring at an empty list.
  final String Function(String code) venueSavedIn;
  final String venueThenGoLive;
  final String Function(String code) venueLiveJoined;

  /// The room row on the home screen, in its three honest states.
  final String roomNotLive;
  final String roomAlone;
  final String Function(int others) roomOthers;

  /// Why the nearby list is empty. Three different causes, three different
  /// fixes, and no way for a person to tell them apart without being told.
  final String quietNoRoomBody;
  final String Function(String code) quietEmptyRoomBody;
  final String Function(int others) quietFilteredBody;
  final String copyLink;
  final String linkCopied;
  final String devCodeLabel;
  final String errorOffline;
  final String errorUnderAge;
  final String errorOtpWrong;
  final String errorRateLimited;
  final String errorGeneric;
  final String blockedList;
  final String reportAndHelp;
  final String privacyPolicy;
  final String termsOfUse;
  final String logOut;
  final String deleteAccount;
  final String deleteConfirmTitle;
  final String deleteConfirmBody;
  final String deleteYes;

  final String block;
  final String report;
  final String unmatch;
  final String reportSent;

  final String themeDark;
  final String themeLight;
  final String themeSystem;
  final String on;
  final String off;

  final String demoTitle;
  final String demoBody;
  final String demoDiscover;
  final String demoIncomingUp;
  final String demoForceMatch;
  final String demoReset;

  final String tabHome;
  final String tabNearby;
  final String tabChats;
  final String tabMe;
  final String back;
  final String more;

  final String Function(String name) upSentTo;
  final String Function(String name) matchBody;
  final String Function(String name) realityBody;
  final String Function(String name) blockedDone;
  final String Function(int count) peopleNearby;
  final String Function(int count) incomingUps;
  final String Function(int years) ageYears;

  static final AppStrings he = AppStrings(
    localeCode: 'he',
    tagline: 'מי שנמצא כאן, נמצא כאן עכשיו',
    start: 'בואו נתחיל',
    cont: 'המשך',
    cancel: 'ביטול',
    done: 'סיום',
    later: 'אחר כך',
    introTitle: 'רואה מישהו שמעניין אותך?',
    introBody:
        'UP מראה רק אנשים שבחרו להיות זמינים ונמצאים ממש לידך. בלי מפה, בלי מרחק, בלי גלילה אינסופית.',
    introPoint1Title: 'אתה בוחר מתי אתה גלוי',
    introPoint1Body: 'מצב Live נדלק לזמן קצוב ונכבה לבד.',
    introPoint2Title: 'UP הוא פרטי',
    introPoint2Body: 'אף אחד לא יודע ששלחת UP עד שגם הוא שלח.',
    introPoint3Title: 'בלי מיקום, בלי מרחק',
    introPoint3Body: 'רק Bluetooth. אנחנו לא שומרים איפה היית.',
    ageGate: 'אני מעל גיל 18 ומאשר את תנאי השימוש ומדיניות הפרטיות',
    phoneTitle: 'מה מספר הטלפון שלך?',
    phoneBody: 'נשלח קוד חד-פעמי. המספר לא מוצג לאף אחד.',
    phoneHint: '050-000-0000',
    sendCode: 'שלח קוד',
    otpTitle: 'הזן את הקוד',
    otpSentTo: 'שלחנו קוד בן 4 ספרות אל',
    otpDemoHint: 'בדמו — כל קוד עובד.',
    resend: 'שלח שוב',
    verify: 'אמת',
    profileTitle: 'קצת עליך',
    firstName: 'שם פרטי',
    birthDate: 'תאריך לידה',
    birthDayHint: 'יום',
    birthMonthHint: 'חודש',
    birthYearHint: 'שנה',
    iAm: 'אני',
    interestedIn: 'מעניין אותי',
    genderMale: 'גבר',
    genderFemale: 'אישה',
    genderOther: 'אחר',
    prefMen: 'גברים',
    prefWomen: 'נשים',
    prefEveryone: 'כולם',
    bioLabel: 'שורה עליך (אופציונלי)',
    bioHint: 'הקטע שלי הוא…',
    photosTitle: 'התמונות שלך',
    photosBody:
        'תמונה ראשית חובה, עד 6 בסך הכל. זה מה שאנשים יראו בשנייה שהם מרימים את המבט מהמסך.',
    addPhoto: 'הוסף',
    mainPhoto: 'ראשית',
    removePhoto: 'הסר תמונה',
    uploading: 'מעלה…',
    photosNoneYet: 'בלי תמונה אף אחד לא יידע מי אתה. אפשר להוסיף עוד אחר כך.',
    permsTitle: 'שתי הרשאות, ואנחנו בפנים',
    permBluetoothTitle: 'Bluetooth',
    permBluetoothBody: 'ככה UP יודע מי נמצא ממש לידך. בלי זה אין אפליקציה.',
    permNotifTitle: 'התראות',
    permNotifBody: 'רק כשיש Match או הודעה. לא נשלח לך "מישהו מתגעגע אליך".',
    permLocationNote:
        'אנחנו לא מבקשים גישה למיקום. אם גרסת אנדרואיד מסוימת דורשת הרשאת מיקום, זה אך ורק כדי לאפשר סריקת Bluetooth — ואנחנו לא שומרים מיקום.',
    allowAndContinue: 'אשר והמשך',
    goLive: 'GO\nLIVE',
    stopLive: 'STOP\nLIVE',
    invisibleTitle: 'אתה לא גלוי',
    invisibleBody:
        'אף אחד לא רואה אותך ואף אחד לא מופיע לך. הדלק Live כשאתה במקום שבו אתה רוצה שיראו אותך.',
    visibleTitle: 'אתה גלוי',
    visibleBody: 'מפרסם ומאזין. מי שגם Live בטווח יופיע כאן.',
    bluetoothOn: 'BLUETOOTH פעיל',
    bluetoothOff: 'BLUETOOTH כבוי',
    visibleFor: 'גלוי עוד',
    durationLabel: 'משך',
    minutesShort: 'דק׳',
    seeNearby: 'ראה מי בסביבה',
    nearbyTitle: 'בסביבה עכשיו',
    nearbyBody: 'רק אנשים שגם הם Live. הרשימה מתרוקנת ברגע שהם יוצאים.',
    nearbyQuietTitle: 'שקט כאן',
    nearbyQuietBody:
        'אף אחד ב-Live בטווח Bluetooth כרגע. נסה שוב עוד רגע — או פתח את מסך הדמו.',
    notLiveTitle: 'אתה לא Live',
    notLiveBody: 'הדלק Live כדי לראות מי בסביבה.',
    nearYouNow: 'קרוב אליך עכשיו',
    upSentLabel: 'שלחת UP',
    upBack: 'שלח UP בחזרה',
    pass: 'דלג',
    passedAway: 'לא יופיע שוב ב-Live הזה',
    matchTitle: 'It’s an UP!',
    sayHi: 'שלח הודעה',
    keepLooking: 'תמשיך להסתכל',
    chatsTitle: 'שיחות',
    noMatchesTitle: 'עוד אין Match',
    noMatchesBody: 'Match נוצר רק כששניכם שלחתם UP.',
    newTag: 'חדש',
    messageHint: 'כתוב הודעה…',
    chatOpener: 'שניכם שלחתם UP. מישהו צריך להתחיל.',
    realityTitle: 'התמונות תאמו?',
    realityNote:
        'זו לא הצבעה על מראה. זו בדיקת אמינות תמונות בלבד, והיא אנונימית לחלוטין.',
    realityYes: 'כן',
    realitySomewhat: 'בערך',
    realityNo: 'לא',
    realityThanks: 'תודה. התשובה שלך אנונימית ולא מוצגת לאף אחד.',
    verifiedBadge: 'תואם לתמונות',
    myProfile: 'הפרופיל שלי',
    editPhotos: 'ערוך תמונות',
    editDetails: 'ערוך פרטים',
    settingsTitle: 'הגדרות ובטיחות',
    sectionApp: 'אפליקציה',
    sectionPrivacy: 'פרטיות',
    sectionSafety: 'בטיחות',
    sectionAccount: 'חשבון',
    settingLanguage: 'שפה',
    settingAppearance: 'מראה',
    settingLiveDuration: 'משך Live ברירת מחדל',
    settingHideContacts: 'הסתר אותי מאנשי הקשר שלי',
    sectionServer: 'שרת',
    serverUrlLabel: 'כתובת השרת',
    serverUrlHint: 'https://xxx.trycloudflare.com',
    serverUrlBody: 'בלי כתובת האפליקציה רצה על נתונים מדומים בלבד.',
    serverStatusMock: 'נתונים מדומים',
    serverStatusChecking: 'בודק…',
    serverStatusOk: 'מחובר',
    serverStatusFail: 'אין חיבור',
    serverSave: 'שמור והתחבר',
    venueLabel: 'קוד מקום',
    venueHint: 'BAR12',
    venueBody: 'מי שמזין את אותו הקוד יופיע אצלך כשאתם Live. '
        'הקוד לא נשמר ונמחק בסוף הסשן.',
    venueTitle: 'החדר שלכם',
    venueScanHint: 'מי שסורק נכנס לאותו חדר — בלי להתקין כלום.',
    venueNoCode: 'עוד אין קוד מקום. בחר קוד קצר ותקבל QR לשיתוף.',
    venueNoServer: 'אין כתובת שרת, אז אין מה לשתף עדיין.',
    venueRoom: 'חדר',
    venueNoCodeShort: 'בחר קוד',
    venueSavedIn: _heVenueSavedIn,
    venueThenGoLive:
        'זה עדיין לא מכניס אותך לחדר. חזור למסך הבית ולחץ GO LIVE.',
    venueLiveJoined: _heVenueLiveJoined,
    roomNotLive: 'לא פעיל',
    roomAlone: 'אתה לבד כאן',
    roomOthers: _heRoomOthers,
    quietNoRoomBody: 'אין קוד מקום, אז אין חדר. בחרו קוד אחד ושתפו אותו.',
    quietEmptyRoomBody: _heQuietEmptyRoom,
    quietFilteredBody: _heQuietFiltered,
    copyLink: 'העתק קישור',
    linkCopied: 'הקישור הועתק',
    devCodeLabel: 'קוד לפיתוח',
    errorOffline: 'אין חיבור לשרת. בדוק את הכתובת בהגדרות.',
    errorUnderAge: 'צריך להיות בן 18 ומעלה.',
    errorOtpWrong: 'הקוד לא נכון.',
    errorRateLimited: 'יותר מדי ניסיונות. נסה שוב עוד קצת.',
    errorGeneric: 'משהו השתבש. נסה שוב.',
    blockedList: 'רשימת חסומים',
    reportAndHelp: 'דיווח ועזרה',
    privacyPolicy: 'מדיניות פרטיות',
    termsOfUse: 'תנאי שימוש',
    logOut: 'התנתק',
    deleteAccount: 'מחק חשבון',
    deleteConfirmTitle: 'למחוק את החשבון?',
    deleteConfirmBody: 'הפרופיל, ההתאמות וההודעות יימחקו. זה לא הפיך.',
    deleteYes: 'כן, מחק',
    block: 'חסום',
    report: 'דווח',
    unmatch: 'בטל Match',
    reportSent: 'הדיווח נשלח לצוות',
    themeDark: 'כהה',
    themeLight: 'בהיר',
    themeSystem: 'לפי המכשיר',
    on: 'פעיל',
    off: 'כבוי',
    demoTitle: 'מסך דמו',
    demoBody:
        'אין BLE אמיתי ואין שרת ב-Milestone 1. הכפתורים כאן מדמים אירועים שבאפליקציה האמיתית יגיעו מהרדיו ומהשרת.',
    demoDiscover: 'גלה עוד אדם בסביבה',
    demoIncomingUp: 'מישהו שלח לך UP',
    demoForceMatch: 'צור Match מיידי',
    demoReset: 'אפס הכל',
    tabHome: 'בית',
    tabNearby: 'בסביבה',
    tabChats: 'שיחות',
    tabMe: 'אני',
    back: 'חזרה',
    more: 'עוד',
    upSentTo: _heUpSentTo,
    matchBody: _heMatchBody,
    realityBody: _heRealityBody,
    blockedDone: _heBlockedDone,
    peopleNearby: _hePeopleNearby,
    incomingUps: _heIncomingUps,
    ageYears: _heAgeYears,
  );

  static final AppStrings en = AppStrings(
    localeCode: 'en',
    tagline: 'Whoever is here, is here now',
    start: 'Let’s go',
    cont: 'Continue',
    cancel: 'Cancel',
    done: 'Done',
    later: 'Later',
    introTitle: 'See someone across the room?',
    introBody:
        'UP only shows people who chose to be available and are right next to you. No map, no distance, no endless scroll.',
    introPoint1Title: 'You choose when you’re visible',
    introPoint1Body: 'Live runs on a timer and turns itself off.',
    introPoint2Title: 'An UP is private',
    introPoint2Body: 'Nobody knows you sent one until they send one too.',
    introPoint3Title: 'No location, no distance',
    introPoint3Body: 'Bluetooth only. We don’t store where you’ve been.',
    ageGate: 'I’m over 18 and accept the Terms and Privacy Policy',
    phoneTitle: 'What’s your number?',
    phoneBody: 'We’ll text a one-time code. Your number is never shown to anyone.',
    phoneHint: '050 000 0000',
    sendCode: 'Send code',
    otpTitle: 'Enter the code',
    otpSentTo: 'We sent a 4-digit code to',
    otpDemoHint: 'Demo — any code works.',
    resend: 'Resend',
    verify: 'Verify',
    profileTitle: 'A bit about you',
    firstName: 'First name',
    birthDate: 'Birth date',
    birthDayHint: 'Day',
    birthMonthHint: 'Month',
    birthYearHint: 'Year',
    iAm: 'I am',
    interestedIn: 'Interested in',
    genderMale: 'Man',
    genderFemale: 'Woman',
    genderOther: 'Other',
    prefMen: 'Men',
    prefWomen: 'Women',
    prefEveryone: 'Everyone',
    bioLabel: 'One line about you (optional)',
    bioHint: 'My thing is…',
    photosTitle: 'Your photos',
    photosBody:
        'A main photo is required, up to 6 in total. This is what people see the second they look up from their screen.',
    addPhoto: 'Add',
    mainPhoto: 'Main',
    removePhoto: 'Remove photo',
    uploading: 'Uploading…',
    photosNoneYet: 'Without a photo nobody knows who you are. You can add more later.',
    permsTitle: 'Two permissions and we’re in',
    permBluetoothTitle: 'Bluetooth',
    permBluetoothBody:
        'This is how UP knows who is actually near you. Without it there is no app.',
    permNotifTitle: 'Notifications',
    permNotifBody:
        'Only for matches and messages. No "someone misses you" nonsense.',
    permLocationNote:
        'We never ask for Location. If a given Android version demands a location permission, it is purely to allow Bluetooth scanning — we do not store location.',
    allowAndContinue: 'Allow and continue',
    goLive: 'GO\nLIVE',
    stopLive: 'STOP\nLIVE',
    invisibleTitle: 'You’re invisible',
    invisibleBody:
        'Nobody sees you and nobody shows up for you. Turn Live on when you’re somewhere you want to be seen.',
    visibleTitle: 'You’re visible',
    visibleBody:
        'Broadcasting and listening. Anyone else who is Live in range will appear here.',
    bluetoothOn: 'BLUETOOTH ON',
    bluetoothOff: 'BLUETOOTH OFF',
    visibleFor: 'Visible for',
    durationLabel: 'Duration',
    minutesShort: 'min',
    seeNearby: 'See who’s nearby',
    nearbyTitle: 'Nearby right now',
    nearbyBody:
        'Only people who are Live too. The list empties the moment they leave.',
    nearbyQuietTitle: 'Quiet in here',
    nearbyQuietBody:
        'Nobody Live in Bluetooth range right now. Try again in a moment — or open the demo sheet.',
    notLiveTitle: 'You’re not Live',
    notLiveBody: 'Turn Live on to see who’s around.',
    nearYouNow: 'Near you right now',
    upSentLabel: 'UP sent',
    upBack: 'UP them back',
    pass: 'Pass',
    passedAway: 'Won’t show again this session',
    matchTitle: 'It’s an UP!',
    sayHi: 'Say something',
    keepLooking: 'Keep looking',
    chatsTitle: 'Chats',
    noMatchesTitle: 'No matches yet',
    noMatchesBody: 'A match only happens when you both sent an UP.',
    newTag: 'New',
    messageHint: 'Message…',
    chatOpener: 'You both sent an UP. Someone has to start.',
    realityTitle: 'Did the photos match?',
    realityNote:
        'This is not a vote on looks. It only checks photo honesty, and it is completely anonymous.',
    realityYes: 'Yes',
    realitySomewhat: 'Kind of',
    realityNo: 'No',
    realityThanks: 'Thanks. Your answer is anonymous and never shown to anyone.',
    verifiedBadge: 'Looks like their photos',
    myProfile: 'My profile',
    editPhotos: 'Edit photos',
    editDetails: 'Edit details',
    settingsTitle: 'Settings & safety',
    sectionApp: 'App',
    sectionPrivacy: 'Privacy',
    sectionSafety: 'Safety',
    sectionAccount: 'Account',
    settingLanguage: 'Language',
    settingAppearance: 'Appearance',
    settingLiveDuration: 'Default Live duration',
    settingHideContacts: 'Hide me from my contacts',
    sectionServer: 'Server',
    serverUrlLabel: 'Server address',
    serverUrlHint: 'https://xxx.trycloudflare.com',
    serverUrlBody: 'Without an address the app runs on mock data only.',
    serverStatusMock: 'Mock data',
    serverStatusChecking: 'Checking…',
    serverStatusOk: 'Connected',
    serverStatusFail: 'No connection',
    serverSave: 'Save and connect',
    venueLabel: 'Venue code',
    venueHint: 'BAR12',
    venueBody: 'Anyone who types the same code shows up while you are both '
        'Live. The code is never stored and dies with the session.',
    venueTitle: 'Your room',
    venueScanHint: 'Whoever scans this lands in the same room — nothing to install.',
    venueNoCode: 'No venue code yet. Pick a short one and you get a QR to share.',
    venueNoServer: 'No server address, so there is nothing to share yet.',
    venueRoom: 'Room',
    venueNoCodeShort: 'Pick a code',
    venueSavedIn: _enVenueSavedIn,
    venueThenGoLive:
        'That does not put you in the room yet. Go back and press GO LIVE.',
    venueLiveJoined: _enVenueLiveJoined,
    roomNotLive: 'not active',
    roomAlone: 'just you here',
    roomOthers: _enRoomOthers,
    quietNoRoomBody: 'No venue code, so there is no room. Pick one and share it.',
    quietEmptyRoomBody: _enQuietEmptyRoom,
    quietFilteredBody: _enQuietFiltered,
    copyLink: 'Copy link',
    linkCopied: 'Link copied',
    devCodeLabel: 'Dev code',
    errorOffline: 'Cannot reach the server. Check the address in settings.',
    errorUnderAge: 'You have to be 18 or over.',
    errorOtpWrong: 'That code is not right.',
    errorRateLimited: 'Too many tries. Give it a minute.',
    errorGeneric: 'Something went wrong. Try again.',
    blockedList: 'Blocked list',
    reportAndHelp: 'Report & help',
    privacyPolicy: 'Privacy policy',
    termsOfUse: 'Terms of use',
    logOut: 'Log out',
    deleteAccount: 'Delete account',
    deleteConfirmTitle: 'Delete your account?',
    deleteConfirmBody:
        'Your profile, matches and messages are removed. This cannot be undone.',
    deleteYes: 'Yes, delete',
    block: 'Block',
    report: 'Report',
    unmatch: 'Unmatch',
    reportSent: 'Report sent to the team',
    themeDark: 'Dark',
    themeLight: 'Light',
    themeSystem: 'System',
    on: 'On',
    off: 'Off',
    demoTitle: 'Demo sheet',
    demoBody:
        'No real BLE and no server in Milestone 1. These buttons fake the events the real app would get from the radio and the backend.',
    demoDiscover: 'Discover one more person',
    demoIncomingUp: 'Someone sends you an UP',
    demoForceMatch: 'Force a match',
    demoReset: 'Reset everything',
    tabHome: 'Home',
    tabNearby: 'Nearby',
    tabChats: 'Chats',
    tabMe: 'Me',
    back: 'Back',
    more: 'More',
    upSentTo: _enUpSentTo,
    matchBody: _enMatchBody,
    realityBody: _enRealityBody,
    blockedDone: _enBlockedDone,
    peopleNearby: _enPeopleNearby,
    incomingUps: _enIncomingUps,
    ageYears: _enAgeYears,
  );

  static AppStrings of(String localeCode) =>
      localeCode == 'he' ? AppStrings.he : AppStrings.en;
}

// ---------------------------------------------------------------------------
// Parameterised copy. Top-level functions so the instances above stay const-ish
// and every locale keeps control of its own word order.
// ---------------------------------------------------------------------------

String _heUpSentTo(String name) => 'UP נשלח אל $name. אם גם הוא ישלח — תדע.';
String _enUpSentTo(String name) =>
    'UP sent to $name. If they send one too, you’ll know.';

String _heMatchBody(String name) => 'גם $name שלח לך UP. עכשיו אתם יכולים לדבר.';
String _enMatchBody(String name) => '$name sent you one too. Go say something.';

String _heRealityBody(String name) =>
    'נפגשתם באמת. האם $name נראה במציאות כמו התמונות בפרופיל?';
String _enRealityBody(String name) =>
    'You actually met. Did $name look like their profile photos in real life?';

String _heBlockedDone(String name) => '$name נחסם ולא יופיע שוב.';
String _enBlockedDone(String name) => '$name is blocked and won’t appear again.';

String _hePeopleNearby(int count) {
  if (count == 0) {
    return 'עדיין אף אחד בסביבה';
  }
  if (count == 1) {
    return 'אדם אחד בסביבה';
  }
  return '$count אנשים בסביבה';
}

String _enPeopleNearby(int count) {
  if (count == 0) {
    return 'Nobody nearby yet';
  }
  if (count == 1) {
    return '1 person nearby';
  }
  return '$count people nearby';
}

String _heIncomingUps(int count) =>
    count == 1 ? 'מישהו שלח לך UP' : '$count אנשים שלחו לך UP';
String _enIncomingUps(int count) =>
    count == 1 ? 'Someone sent you an UP' : '$count people sent you an UP';

String _heAgeYears(int years) => 'גיל $years';
String _enAgeYears(int years) => 'Age $years';

String _heVenueSavedIn(String code) => 'נשמר. החדר שלך הוא $code.';
String _enVenueSavedIn(String code) => 'Saved. Your room is $code.';

String _heVenueLiveJoined(String code) => 'אתה Live בחדר $code כרגע.';
String _enVenueLiveJoined(String code) => 'You are Live in $code right now.';

String _heRoomOthers(int others) =>
    others == 1 ? 'עוד אחד בחדר' : 'עוד $others בחדר';
String _enRoomOthers(int others) =>
    others == 1 ? '1 other here' : '$others others here';

String _heQuietEmptyRoom(String code) =>
    'אתה לבד בחדר $code. ודאו שכולם על אותו קוד ושכל אחד לחץ GO LIVE.';
String _enQuietEmptyRoom(String code) =>
    'You are alone in $code. Check everyone is on that code and pressed GO LIVE.';

/// The case that looks like a bug and is not: everyone is in the room, and the
/// preference rules — which have to agree in both directions — rule them out.
String _heQuietFiltered(int others) {
  final String who = others == 1 ? 'עוד אחד' : 'עוד $others';
  return '$who בחדר, אבל ההעדפות לא מסתדרות בשני הכיוונים. '
      'נסו "מעניין אותי: כולם".';
}

String _enQuietFiltered(int others) {
  final String who = others == 1 ? '1 other' : '$others others';
  return '$who in the room, but the preferences do not agree both ways. '
      'Try “interested in: everyone”.';
}
