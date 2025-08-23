pipeline {
  agent any

  environment {
    ROBOT_DIR      = "robot_reports"
    PY_ENV         = "venv"
    HEADLESS       = "true"
    EMAIL_FROM     = "emil-pelak@wp.pl"
    EMAIL_TO       = "emil-pelak@outlook.com"
    MAX_ATTACH_MB  = "7"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout([$class: 'GitSCM',
          branches: [[name: "*/dev/main"]],
          userRemoteConfigs: [[
            url: "git@github.com:emil-pelak/CICD_Wikipedia.git",
            credentialsId: "local_github-ssh"
          ]]
        ])
      }
    }

    stage('Install dependencies') {
      steps {
        sh '''
          set -e
          python3 -m venv ${PY_ENV} || true
          . ${PY_ENV}/bin/activate
          pip install --upgrade pip wheel
          pip install -r requirements.txt
          # biblioteka do obróbki obrazu:
          pip install Pillow
        '''
      }
    }

    stage('Run tests') {
      steps {
        sh '''
          set -e
          echo "Cleaning old /tmp/robot-* profiles"
          find /tmp -maxdepth 1 -user "$(whoami)" -type d -name "robot-*" -exec rm -rf {} + || true

          . ${PY_ENV}/bin/activate
          mkdir -p ${ROBOT_DIR}

          robot \
            --outputdir ${ROBOT_DIR} \
            --reporttitle "Wikipedia - test report" \
            --logtitle    "Wikipedia - test log"  \
            --variable HEADLESS:${HEADLESS} \
            tests/
        '''
      }
    }
  }

  post {
    always {
      // --- Snapshot + agresywne przycięcie ---
      sh '''
        set -e
        . ${PY_ENV}/bin/activate

        HTML="$(readlink -f ${ROBOT_DIR}/report.html || true)"
        SNAP_RAW="${ROBOT_DIR}/report_raw.png"
        SNAP_OUT="${ROBOT_DIR}/report_snapshot.png"

        if [ -n "$HTML" ] && [ -f "$HTML" ]; then
          okshot=0
          for B in google-chrome google-chrome-stable chromium chromium-browser; do
            if command -v "$B" >/dev/null 2>&1; then
              "$B" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
                  --force-device-scale-factor=1.15 \
                  --window-size=1600,1800 \
                  --screenshot="${SNAP_RAW}" "file://${HTML}" && okshot=1 && break
            fi
          done

          if [ "$okshot" -eq 1 ] && [ -s "${SNAP_RAW}" ]; then
            # 1) usuń jednolite tło; 2) usuń dół z "Test Details"; 3) przeskaluj do 1000px
            python3 - "${SNAP_RAW}" "${SNAP_OUT}" <<'PY'
from PIL import Image, ImageChops, ImageStat
import sys

src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')

# ---- TRIM: usuń jednolite tło (kolor rogu) ----
bg_color = im.getpixel((5,5))
bg = Image.new('RGB', im.size, bg_color)
diff = ImageChops.difference(im, bg)
# czułość: >10 jasności traktujemy jako "nie tło"
bbox = diff.convert('L').point(lambda x: 0 if x < 10 else 255, mode='1').getbbox()
if bbox:
    im = im.crop(bbox)

# ---- Utnij dół z "Test Details" (heurystyka) ----
w, h = im.size
# jeśli po trymie wysokość jest duża, obetnij ~26% od dołu
if h > 800:
    cut = int(h * 0.74)  # zostaw ~74% górnej części (Summary + Test Statistics)
    im = im.crop((0, 0, w, cut))

# ---- Skalowanie do czytelnej szerokości ----
max_w = 1000
if im.width > max_w:
    new_h = int(im.height * (max_w / im.width))
    im = im.resize((max_w, new_h), Image.LANCZOS)

im.save(dst)
PY
            echo "Report snapshot created at ${SNAP_OUT}"
          else
            echo "WARN: could not create snapshot."
          fi
        else
          echo "WARN: ${ROBOT_DIR}/report.html not found – skipping snapshot."
        fi

        ( cd ${ROBOT_DIR} && zip -9qr ../${ROBOT_DIR}.zip . ) || true
      '''

      // --- Wyślij WYŁĄCZNIE obraz raportu ---
      script {
        def b64 = ''
        def snapPath = "${env.WORKSPACE}/${ROBOT_DIR}/report_snapshot.png"
        if (fileExists(snapPath)) {
          b64 = sh(script: "base64 -w0 '${snapPath}'", returnStdout: true).trim()
        }

        String imgHtml = b64 ?
          ("<img class='snap' src='data:image/png;base64," + b64 + "' alt='Robot report'/>") :
          "<div style='padding:16px;border:1px dashed #e5e7eb;border-radius:10px;background:#fff;color:#6b7280'>Snapshot unavailable</div>"

        String mailSubject = "[${currentBuild.currentResult ?: 'SUCCESS'}] ${env.JOB_NAME} #${env.BUILD_NUMBER} – Robot Report"

        String bodyHtml = """
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>${mailSubject}</title>
<style>
  body{margin:0;padding:0;background:#f8fafc;font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif}
  .wrap{max-width:1120px;margin:18px auto;padding:0 8px}
  img.snap{display:block;width:100%;height:auto;border:1px solid #e5e7eb;border-radius:10px;box-shadow:0 1px 3px rgba(0,0,0,.06)}
</style>
</head>
<body><div class="wrap">
  ${imgHtml}
</div></body>
</html>
"""

        // Załącz ZIP tylko, gdy mały
        def zipPath = "${ROBOT_DIR}.zip"
        def attachZip = false
        if (fileExists(zipPath)) {
          long bytes = (sh(script: "stat -c%s '${zipPath}' || echo 0", returnStdout: true).trim() as long)
          long maxByte = (env.MAX_ATTACH_MB as Integer) * 1024L * 1024L
          attachZip = (bytes > 0 && bytes <= maxByte)
          echo "ZIP size: ${bytes} bytes (attach <= ${maxByte}) -> attachZip=${attachZip}"
        }

        if (attachZip) {
          emailext(subject: mailSubject, from: env.EMAIL_FROM, to: env.EMAIL_TO,
                   body: bodyHtml, mimeType: 'text/html', attachmentsPattern: zipPath)
        } else {
          emailext(subject: mailSubject, from: env.EMAIL_FROM, to: env.EMAIL_TO,
                   body: bodyHtml, mimeType: 'text/html')
        }
      }
    }
  }
}
