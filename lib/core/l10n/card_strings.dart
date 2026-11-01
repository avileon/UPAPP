import 'app_strings.dart';

/// Copy for business cards: handing yours over, and answering one.
/// Hebrew is the reference copy, as everywhere else.
extension CardStrings on AppStrings {
  bool get _he => localeCode == 'he';

  String _t(String he, String en) => _he ? he : en;

  // -- my card ---------------------------------------------------------------

  String get myCard => _t('כרטיס הביקור שלי', 'My card');
  String get myCardTitle => _t('הכרטיס שלך', 'Your card');
  String get myCardHint => _t(
        'תנו לסרוק את ה-QR. מי שסורק רואה את השם והתמונה הראשית שלך, ויכול לשלוח לך UP — ונפתחת ביניכם שיחה.',
        'Let them scan the QR. They see your first name and main photo, and can send you an UP — and a chat opens.',
      );
  String get myCardOnePerson => _t(
        'כל קוד עונה לאדם אחד ותקף ל-24 שעות. לאדם הבא — קוד חדש.',
        'Each code answers one person and lasts 24 hours. Next person, new code.',
      );
  String get myCardNew => _t('קוד חדש', 'New code');
  String get myCardShare => _t('שליחת קישור', 'Send link');
  String get myCardCopied => _t('הקישור הועתק', 'Link copied');
  String get myCardRevoke => _t('ביטול כל הכרטיסים שנתתי', 'Cancel every card I gave');
  String get myCardRevoked =>
      _t('כל הכרטיסים שנתת בוטלו', 'Every card you gave is cancelled');
  String get myCardNeedsName => _t(
        'כדי לתת כרטיס צריך קודם שם ותמונה בפרופיל.',
        'Add a name and a photo to your profile first.',
      );

  String get walletAdd => _t('הוספה ל-Google Wallet', 'Add to Google Wallet');
  String get walletHint => _t(
        'כרטיס קבוע עם QR, נפתח ממסך הנעילה. כרטיס Wallet חדש מבטל את הקודם.',
        'A lasting card with a QR, opened from the lock screen. A new Wallet card replaces the old one.',
      );

  // -- NFC -------------------------------------------------------------------

  String get nfcReady => _t('הצמידו גב אל גב', 'Hold the phones back to back');
  String get nfcReadyHint => _t(
        'הטלפון שלך משדר עכשיו את הכרטיס. אצל הצד השני המסך צריך להיות פתוח.',
        'Your phone is sending the card now. The other phone needs its screen unlocked.',
      );
  String nfcSent(int n) => _t('נשלח ✓ ($n)', 'Sent ✓ ($n)');
  String get nfcOff => _t('NFC כבוי', 'NFC is off');
  String get nfcOffHint => _t(
        'הפעילו NFC כדי לתת את הכרטיס בנגיעה. בינתיים — ה-QR עובד.',
        'Turn on NFC to give your card with a tap. Meanwhile, the QR works.',
      );
  String get nfcTurnOn => _t('להפעלת NFC', 'Turn on NFC');

  // -- a card someone gave me ----------------------------------------------

  String cardFrom(String name) =>
      _t('$name נתן/ה לך את הכרטיס שלו/ה', '$name gave you their card');
  String get cardLead => _t(
        'רוצה להמשיך להכיר? שלח/י UP — ותיפתח לכם שיחה.',
        'Want to keep talking? Send an UP — and a chat opens.',
      );
  String get cardSendUp => _t('תן UP', 'Send UP');
  String get cardNotNow => _t('לא עכשיו', 'Not now');
  String get cardMatched => _t('יש Match!', 'It\'s a Match!');
  String get cardOpeningChat => _t('פותחים שיחה…', 'Opening the chat…');
  String get cardToChat => _t('לשיחה', 'Open chat');
  String get cardVerifyFirst => _t(
        'רגע לפני: אימות פנים קצר, כדי שכולם ב-UP יהיו אמיתיים.',
        'One thing first: a quick face check, so everyone on UP is real.',
      );
  String get cardVerifyAction => _t('לאימות', 'Verify');

  String? cardError(String? code) {
    switch (code) {
      case 'card_expired':
        return _t('הכרטיס הזה כבר פג תוקף. בקש/י קוד חדש.',
            'This card has expired. Ask for a new code.');
      case 'card_used':
        return _t('מישהו אחר כבר ענה לכרטיס הזה.',
            'Someone else already answered this card.');
      case 'card_unknown':
        return _t('הכרטיס הזה לא קיים או שבוטל.',
            'This card does not exist or was cancelled.');
      case 'wallet_unavailable':
        return _t('Google Wallet עדיין לא מחובר בשרת.',
            'Google Wallet is not set up on the server yet.');
      case 'card_rate_limited':
        return _t('יותר מדי ניסיונות. נסו שוב בעוד כמה דקות.',
            'Too many tries. Try again in a few minutes.');
      default:
        return null;
    }
  }
}
