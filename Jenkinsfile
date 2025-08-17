pipeline {
  agent any

  environment {
    ROBOT_DIR  = "robot_reports"
    PY_ENV     = "venv"
    HEADLESS   = "true"                   // run headless on Jenkins
    EMAIL_FROM = "emil-pelak@wp.pl"
    EMAIL_TO   = "emil-pelak@outlook.com"
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
        '''
      }
    }

    stage('Run tests') {
      steps {
        sh '''
          set -e
          echo "🧹 Cleaning old /tmp/robot-* profiles"
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

    stage('Publish report') {
      steps {
        sh '''
          cd ${ROBOT_DIR}
          zip -qr ../${ROBOT_DIR}.zip .
        '''
        publishHTML(target: [
          allowMissing: false,
          keepAll: true,
          reportDir: "${ROBOT_DIR}",
          reportFiles: "report.html",
          reportName: "Robot Report"
        ])
        archiveArtifacts artifacts: "${ROBOT_DIR}/**, ${ROBOT_DIR}.zip", fingerprint: true
      }
    }
  }

  post {
    always {
      script {
        // ---- Links (publisher view avoids CSP) ----
        def reportUrl   = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl  = "${env.BUILD_URL}console"
        def zipUrl      = "${env.BUILD_URL}artifact/${ROBOT_DIR}.zip"

        // ---- Git metadata ----
        def branch   = sh(script: 'git rev-parse --abbrev-ref --symbolic-full-name @{u} || git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
        def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        def subject  = sh(script: 'git log -1 --pretty=%s', returnStdout: true).trim()
        def author   = sh(script: 'git log -1 --pretty="%an <%ae>"', returnStdout: true).trim()

        // ---- Parse Robot XML + optional thumbnail (Base64) ----
        def parseOut = sh(returnStdout: true, label: 'Parse stats & build thumbnail', script: '''
          set -e
          . ${PY_ENV}/bin/activate
          python3 - <<'PY'
import os, base64, xml.etree.ElementTree as ET
from io import BytesIO

# Try Pillow for thumbnail; if not present, just skip image.
try:
    from PIL import Image, ImageDraw, ImageFont
    PIL_OK = True
except Exception:
    PIL_OK = False

out_dir = os.path.join(os.getcwd(), "${ROBOT_DIR}")
xml_path = os.path.join(out_dir, "output.xml")

total = passed = failed = 0
rate = "0.0%"
elapsed = "n/a"

if os.path.exists(xml_path):
    root = ET.parse(xml_path).getroot()
    tests = root.findall(".//test")
    total = len(tests)
    passed = sum(1 for t in tests if (t.find("status") is not None and t.find("status").attrib.get("status") == "PASS"))
    failed = total - passed
    ms = root.attrib.get("elapsedtime")
    if ms:
        s = float(ms) / 1000.0
        mm = int(s // 60); ss = int(round(s - mm*60))
        elapsed = f"{mm:02d}:{ss:02d}"
    rate = f"{(passed/total*100):.1f}%" if total else "0.0%"

print("ROBOT_TOTAL=" + str(total))
print("ROBOT_PASS=" + str(passed))
print("ROBOT_FAIL=" + str(failed))
print("ROBOT_RATE=" + rate)
print("ROBOT_ELAPSED=" + elapsed)

b64 = ""
if PIL_OK:
    W, H = 900, 220
    img_dir = out_dir
    img_path = os.path.join(img_dir, "summary.png")

    from PIL import Image, ImageDraw, ImageFont
    img = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(img)

    def font(name, size):
        try: return ImageFont.truetype(name, size)
        except: return ImageFont.load_default()

    f_head = font("DejaVuSans-Bold.ttf", 20)
    f_lab  = font("DejaVuSans.ttf", 12)
    f_num  = font("DejaVuSans-Bold.ttf", 26)

    # green header
    d.rectangle((0,0,W,44), fill=(34,197,94))
    d.text((14,10), "Robot Report – summary", fill="white", font=f_head)

    labels = ["Total","Passed","Failed","Pass rate","Duration"]
    values = [str(total), str(passed), str(failed), rate, elapsed]

    x = 14
    for i in range(5):
        d.rounded_rectangle((x,64,x+168,140), radius=10, fill=(249,250,251), outline=(238,242,247))
        d.text((x+12,72), labels[i], fill=(107,114,128), font=f_lab)
        d.text((x+12,96), values[i], fill=(17,24,39), font=f_num)
        x += 176

    img.save(img_path, "PNG")
    with open(img_path, "rb") as fh:
        b64 = base64.b64encode(fh.read()).decode("ascii")

print("REPORT_THUMB_B64=" + b64)
PY
        ''').trim()

        // Load KEY=VAL pairs from Python
        parseOut.split("\n").each { ln ->
          int i = ln.indexOf("=")
          if (i > 0) env[ln.substring(0,i)] = ln.substring(i+1)
        }

        def total    = env.ROBOT_TOTAL ?: '0'
        def passed   = env.ROBOT_PASS ?: '0'
        def failed   = env.ROBOT_FAIL ?: '0'
        def passRate = env.ROBOT_RATE ?: '0.0%'
        def elapsed  = env.ROBOT_ELAPSED ?: 'n/a'
        def thumbB64 = env.REPORT_THUMB_B64 ?: ''

        def buildStatus = currentBuild.result ?: 'SUCCESS'
        def statusBg = (buildStatus == 'SUCCESS') ? "#16a34a" : "#dc2626"
        def statusIcon = (buildStatus == 'SUCCESS') ? "✅" : "❌"
        def nodeName = env.NODE_NAME ?: 'built-in'
        def browser  = "Chrome (headless=${env.HEADLESS})"

        def subj = "[${buildStatus}] ${env.JOB_NAME} #${env.BUILD_NUMBER} – Wikipedia - test report"

        def body = """
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>${subj}</title>
<style>
  body { font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; background:#f8fafc; padding:20px }
  .card { background:#fff; border:1px solid #e5e7eb; border-radius:14px; max-width:900px; margin:auto; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,.06) }
  .status { background:${statusBg}; color:#fff; padding:16px 20px; font-size:18px; font-weight:700 }
  .sub { color:#e5e7eb; font-weight:500 }
  .grid { display:grid; grid-template-columns: repeat(5, minmax(120px,1fr)); gap:12px; padding:16px 20px 8px 20px }
  .kpi { background:#f9fafb; border:1px solid #eef2f7; border-radius:12px; padding:12px; text-align:center }
  .kpi .label { font-size:12px; color:#6b7280; display:block }
  .kpi .val   { font-size:22px; font-weight:800; margin-top:2px }
  .section { padding:0 20px 16px 20px }
  .h { font-weight:700; margin:8px 0 10px 0; color:#111827 }
  .mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; background:#f3f4f6; padding:2px 6px; border-radius:6px }
  .btns { padding:0 20px 20px 20px }
  a.btn { display:inline-block; margin-right:10px; margin-top:10px; padding:10px 14px; border-radius:10px; text-decoration:none; color:#fff }
  a.primary   { background:#111827 }
  a.secondary { background:#374151 }
  a.zip       { background:#0ea5e9 }
  .meta { display:grid; grid-template-columns: 1fr 1fr; gap:12px }
  .box  { border:1px solid #eef2f7; border-radius:12px; padding:12px }
  .muted { color:#6b7280; font-size:12px }
  img.thumb { width:100%; max-width:880px; border:1px solid #eef2f7; border-radius:10px; display:block; }
</style>
</head>
<body>
  <div class="card">
    <div class="status">${statusIcon} ${buildStatus} <span class="sub">• ${env.JOB_NAME}</span> <span class="sub">• Build #${env.BUILD_NUMBER}</span></div>

    ${thumbB64 ? "<div class='section'><img class='thumb' alt='Robot report summary' src='data:image/png;base64,"+thumbB64+"' /></div>" : ""}

    <div class="grid">
      <div class="kpi"><span class="label">Total</span><span class="val">${total}</span></div>
      <div class="kpi"><span class="label">Passed</span><span class="val">${passed}</span></div>
      <div class="kpi"><span class="label">Failed</span><span class="val">${failed}</span></div>
      <div class="kpi"><span class="label">Pass rate</span><span class="val">${passRate}</span></div>
      <div class="kpi"><span class="label">Duration (mm:ss)</span><span class="val">${elapsed}</span></div>
    </div>

    <div class="section meta">
      <div class="box">
        <div class="h">Commit</div>
        <div><b>Branch:</b> <span class="mono">${branch}</span></div>
        <div><b>SHA:</b> <span class="mono">${shortSha}</span></div>
        <div><b>Message:</b> ${subject}</div>
        <div><b>Author:</b> ${author}</div>
      </div>
      <div class="box">
        <div class="h">Execution</div>
        <div><b>Node:</b> ${nodeName}</div>
        <div><b>Browser:</b> ${browser}</div>
      </div>
    </div>

    <div class="btns">
      <a class="btn primary"   href="${reportUrl}"  target="_blank">🔎 Open “Wikipedia - test report”</a>
      <a class="btn secondary" href="${consoleUrl}" target="_blank">🖥 Console Output</a>
      <a class="btn zip"       href="${zipUrl}"     target="_blank">📦 Download results (ZIP)</a>
    </div>

    <div class="section muted">If Chrome blocks direct HTML artifacts due to CSP, use the “Robot Report” link above (publisher view).</div>
  </div>
</body>
</html>
"""
        emailext(
          subject:  subj,
          from:     env.EMAIL_FROM,
          to:       env.EMAIL_TO,
          body:     body,
          mimeType: 'text/html',
          attachmentsPattern: 'robot_reports/report.html, robot_reports/log.html, robot_reports.zip'
        )

        echo "Pipeline finished: ${currentBuild.currentResult}"
      }
    }
  }
}
