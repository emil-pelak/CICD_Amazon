// Jenkinsfile — CICD_Wikipedia (mail: tylko Passed/Failed + kadr PNG w pikselach)
pipeline {
  agent any

  environment {
    ROBOT_DIR      = "robot_reports"
    PY_ENV         = "venv"
    HEADLESS       = "true"

    // mail
    EMAIL_FROM     = "emil-pelak@wp.pl"
    EMAIL_TO       = "emil-pelak@outlook.com"
    MAX_ATTACH_MB  = "7"

    // parametry kadrowania screenshota (piksele; łatwo korygować po pierwszym mailu)
    SNAP_LEFT      = "140"   // ile pikseli uciąć od LEWEJ
    SNAP_TOP       = "220"   // ile pikseli uciąć od GÓRY
    SNAP_WIDTH     = "1300"  // docelowa szerokość wycinka; 0 = do końca
    SNAP_HEIGHT    = "560"   // docelowa wysokość wycinka; 0 = do końca
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
          python3 -m venv "${PY_ENV}" || true
          . "${PY_ENV}/bin/activate"
          pip install --upgrade pip wheel
          pip install -r requirements.txt
          # do kadrowania PNG
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

          . "${PY_ENV}/bin/activate"
          mkdir -p "${ROBOT_DIR}"

          robot \
            --outputdir "${ROBOT_DIR}" \
            --reporttitle "Wikipedia - test report" \
            --logtitle    "Wikipedia - test log" \
            --variable HEADLESS:${HEADLESS} \
            tests/
        '''
      }
    }
  }

  post {
    always {

      // --- Snapshot + kadrowanie pikselowe + ZIP ---
      sh '''
        set -e
        HTML="$(readlink -f "${ROBOT_DIR}/report.html" || true)"
        SNAP_RAW="${ROBOT_DIR}/report_raw.png"
        SNAP="${ROBOT_DIR}/report_snapshot.png"

        if [ -n "$HTML" ] && [ -f "$HTML" ]; then
          okshot=0
          for B in google-chrome google-chrome-stable chromium chromium-browser; do
            if command -v "$B" >/dev/null 2>&1; then
              "$B" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
                   --force-device-scale-factor=1.25 --window-size=1600,1800 \
                   --screenshot="${SNAP_RAW}" "file://${HTML}" && okshot=1 && break
            fi
          done

          if [ "$okshot" -eq 1 ] && [ -s "${SNAP_RAW}" ]; then
            # Kadrowanie od górnego-lewego rogu o X/Y pikseli; rozmiar docelowy w px
            python3 - "${SNAP_RAW}" "${SNAP}" <<'PY' || cp "${SNAP_RAW}" "${SNAP}"
from PIL import Image
import sys, os
src, dst = sys.argv[1], sys.argv[2]
left  = int(os.environ.get("SNAP_LEFT", "0"))
top   = int(os.environ.get("SNAP_TOP",  "0"))
w_set = int(os.environ.get("SNAP_WIDTH",  "0"))
h_set = int(os.environ.get("SNAP_HEIGHT", "0"))

im = Image.open(src).convert("RGB")
W, H = im.size

w = (W - left) if w_set <= 0 else w_set
h = (H - top)  if h_set <= 0 else h_set

left  = max(0, min(left,  W-1))
top   = max(0, min(top,   H-1))
right = max(left+1,  min(left + w, W))
bottom= max(top +1,  min(top  + h, H))

im.crop((left, top, right, bottom)).save(dst, optimize=True)
PY
          else
            echo "WARN: could not create snapshot – copying raw if exists"
            [ -s "${SNAP_RAW}" ] && cp "${SNAP_RAW}" "${SNAP}" || true
          fi
        else
          echo "WARN: ${ROBOT_DIR}/report.html not found – skipping snapshot."
        fi

        ( cd "${ROBOT_DIR}" && zip -9qr ../"${ROBOT_DIR}.zip" . ) || true
      '''

      // --- Opublikuj (przyda się do wglądu z Joba) ---
      publishHTML(target: [
        allowMissing: true,
        keepAll: true,
        reportDir: "${ROBOT_DIR}",
        reportFiles: "report.html",
        reportName: "Robot Report"
      ])
      archiveArtifacts artifacts: "${ROBOT_DIR}/**, ${ROBOT_DIR}.zip", fingerprint: true

      // --- Mail (tylko Passed/Failed + kadr PNG) ---
      script {
        // Linki
        def reportUrl  = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl = "${env.BUILD_URL}console"
        def zipUrl     = "${env.BUILD_URL}artifact/${ROBOT_DIR}.zip"

        // Git meta (z bezpiecznymi fallbackami)
        def branch = sh(
          script: 'git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev/main',
          returnStdout: true
        ).trim().replaceFirst(/^origin\\//,'')
        def shortSha    = sh(script: 'git rev-parse --short HEAD 2>/dev/null || echo ???????', returnStdout: true).trim()
        def commitTitle = sh(script: 'git log -1 --pretty=%s 2>/dev/null || echo "-"', returnStdout: true).trim()
        def author      = sh(script: 'git log -1 --pretty=%an 2>/dev/null || echo "-"', returnStdout: true).trim()

        // Statystyki z output.xml (bez XmlSlurper — działa w sandboxie)
        def stats = sh(script: '''
python3 - <<'PY'
import xml.etree.ElementTree as ET, json, sys
p=f=n=t=0
try:
    r=ET.parse("robot_reports/output.xml").getroot()
    s=r.find("./statistics/total/stat")
    t=int(s.get("total","0")); p=int(s.get("pass","0")); f=int(s.get("fail","0"))
except Exception: pass
print(f"{p} {f} {t}")
PY
''', returnStdout: true).trim().split(' ')
        def passed = (stats.size()>=1 ? stats[0] : "0")
        def failed = (stats.size()>=2 ? stats[1] : "0")
        // total available in stats[2] if needed

        // Obrazek w base64
        def b64 = ""
        def shot = "${env.WORKSPACE}/${ROBOT_DIR}/report_snapshot.png"
        if (fileExists(shot)) {
          b64 = sh(script: "base64 -w0 '${shot}'", returnStdout: true).trim()
        }

        String buildStatus = currentBuild.currentResult ?: 'SUCCESS'
        String statusColor = (buildStatus == 'SUCCESS') ? '#16a34a' : '#dc2626'
        String statusIcon  = (buildStatus == 'SUCCESS') ? '✅' : '❌'
        String subj        = "[${buildStatus}] ${env.JOB_NAME} #${env.BUILD_NUMBER} – Robot Report"

        String body = """
<!doctype html>
<html><head><meta charset="utf-8"/>
<title>${subj}</title>
<style>
  body { font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;background:#f8fafc;padding:20px }
  .card{ background:#fff;border:1px solid #e5e7eb;border-radius:14px;max-width:900px;margin:auto;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.06) }
  .status{ background:${statusColor};color:#fff;padding:16px 20px;font-size:18px;font-weight:800 }
  .wrap{ padding:16px 20px }
  .grid2{ display:grid;grid-template-columns:1fr 1fr;gap:12px }
  .box{ border:1px solid #eef2f7;border-radius:12px;padding:12px }
  .row{ display:flex;align-items:center;gap:8px;margin:6px 0 }
  .chip{ display:inline-flex;align-items:center;gap:6px;padding:4px 10px;border-radius:999px;border:1px solid #e5e7eb;background:#f9fafb;font-family:ui-monospace,Menlo,monospace }
  .branch{ background:#eef2ff;border-color:#e0e7ff;color:#1e3a8a }
  .sha{ background:#ecfeff;border-color:#cffafe;color:#155e75 }
  .btns{ padding:0 20px 14px 20px }
  a.btn{ display:inline-block;margin-right:10px;margin-top:10px;padding:10px 14px;border-radius:10px;text-decoration:none;color:#fff }
  a.p { background:#111827 } a.s { background:#374151 } a.z { background:#0ea5e9 }
  .kpis{ display:grid;grid-template-columns:repeat(2,minmax(140px,1fr));gap:10px }
  .kpi{ background:#f9fafb;border:1px solid #eef2f7;border-radius:12px;padding:10px;text-align:center }
  .kpi .lab{ font-size:12px;color:#6b7280 } .kpi .val{ font-size:22px;font-weight:800;margin-top:2px }
  .kpi.good .val{ color:#16a34a } .kpi.bad .val{ color:#dc2626 }
  img.snap{ max-width:860px;width:100%;height:auto;border:1px solid #eef2f7;border-radius:10px;display:block }
</style>
</head>
<body>
  <div class="card">
    <div class="status">${statusIcon} ${buildStatus} • ${env.JOB_NAME} • Build #${env.BUILD_NUMBER}</div>

    <div class="wrap grid2">
      <div class="box">
        <div class="row"><span style="color:#6b7280;font-size:12px">Branch</span> <span class="chip branch">${branch}</span></div>
        <div class="row"><span style="color:#6b7280;font-size:12px">SHA</span>    <span class="chip sha">${shortSha}</span></div>
      </div>
      <div class="box">
        <div class="row" style="font-weight:700">Commit title: ${commitTitle}</div>
        <div class="row">Author: ${author}</div>
      </div>
    </div>

    <div class="wrap">
      <div class="kpis">
        <div class="kpi good"><div class="lab">Passed</div><div class="val">${passed}</div></div>
        <div class="kpi bad"><div class="lab">Failed</div><div class="val">${failed}</div></div>
      </div>
    </div>

    <div class="btns">
      <a class="btn p" href="${reportUrl}"  target="_blank">🔎 Open "Wikipedia - test report"</a>
      <a class="btn s" href="${consoleUrl}" target="_blank">🖥 Console Output</a>
      <a class="btn z" href="${zipUrl}"     target="_blank">📦 Download results (ZIP)</a>
    </div>

    <div class="wrap">
      ${ b64 ? "<img class='snap' src='data:image/png;base64," + b64 + "' alt='Robot report'/>"
             : "<div style='border:1px dashed #e5e7eb;border-radius:10px;padding:14px;color:#6b7280'>Snapshot unavailable</div>" }
    </div>
  </div>
</body></html>
"""

        // Załącz ZIP jeśli nie jest za duży
        def zipPath   = "${ROBOT_DIR}.zip"
        def attachZip = false
        if (fileExists(zipPath)) {
          try {
            long bytes   = (sh(script: "stat -c%s '${zipPath}' || echo 0", returnStdout: true).trim() as long)
            long maxByte = (env.MAX_ATTACH_MB as Integer) * 1024L * 1024L
            attachZip = (bytes > 0 && bytes <= maxByte)
            echo "ZIP size: ${bytes} bytes (attach <= ${maxByte}) -> attachZip=${attachZip}"
          } catch (ignored) {}
        }

        if (attachZip) {
          emailext(subject: subj, from: env.EMAIL_FROM, to: env.EMAIL_TO,
                   body: body, mimeType: 'text/html', attachmentsPattern: zipPath)
        } else {
          emailext(subject: subj, from: env.EMAIL_FROM, to: env.EMAIL_TO,
                   body: body, mimeType: 'text/html')
        }
      }
    }
  }
}
