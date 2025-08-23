pipeline {
  agent any

  options {
    skipDefaultCheckout(true)
    timestamps()
  }

  environment {
    ROBOT_DIR     = "robot_reports"
    PY_ENV        = "venv"
    HEADLESS      = "true"
    EMAIL_FROM    = "emil-pelak@wp.pl"
    EMAIL_TO      = "emil-pelak@outlook.com"
    MAX_ATTACH_MB = "7"
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
          # do przycięcia obrazka (fallback – jeśli brak, pipeline i tak pójdzie dalej)
          pip install -q Pillow || true
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
            --logtitle    "Wikipedia - test log"  \
            --variable HEADLESS:${HEADLESS} \
            tests/
        '''
      }
    }
  }

  post {
    always {
      // ── Snapshot + ZIP (zawsze, także przy FAIL) ───────────────────────────────
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
            # Delikatne przycięcie czerwonych marginesów – jeśli Pillow jest
            python3 - "$SNAP_RAW" "$SNAP" <<'PY' || cp "$SNAP_RAW" "$SNAP"
from PIL import Image
import sys
src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
w,h = im.size
# utnij górę/dół po 3% oraz boki po 8% jako uniwersalny kompromis
crop = (int(w*0.08), int(h*0.03), int(w*0.92), int(h*0.75))
im.crop(crop).save(dst)
PY
          else
            echo "WARN: could not create snapshot – copying raw"
            [ -s "${SNAP_RAW}" ] && cp "${SNAP_RAW}" "${SNAP}" || true
          fi
        else
          echo "WARN: ${ROBOT_DIR}/report.html not found – skipping snapshot."
        fi

        ( cd "${ROBOT_DIR}" && zip -9qr ../"${ROBOT_DIR}.zip" . ) || true
      '''

      // ── Publikacja HTML + artefakty ────────────────────────────────────────────
      publishHTML(target: [
        allowMissing: true,
        keepAll: true,
        reportDir: env.ROBOT_DIR,
        reportFiles: "report.html",
        reportName: "Robot Report"
      ])
      archiveArtifacts artifacts: "${env.ROBOT_DIR}/**, ${env.ROBOT_DIR}.zip", fingerprint: true

      // ── E-mail (KPI + screenshot) ─────────────────────────────────────────────
      script {
        // Linki
        def reportUrl  = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl = "${env.BUILD_URL}console"
        def zipUrl     = "${env.BUILD_URL}artifact/${env.ROBOT_DIR}.zip"

        // Git meta
        def branch      = sh(script: 'git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev/main', returnStdout: true).trim().replaceFirst(/^origin\\//,'')
        def shortSha    = sh(script: 'git rev-parse --short HEAD 2>/dev/null || echo ???????', returnStdout: true).trim()
        def commitTitle = sh(script: 'git log -1 --pretty=%s 2>/dev/null || echo "-"', returnStdout: true).trim()
        def author      = sh(script: 'git log -1 --pretty="%an" 2>/dev/null || echo "-"', returnStdout: true).trim()

        // KPI z output.xml (Python; odporny na sandbox)
        def kpiOut = sh(
          script: '''
python3 - <<'PY'
import xml.etree.ElementTree as ET
try:
    root = ET.parse('robot_reports/output.xml').getroot()
    stat = root.find('./statistics/total/stat')
    total  = (stat.get('total') if stat is not None else '0')
    passed = (stat.get('pass')  if stat is not None else '0')
    failed = (stat.get('fail')  if stat is not None else '0')
    ms = int(root.get('elapsedtime') or 0)
    dur = f"{ms//60000:02d}:{(ms//1000)%60:02d}"
    suite = root.find('suite')
    start = suite.get('starttime','-') if suite is not None else '-'
    end   = suite.get('endtime','-')   if suite is not None else '-'
    print(total, passed, failed, dur, start, end, sep='|')
except Exception:
    print("-|-|-|-|-|-")
PY
''',
          returnStdout: true
        ).trim().split("\\|")
        def total=kpiOut[0], passed=kpiOut[1], failed=kpiOut[2], duration=kpiOut[3], start=kpiOut[4], end=kpiOut[5]
        def passRate = '-'
        try { def t=total as Integer; def p=passed as Integer; if (t>0) passRate = String.format('%.0f%%', (p*100.0)/t) } catch (ignored) {}

        // obrazek
        def imgTag = ''
        def shot = "${env.WORKSPACE}/${env.ROBOT_DIR}/report_snapshot.png"
        if (fileExists(shot)) {
          def b64 = sh(script: "base64 -w0 '${shot}'", returnStdout: true).trim()
          imgTag = '<img class="snap" src="data:image/png;base64,' + b64 + '" alt="Robot report"/>'
        } else {
          imgTag = '<div class="snap-missing">Snapshot unavailable</div>'
        }

        def buildStatus = currentBuild.currentResult ?: 'SUCCESS'
        def statusColor = (buildStatus == 'SUCCESS') ? '#16a34a' : '#dc2626'
        def subj        = "[${buildStatus}] ${env.JOB_NAME} #${env.BUILD_NUMBER} – Robot Report"

        String body = """
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>${subj}</title>
<style>
  body{font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;background:#f8fafc;margin:0;padding:20px}
  .card{background:#fff;border:1px solid #e5e7eb;border-radius:14px;max-width:950px;margin:auto;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.06)}
  .status{background:${statusColor};color:#fff;padding:16px 20px;font-size:18px;font-weight:700}
  .section{padding:14px 20px}
  .grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
  .box{border:1px solid #eef2f7;border-radius:12px;padding:12px}
  .chip{display:inline-flex;align-items:center;gap:6px;padding:4px 10px;border-radius:999px;border:1px solid #e5e7eb;background:#f9fafb;font-family:ui-monospace,Menlo,monospace}
  .chip.branch{background:#eef2ff;border-color:#e0e7ff;color:#1e3a8a}
  .chip.sha{background:#ecfeff;border-color:#cffafe;color:#155e75}
  .lbl{color:#6b7280;font-size:12px;margin-right:6px}
  .kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:10px}
  .kpi{background:#f9fafb;border:1px solid #eef2f7;border-radius:12px;padding:10px;text-align:center}
  .kpi .lab{font-size:12px;color:#6b7280}
  .kpi .val{font-size:22px;font-weight:800;margin-top:2px}
  .kpi.good .val{color:#16a34a} .kpi.bad .val{color:#dc2626}
  .btns{padding:0 20px 16px}
  a.btn{display:inline-block;margin-right:10px;margin-top:10px;padding:10px 14px;border-radius:10px;text-decoration:none;color:#fff}
  a.primary{background:#111827} a.secondary{background:#374151} a.zip{background:#0ea5e9}
  img.snap{max-width:860px;width:100%;height:auto;border:1px solid #eef2f7;border-radius:10px;display:block}
  .snap-missing{border:1px dashed #e5e7eb;border-radius:10px;padding:14px;color:#6b7280}
</style>
</head>
<body>
  <div class="card">
    <div class="status">${buildStatus} • ${env.JOB_NAME} • Build #${env.BUILD_NUMBER}</div>

    <div class="section">
      <div class="grid">
        <div class="box">
          <div><span class="lbl">Branch</span><span class="chip branch">${branch}</span></div>
          <div style="margin-top:8px"><span class="lbl">SHA</span><span class="chip sha">${shortSha}</span></div>
        </div>
        <div class="box">
          <div><span class="lbl">Commit title:</span><b>${commitTitle}</b></div>
          <div style="margin-top:6px"><span class="lbl">Author:</span>${author}</div>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="kpis">
        <div class="kpi"><div class="lab">All</div><div class="val">${total}</div></div>
        <div class="kpi good"><div class="lab">Passed</div><div class="val">${passed}</div></div>
        <div class="kpi bad"><div class="lab">Failed</div><div class="val">${failed}</div></div>
        <div class="kpi"><div class="lab">Pass rate</div><div class="val">${passRate}</div></div>
        <div class="kpi"><div class="lab">Duration</div><div class="val">${duration}</div></div>
      </div>
      <div style="margin-top:8px;color:#6b7280;font-size:12px">
        <span class="lbl">Start</span>${start} &nbsp;•&nbsp; <span class="lbl">End</span>${end}
      </div>
    </div>

    <div class="btns">
      <a class="btn primary"   href="${reportUrl}"  target="_blank">🔎 Open "Wikipedia - test report"</a>
      <a class="btn secondary" href="${consoleUrl}" target="_blank">🖥 Console Output</a>
      <a class="btn zip"       href="${zipUrl}"     target="_blank">📦 Download results (ZIP)</a>
    </div>

    <div class="section">${imgTag}</div>
  </div>
</body>
</html>
"""
        // Załącz ZIP jeśli niewielki
        def zipPath   = "${env.ROBOT_DIR}.zip"
        def attachZip = false
        if (fileExists(zipPath)) {
          try {
            long bytes   = (sh(script: "stat -c%s '${zipPath}' || echo 0", returnStdout: true).trim() as long)
            long maxByte = (env.MAX_ATTACH_MB as Integer) * 1024L * 1024L
            attachZip = (bytes > 0 && bytes <= maxByte)
          } catch (ignored) {}
        }
        if (attachZip) {
          emailext(subject: subj, from: env.EMAIL_FROM, to: env.EMAIL_TO, body: body, mimeType: 'text/html', attachmentsPattern: zipPath)
        } else {
          emailext(subject: subj, from: env.EMAIL_FROM, to: env.EMAIL_TO, body: body, mimeType: 'text/html')
        }
      }
    }
  }
}
