# Messenger (Flutter + Node.js)

## 1. Server starten (auf einem PC/Server im selben Netz oder online)
    cd server
    npm install
    npm start
Läuft auf Port 8080. Im lokalen Netz die IP des PCs herausfinden (z. B. 192.168.0.10).

## 2. App-Projekt erzeugen
    flutter create --org com.example --project-name messenger app_tmp
    cp -r app/lib app_tmp/
    cp app/pubspec.yaml app_tmp/pubspec.yaml
    cd app_tmp
    flutter pub get

## 3. Android-Manifest anpassen
Datei `android/app/src/main/AndroidManifest.xml`:

Vor dem `<application ...>`-Tag einfügen:
    <uses-permission android:name="android.permission.INTERNET"/>

Und im `<application ...>`-Tag ergänzen (nötig für ws:// ohne TLS):
    android:usesCleartextTraffic="true"

## 4. APK bauen
    flutter build apk --release
Ergebnis: `build/app/outputs/flutter-apk/app-release.apk`

## 5. Benutzen
APK auf zwei Handys installieren, in der App Namen und Server-Adresse
(z. B. ws://192.168.0.10:8080) eingeben.

Für Zugriff über das Internet: Server auf einem VPS/Render/Railway hosten
und mit TLS betreiben, dann wss://deine-domain verwenden
(und usesCleartextTraffic wieder entfernen).
