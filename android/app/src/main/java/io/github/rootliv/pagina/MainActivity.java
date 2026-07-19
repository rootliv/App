package io.github.rootliv.pagina;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    // La WebView di Android, di base, applica ANCHE l'impostazione di sistema
    // "Dimensione testo" (Impostazioni > Schermo) sopra le dimensioni scritte nel CSS.
    // È per questo che nell'app installata (APK) il testo appariva più grande che nella
    // PWA aperta da browser: il browser gestisce quello zoom in modo diverso dalla WebView
    // incorporata. Bloccando textZoom a 100 il testo segue SEMPRE e SOLO il CSS della
    // pagina, identico alla PWA, a prescindere dalle impostazioni del telefono.
    getBridge().getWebView().getSettings().setTextZoom(100);
  }
}
