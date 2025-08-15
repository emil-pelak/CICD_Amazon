pipeline {
  agent { label 'built-in' }

  options {
    disableConcurrentBuilds()
    timestamps()
  }

  environment {
    HEADLESS  = 'true'                     // na Jenkinsie lecimy headless
    EMAIL_TO  = 'emil-pelak@outlook.com'
    EMAIL_FROM= 'emil-pelak@wp.pl'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Install dependencies') {
      steps {
        sh '''
          set -e
          python3 -m venv venv || true
          . venv/bin/activate
          pip install --upgrade pip wheel
          pip install -r requirements.txt
        '''
      }
    }

    stage('Run tests') {
      steps {
        // nie przerywamy – chcemy zawsze opublikować raport i wysłać mail
        sh '''
          set -e
          echo "🧹 Czyszczenie starych profili /tmp/robot-*"
          find /tmp -maxdepth 1 -user $(whoami) -type d -name 'robot-*' -exec rm -rf {} + || true

          . venv/bin/activate
          mkdir -p robot_reports

          robot \
            --outputdir robot_reports \
            --reporttitle "Wikipedia - test report" \
            --logtitle    "Wikipedia - log" \
            --variable HEADLESS:$HEADLESS \
            tests/ || true
        '''
      }
    }

    stage('Package & Publish') {
      steps {
        // ZIP + publikacja widoku raportu (działa nawet przy CSP; nie używamy artifact HTML bezpośrednio)
        sh '''
          cd robot_reports
          zip -qr ../robot_reports.zip .
        '''
        publishHTML([
          allowMissing: true,
          alwaysLinkToLastBuild: true,
          keepAll: true,
          reportDir: 'robot_reports',
          reportFiles: 'report.html',
          reportName: 'Robot Report'
        ])
        archiveArtifacts artifacts: 'robot_reports/**, robot_reports.zip', fingerprint: true, allowEmptyArchive: true
      }
    }

    stage('Build email summary') {
      steps {
        // Wyciągnięcie metryk z output.xml + danych gita i zbudowanie eleganckiego HTML-a do maila
        sh '''
          python3 - <<'PY'
import os, xml.etree.ElementTree as ET, subprocess, html

build_url   = os.environ.get("BUILD_URL","")
job_name    = os.environ.get("JOB_NAME","")
build_num   = os.environ.get("BUILD_NUMBER","")
report_url  = f"{build_url}Robot_20Report/"
console_url = f"{build_url}console"

# GIT (fancy)
def run(cmd):
    return subprocess.check_output(cmd, shell=True, text=True).strip()

try:
    rev       = run("git rev-parse HEAD")[0:40]
    rev_short = run("git rev-parse --short=9 HEAD")
    author    = run("git --no-pager show -s --format='%an <%ae>' HEAD")
    subject   = run("git --no-pager show -s --format='%s' HEAD")
    branch    = run("git rev-parse --abbrev-ref HEAD")
except Exception:
    rev=rev_short=author=subject=branch="n/a"

# Robot totals
tot=passed=failed=elapsed="n/a"
try:
    tree = ET.parse("robot_reports/output.xml")
    root = tree.getroot()
    stat = root.find(".//statistics/total/stat")
    if stat is not None:
        tot    = stat.attrib.get("total","0")
        passed = stat.attrib.get("pass","0")
        failed = stat.attrib.get("fail","0")
    # prosty elapsed: sumujemy 'elapsedtime' z roota (ms)
    et = root.attrib.get("elapsedtime")
    if et:
        secs = int(et) / 1000.0
        elapsed = f"{int(secs//60):02d}:{int(secs%60):02d}"
except Exception:
    pass

# Zbuduj zielony box + linki
html_body = f"""\
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>{html.escape(job_name)} – build #{build_num}</title>
<style>
  body {{ font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; }}
  .card {{ border:1px solid #e6e6e6; border-radius:10px; overflow:hidden; max-width:880px }}
  .ok {{ background:#22c55e; color:#fff; padding:16px 20px; font-size:18px; font-weight:700 }}
  .grid {{ display:grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap:8px; padding:16px }}
  .pill {{ background:#f7f7f7; border-radius:8px; padding:10px 12px; text-align:center }}
  .k {{ color:#6b7280; font-size:12px; display:block }}
  .v {{ font-size:20px; font-weight:700 }}
  .links {{ padding:0 16px 16px }}
  a.btn {{ display:inline-block; margin-right:10px; margin-top:8px; padding:10px 14px; border-radius:8px;
           background:#111827; color:#fff !important; text-decoration:none }}
  a.btn.secondary {{ background:#374151 }}
  .commit {{ padding:0 16px 16px; color:#374151 }}
  code {{ background:#f3f4f6; padding:2px 6px; border-radius:6px }}
</style>
</head>
<body>
  <div class="card">
    <div class="ok">✅ TESTY ZALICZONE • {html.escape(job_name)} • Build #{build_num}</div>
    <div class="grid">
      <div class="pill"><span class="k">Total</span><span class="v">{tot}</span></div>
      <div class="pill"><span class="k">Pass</span><span class="v">{passed}</span></div>
      <div class="pill"><span class="k">Fail</span><span class="v">{failed}</span></div>
      <div class="pill"><span class="k">Elapsed</span><span class="v">{elapsed}</span></div>
    </div>
    <div class="links">
      <a class="btn" href="{report_url}">🔎 Otwórz “Wikipedia - test report”</a>
      <a class="btn secondary" href="{console_url}">🖥 Console Output</a>
    </div>
    <div class="commit">
      <div><b>Branch:</b> <code>{html.escape(branch)}</code></div>
      <div><b>Commit:</b> <code>{html.escape(rev_short)}</code> – {html.escape(subject)}</div>
      <div><b>Author:</b> {html.escape(author)}</div>
    </div>
  </div>
  <p style="color:#6b7280;font-size:12px">Załączniki: report.html, log.html oraz ZIP z pełnym pakietem wyników.</p>
</body>
</html>
"""
open("email_summary.html","w",encoding="utf-8").write(html_body)
PY
        '''
      }
    }
  }

  post {
    always {
      script {
        // temat z czytelnym statusem
        def subj = "[${currentBuild.currentResult}] ${env.JOB_NAME} #${env.BUILD_NUMBER} – Wikipedia - test report"

        emailext(
          subject: subj,
          from:    env.EMAIL_FROM,
          to:      env.EMAIL_TO,
          // Ładny HTML z liczbami PASS/FAIL i linkiem do publikacji raportu
          body:    readFile(file: 'email_summary.html'),
          mimeType: 'text/html',
          // Dołączamy czytelne pliki (HTML + ZIP); przeglądasz lokalnie bez CSP
          attachmentsPattern: 'robot_reports/report.html, robot_reports/log.html, robot_reports.zip'
        )
      }
      echo "Pipeline finished: ${currentBuild.currentResult}"
    }
  }
}
