import 'package:firebase_auth/firebase_auth.dart';

class FirebaseConfig {
  static ActionCodeSettings get actionCodeSettings => ActionCodeSettings(
        // TODO: Firebase Consoleの「承認済みドメイン」にこのURL（およびそのドメイン）を追加する必要があります
        url: 'https://v-effect.app/verify',
        handleCodeInApp: true,
        iOSBundleId: 'com.veffect.app.vEffect',
        androidPackageName: 'com.veffect.app.v_effect',
        androidInstallApp: true,
        androidMinimumVersion: '1',
      );
}
