import 'app_strings.dart';

/// Copy for the October 2026 dating features: venues, the people viewer,
/// hide/block, photos and the live face check.
///
/// An extension rather than more fields on [AppStrings], so each sentence sits
/// next to its translation instead of 900 lines away from it. Hebrew is the
/// reference copy, as everywhere else.
extension DatingStrings on AppStrings {
  bool get _he => localeCode == 'he';

  String _t(String he, String en) => _he ? he : en;

  // -- leaving ---------------------------------------------------------------

  String get exitTitle => _t('לצאת מ-UP?', 'Leave UP?');
  String get exitBody => _t(
        'בטוח שאתה רוצה לצאת מהאפליקציה?',
        'Are you sure you want to leave the app?',
      );
  String get exitStay => _t('להישאר', 'Stay');
  String get exitLeave => _t('יציאה', 'Leave');

  // -- where ---------------------------------------------------------------

  String get whereQuestion => _t('איפה אתם?', 'Where are you?');
  String get modeArea => _t('באזור שלי', 'Around me');
  String get modeAreaHint =>
      _t('כל מי שב-Live בסביבה הקרובה', 'Everyone Live close by');
  String get modeVenue => _t('במקום (QR)', 'At a place (QR)');
  String get modeVenueHint =>
      _t('סורקים את ה-QR של הפאב, הבר או האולם', 'Scan the bar or hall QR');
  String get scanQr => _t('סריקת QR', 'Scan QR');
  String get scanTitle => _t('סרקו את ה-QR של המקום', 'Scan the place QR');
  String get scanHint => _t(
        'כוונו את המצלמה לקוד שעל הדלפק, השולחן או הקיר',
        'Point the camera at the code on the bar, table or wall',
      );
  String get scanTypeCode => _t('או הקלידו את הקוד', 'Or type the code');
  String get scanCodeHint => _t('הקוד שמתחת ל-QR', 'The code under the QR');
  String get scanInvalid =>
      _t('זה לא קוד של מקום ב-UP', 'That is not an UP place code');
  String get scanCameraUnavailable => _t(
        'המצלמה לא זמינה כאן. אפשר להקליד את הקוד שמתחת ל-QR.',
        'The camera is not available here. Type the code under the QR.',
      );

  // -- joining a venue -----------------------------------------------------

  String get joinBody => _t(
        'כדי להיכנס נוודא שאתם באמת כאן — לפי המיקום של הטלפון. '
            'המיקום משמש רק לבדיקה הזו ולא נשמר.',
        'To get in we check you are really here, using the phone location. '
            'It is used for this check only and not stored.',
      );
  String get joinButton => _t('אימות מיקום וכניסה', 'Check location and join');
  String joinHour(int minutes) => _t(
        'הכניסה ל-$minutes דקות. אחרי זה סורקים שוב.',
        'You are in for $minutes minutes, then scan again.',
      );
  String distanceFromPlace(int metres, int accuracy) {
    final String d = metres >= 1000
        ? '${(metres / 1000).toStringAsFixed(1)} ${_t('ק"מ', 'km')}'
        : '$metres ${_t('מ\'', 'm')}';
    return _t(
      'הטלפון נמצא במרחק כ-$d מהמקום (דיוק ±$accuracy מ\').',
      'Your phone is about $d from the place (±$accuracy m).',
    );
  }

  String get joinUnknown =>
      _t('המקום הזה לא רשום ב-UP', 'This place is not on UP');
  String get locating => _t('מאתרים מיקום…', 'Finding your location…');
  String get joining => _t('נכנסים…', 'Joining…');
  String venueLiveTitle(String name) => _t('אתם ב-$name', 'You are at $name');
  String venueEnded(String name) =>
      _t('השעה שלכם ב-$name נגמרה', 'Your hour at $name is over');
  String get scanAgain => _t('סריקה חוזרת', 'Scan again');
  String get areaLiveTitle => _t('אתם באזור', 'You are Live around here');
  String get quietAreaBody => _t(
        'עוד אין אנשים ב-Live סביבך. השאירו את UP פתוח — מי שיצטרף יופיע כאן.',
        'Nobody Live around you yet. Keep UP open — whoever joins shows up here.',
      );
  String get seePeople => _t('לראות מי כאן', 'See who is here');
  String get stillHere => _t('עדיין כאן? סרקו שוב כדי להישאר', 'Still here? Scan again to stay');

  // -- people viewer -------------------------------------------------------

  String get upAction => 'UP';
  String get upSentShort => _t('נשלח', 'Sent');
  String get sentYouUpBadge => _t('שלח/ה לך UP', 'Sent you an UP');
  String get noOneLeft => _t('אין עוד אנשים כרגע', 'Nobody else right now');
  String photoOf(int index, int count) =>
      _t('תמונה $index מתוך $count', 'Photo $index of $count');

  // -- celebrations --------------------------------------------------------

  String incomingUpTitle(String name) =>
      _t('$name שלח/ה לך UP!', '$name sent you an UP!');
  String get incomingUpBody =>
      _t('נמצאים כאן עכשיו. מחזירים?', 'They are here right now. UP back?');
  String get upBackAction => _t('UP בחזרה', 'UP back');
  String get laterAction => _t('אחר כך', 'Later');
  String newMatchTitle(String name) =>
      _t('את/ה ו-$name — יש UP הדדי!', 'You and $name — it is mutual!');
  String get openChat => _t('לשיחה', 'Open chat');

  // -- hide and block ------------------------------------------------------

  String get hideForVisit => _t('הסתרה זמנית', 'Hide for now');
  String get hideForVisitHint => _t(
        'לא תראו אותו/ה עד הפעם הבאה שתהיו באותו מקום',
        'You will not see them until next time you are in the same place',
      );
  String hiddenDone(String name) => _t(
        '$name הוסתר/ה עד הביקור הבא',
        '$name is hidden until next time',
      );
  String get blockHint =>
      _t('לא תראו זה את זה יותר — עד שתשחררו', 'Neither of you sees the other until you unblock');
  String get blockedTitle => _t('חסומים', 'Blocked');
  String get blockedEmpty => _t('אין אף אחד ברשימה', 'Nobody here');
  String get blockedBody => _t(
        'שחרור חסימה מאפשר לכם לראות זה את זה שוב. UP והתאמות שנמחקו לא חוזרים.',
        'Unblocking lets you see each other again. Deleted UPs and matches do not come back.',
      );
  String get unblock => _t('שחרור', 'Unblock');
  String unblockedDone(String name) =>
      _t('$name שוחרר/ה מחסימה', '$name is unblocked');

  // -- photos --------------------------------------------------------------

  String get photosFourBody => _t(
        'עד 4 תמונות. הראשית היא זו שכולם רואים קודם — לחצו על תמונה כדי לבחור אותה.',
        'Up to 4 photos. The main one is what everyone sees first — tap a photo to choose it.',
      );
  String get takePhoto => _t('צילום עכשיו', 'Take a photo');
  String get chooseFromGallery => _t('בחירה מהגלריה', 'Choose from gallery');
  String get makeMain => _t('הגדרה כתמונה ראשית', 'Make main photo');
  String get deletePhoto => _t('מחיקת התמונה', 'Delete photo');
  String get photoInReview => _t('בבדיקה', 'In review');
  String get photoRejected => _t('לא תואם · מוסתרת', 'No match · hidden');
  String get photoRejectedHint => _t(
        'התמונה לא תואמת לפנים שאימתת, ולכן אחרים לא רואים אותה.',
        'This photo does not match your verified face, so others cannot see it.',
      );

  // -- live face check -----------------------------------------------------

  String get faceTitle => _t('אימות פנים', 'Face check');
  String get faceHeadline =>
      _t('נראה שזה באמת את/ה', 'Show it is really you');
  String get faceBody => _t(
        'המצלמה תיפתח ונבקש ממך לסובב את הראש לפי הוראות. זה לוקח כ-15 שניות. '
            'אחרי האימות, כל תמונה שתעלו תיבדק שהיא שלך.',
        'The camera opens and we ask you to turn your head a few times. About 15 '
            'seconds. After that, every photo you upload is checked to be you.',
      );
  String get consentTitle => _t('לפני שמתחילים', 'Before we start');
  String get consentBody => _t(
        'נשמור תבנית מספרית מוצפנת של הפנים (לא תמונה), רק כדי להשוות אליה את '
            'תמונות הפרופיל שלך. התמונות מהמצלמה נמחקות מיד. אפשר למחוק את התבנית '
            'בכל רגע מההגדרות.',
        'We keep an encrypted numeric template of your face (not a picture), only '
            'to compare your profile photos with it. Camera frames are deleted right '
            'away. You can delete the template at any time in settings.',
      );
  String get consentAgree => _t('מסכים/ה, מתחילים', 'I agree, start');
  String get startCheck => _t('התחלת אימות', 'Start the check');
  String get stepCenter => _t('הסתכלו ישר למצלמה', 'Look straight at the camera');
  String get stepLeft => _t('סובבו את הראש שמאלה', 'Turn your head to the left');
  String get stepRight => _t('סובבו את הראש ימינה', 'Turn your head to the right');
  String get holdStill => _t('החזיקו…', 'Hold…');
  String get checkingFace => _t('בודקים…', 'Checking…');
  String get faceApproved => _t('הפנים אומתו!', 'Face verified!');
  String get faceApprovedBody => _t(
        'מעכשיו אפשר להיכנס ל-Live, ותמונות חדשות ייבדקו אוטומטית.',
        'You can go Live now, and new photos are checked automatically.',
      );
  String get facePending => _t('כמעט — מישהו יעבור על זה', 'Almost — someone will take a look');
  String get facePendingBody => _t(
        'חלק מהצילומים לא היו חדים מספיק, אז אדם יבדוק. בדרך כלל תוך שעות.',
        'Some frames were not sharp enough, so a person will check. Usually within hours.',
      );
  String get tryAgain => _t('לנסות שוב', 'Try again');
  String get manualFallback =>
      _t('אימות ידני במקום זה (סלפי בתנוחה)', 'Verify manually instead (pose selfie)');
  String get cameraDenied => _t(
        'אין גישה למצלמה. אשרו גישה בדפדפן או בהגדרות ונסו שוב.',
        'No camera access. Allow it in the browser or settings and try again.',
      );
  String get deleteFace => _t('מחיקת נתוני הפנים', 'Delete face data');
  String get deleteFaceDone => _t('נתוני הפנים נמחקו', 'Face data deleted');
  String get verifyToGoLive => _t('אימות פנים', 'Verify face');

  String faceReason(String? reason) {
    switch (reason) {
      case 'no_face':
        return _t('לא זיהינו פנים. ודאו תאורה טובה ופנים במרכז.',
            'No face found. Use good light and keep your face centred.');
      case 'multiple_faces':
        return _t('יש יותר מאדם אחד בצילום.', 'More than one person in the frame.');
      case 'face_too_small':
        return _t('התקרבו למצלמה.', 'Come closer to the camera.');
      case 'wrong_direction':
        return _t('הסיבוב לא זוהה. סובבו את הראש יותר, לאט.',
            'The turn was not detected. Turn further, slowly.');
      case 'identity_mismatch':
      case 'replayed_frame':
        return _t('משהו לא הסתדר בין הצילומים. נסו שוב.',
            'The frames did not line up. Try again.');
      default:
        return _t('לא הצלחנו לאמת. נסו שוב באור טוב.',
            'We could not verify. Try again in good light.');
    }
  }

  // -- errors --------------------------------------------------------------

  /// Sentences for the server and device codes added with these features.
  /// Null for a code this file does not know.
  String? datingError(String? code) {
    switch (code) {
      case 'too_far':
        return _t('נראה שאתם לא במקום. היכנסו פנימה ונסו שוב.',
            'You do not seem to be there. Step inside and try again.');
      case 'location_required':
      case 'location_denied':
        return _t('צריך לאשר גישה למיקום כדי להיכנס.',
            'Location access is needed to join.');
      case 'location_off':
        return _t('שירותי המיקום כבויים בטלפון.', 'Location services are off.');
      case 'location_timeout':
        return _t('לא הצלחנו לקבל מיקום. נסו שוב, אולי ליד חלון.',
            'Could not get a location. Try again, maybe near a window.');
      case 'venue_unknown':
        return joinUnknown;
      case 'verification_required':
        return _t('כדי להופיע לאחרים צריך קודם לאמת פנים.',
            'Verify your face first to appear to others.');
      case 'photo_no_face':
        return _t('לא מצאנו פנים בתמונה. העלו תמונה שרואים בה אתכם.',
            'No face in that photo. Upload one that shows you.');
      case 'photo_face_mismatch':
        return _t('זה לא נראה כמוך. אפשר להעלות רק תמונות שלך.',
            'That does not look like you. Only photos of you.');
      case 'face_service_unavailable':
        return _t('בדיקת הפנים לא זמינה כרגע. נסו שוב בעוד דקה.',
            'Face checks are unavailable right now. Try again in a minute.');
      case 'too_many_attempts':
        return _t('יותר מדי ניסיונות היום. נסו שוב מחר.',
            'Too many attempts today. Try again tomorrow.');
      case 'photo_limit_reached':
        return _t('אפשר עד 4 תמונות.', 'Up to 4 photos.');
      case 'consent_required':
        return _t('צריך הסכמה כדי להתחיל.', 'Consent is needed to start.');
      case 'not_live':
        return _t('צריך להיות ב-Live כדי להסתיר.', 'You need to be Live to hide someone.');
      default:
        return null;
    }
  }
}
