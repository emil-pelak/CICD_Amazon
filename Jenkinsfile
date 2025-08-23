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
          # do obróbki zrzutu
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
      // --- snapshot (zawsze, także przy FAIL) + archiwizacja ---
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
                  --window-size=1500,1700 \
                  --screenshot="${SNAP_RAW}" "file://${HTML}" && okshot=1 && break
            fi
          done

          if [ "$okshot" -eq 1 ] && [ -s "${SNAP_RAW}" ]; then
            # zmniejsz obraz do rozsądnej szerokości (np. 1100px)
            python3 - "${SNAP_RAW}" "${SNAP_OUT}" <<'PY'
from PIL import Image
import sys
src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src)
max_w = 1100
if im.width > max_w:
    h = int(im.height * (max_w / im.width))
    im = im.resize((max_w, h), Image.LANCZOS)
im.save(dst)
PY
            echo "Report snapshot created at ${SNAP_OUT}"
          else
            echo "WARN: could not create snapshot (no Chrome/Chromium or screenshot failed)."
          fi
        else
          echo "WARN: ${ROBOT_DIR}/report.html not found – skipping snapshot."
        fi

        ( cd ${ROBOT_DIR} && zip -9qr ../${ROBOT_DIR}.zip . ) || true
      '''

      publishHTML(target: [
        allowMissing: true,
        keepAll: true,
        reportDir: "${ROBOT_DIR}",
        reportFiles: "report.html",
        reportName: "Robot Report"
      ])
      archiveArtifacts artifacts: "${ROBOT_DIR}/**, ${ROBOT_DIR}.zip", fingerprint: true

      // --- E-mail: tylko raport (obraz) ---
      script {
        // baza64 obrazu (jeśli jest)
        def b64 = ''
        def snapPath = "${env.WORKSPACE}/${ROBOT_DIR}/report_snapshot.png"
        if (fileExists(snapPath)) {
          b64 = sh(script: "base64 -w0 '${snapPath}'", returnStdout: true).trim()
        }

        // prosty, czysty mail – wyłącznie zrzut raportu
        String mailSubject = "[${currentBuild.currentResult ?: 'SUCCESS'}] ${env.JOB_NAME} #${env.BUILD_NUMBER} – Robot Report"
        String onlyReportBody = """
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>${mailSubject}</title>
<style>
  body{margin:0;padding:0;background:#f8fafc;font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif}
  .wrap{max-width:1120px;margin:18px auto}
  img.snap{display:block;width:100%;height:auto;border:1px solid #e5e7eb;border-radius:10px;box-shadow:0 1px 3px rgba(0,0,0,.06)}
</style>
</head>
<body>
  <div class="wrap">
    ${ b64 ? "<img class=\\"snap\\" src=\\"data:image/png;base64,${b64}\\" alt=\\"Robot report\\"/>"
           : "<div style='padding:16px;border:1px dashed #e5e7eb;border-radius:10px;background:#fff;color:#6b7280'>Snapshot unavailable</div>" }
  </div>
</body>
</html>
"""

        // dołącz ZIP tylko jeśli mały (opcjonalnie)
        def zipPath = "${ROBOT_DIR}.zip"
        def attachZip = false
        if (fileExists(zipPath)) {
          def bytes = (sh(script: "stat -c%s '${zipPath}' || echo 0", returnStdout: true).trim() as long)
          long maxByte = (env.MAX_ATTACH_MB as Integer) * 1024L * 1024L
          attachZip = (bytes > 0 && bytes <= maxByte)
          echo "ZIP size: ${bytes} bytes (attach <= ${maxByte}) -> attachZip=${attachZip}"
        }

        if (attachZip) {
          emailext(subject: mailSubject, from: env.EMAIL_FROM, to: env.EMAIL_TO,
                   body: onlyReportBody, mimeType: 'text/html', attachmentsPattern: zipPath)
        } else {
          emailext(subject: mailSubject, from: env.EMAIL_FROM, to: env.EMAIL_TO,
                   body: onlyReportBody, mimeType: 'text/html')
        }
      }
    }
  }
}
