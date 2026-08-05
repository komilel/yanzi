{
  pkgs,
  config,
}: let
  # Tesseract engine with only the language data we actually need bundled
  # in (sets TESSDATA_PREFIX via nixpkgs' wrapper.nix). eng is required by
  # tesseract's internal lookup; chi_sim/chi_tra cover simplified/traditional.
  tesseract = pkgs.tesseract5.override {
    enableLanguages = ["chi_sim" "chi_tra" "eng"];
  };
in
  pkgs.writeShellApplication {
    name = "translate-screen";

    runtimeInputs = with pkgs; [
      grim # Wayland-native screenshot (no portal needed on niri)
      slurp # Wayland-native region picker
      wl-clipboard # wl-copy for the result
      libnotify # notify-send (best-effort, via dms-shell)
      gnused # text cleanup
      translate-shell # the `trans` CLI (confirmed working)
      tesseract
    ];

    text = ''
      # Capture a screen region, OCR it (Chinese), and translate to English.
      #
      # Pipeline (no temp files):
      #   slurp  ─►  grim -g <region> -  ─►  tesseract - -  ─►  trans -b :en
      #   (Wayland-native)                 (PNG→stdout)        (image→text)    (→English)
      #
      # Output: translation copied to the clipboard + a notification showing
      # both the OCR'd original and the translation.
      set -euo pipefail

      # --- 1. Pick a region. Abort silently if the user cancels (Esc). -------
      region=$(slurp) || exit 0

      # --- 2. Capture + OCR. -------------------------------------------------
      # chi_sim = Simplified Chinese (chi_tra is also bundled, pass via -l if
      # needed). +eng lets it handle Latin/punctuation/numbers mixed into the
      # Chinese text, which is the common real-world case.
      ocr=$(grim -g "$region" - | tesseract - - -l chi_sim+eng 2>/dev/null) || {
        notify-send "🌐 Translate" "OCR failed" 2>/dev/null || true
        exit 1
      }

      # tesseract appends a trailing form-feed (\f); strip it + trim whitespace.
      ocr=$(printf '%s' "$ocr" | sed 's/\f//g; s/^[[:space:]]*//; s/[[:space:]]*$//')

      if [[ -z "$ocr" ]]; then
        notify-send "🌐 Translate" "No text detected" 2>/dev/null || true
        exit 0
      fi

      # --- 3. Translate to English (auto-detects the source language). -------
      translation=$(printf '%s' "$ocr" | trans -b :en 2>/dev/null) || {
        notify-send "🌐 Translate" "Translation failed" 2>/dev/null || true
        exit 1
      }
      translation=$(printf '%s' "$translation" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

      if [[ -z "$translation" ]]; then
        notify-send "🌐 Translate" "Translation failed" 2>/dev/null || true
        exit 1
      fi

      # --- 4. Output: clipboard (guaranteed) + notification (best-effort). ---
      printf '%s' "$translation" | wl-copy

      body=$(printf '%s\n→ %s' "$ocr" "$translation")
      notify-send --app-name="Translate" "🌐 Translate" "$body" 2>/dev/null || true
    '';
  }
