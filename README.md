# CICD_Wikipedia

> **EN:** End-to-end demo of UI testing Wikipedia with **Robot Framework** + **Selenium**, runnable locally and in **Jenkins**. The pipeline publishes Robot reports and emails a styled summary with an embedded PNG snapshot of `report.html`. If KPI parsing isn’t possible, the email automatically **omits** stats while still embedding the snapshot.  
> **PL:** Kompletny przykład testów UI Wikipedii w **Robot Framework** + **Selenium**, uruchamiany lokalnie i w **Jenkinsie**. Pipeline publikuje raporty Robot i wysyła estetyczny e-mail z osadzonym zrzutem PNG `report.html`. Gdy obliczenie KPI jest niemożliwe, wiadomość automatycznie **pomija** statystyki, zachowując snapshot.

---

## Table of Contents · Spis treści

- [About · O projekcie](#about--o-projekcie)
- [Features · Funkcje](#features--funkcje)
- [Repository Layout · Struktura repozytorium](#repository-layout--struktura-repozytorium)
- [Tech Stack · Stos technologiczny](#tech-stack--stos-technologiczny)
- [Quick Start (Local) · Szybki start (lokalnie)](#quick-start-local--szybki-start-lokalnie)
- [Run Options · Opcje uruchamiania](#run-options--opcje-uruchamiania)
- [Reports · Raporty](#reports--raporty)
- [Jenkins CI/CD](#jenkins-cicd)
  - [Required Plugins · Wymagane wtyczki](#required-plugins--wymagane-wtyczki)
  - [Credentials · Dane uwierzytelniające](#credentials--dane-uwierzytelniające)
  - [Pipeline Overview · Przegląd potoku](#pipeline-overview--przegląd-potoku)
  - [Email Notification · Powiadomienie e-mail](#email-notification--powiadomienie-e-mail)
- [Page Object: `WikipediaPage.robot`](#page-object-wikipediapagerobot)
- [Test Suites · Zestawy testów](#test-suites--zestawy-testów)
- [Customization · Dostosowanie](#customization--dostosowanie)
- [Troubleshooting · Rozwiązywanie problemów](#troubleshooting--rozwiązywanie-problemów)
- [FAQ](#faq)
- [Changelog · Zmiany](#changelog--zmiany)
- [License · Licencja](#license--licencja)

---

## About · O projekcie

**EN:**  
This repository demonstrates robust browser tests for Wikipedia. It uses a Page Object layer with resilient locators (handles search results and disambiguation pages), works both in GUI and headless modes, and integrates with Jenkins to publish and email results, including a snapshot of the Robot HTML report.

**PL:**  
Repozytorium prezentuje odporne testy przeglądarkowe dla Wikipedii. Wykorzystuje warstwę Page Object ze stabilnymi lokatorami (obsługa stron wyników i rozróżnień), działa w trybie GUI i headless oraz integruje się z Jenkinsem, publikując i wysyłając wyniki, w tym zrzut raportu HTML Robot.

---

## Features · Funkcje

**EN**
- ✅ Robot Framework + SeleniumLibrary
- ✅ Page Object for Wikipedia (open, search, ensure article, heading, first paragraph, infobox)
- ✅ GUI & headless (Chrome/Chromium)
- ✅ Local `run_tests.sh` with virtualenv and optional auto-open report (GUI)
- ✅ Jenkins pipeline with HTML Publisher
- ✅ Email (Email Extension) with embedded **PNG snapshot** of `report.html`
- ✅ When KPI parsing isn’t available, the email **omits** the stats gracefully

**PL**
- ✅ Robot Framework + SeleniumLibrary
- ✅ Page Object dla Wikipedii (otwarcie, wyszukiwanie, potwierdzenie artykułu, nagłówek, pierwszy akapit, infobox)
- ✅ GUI i headless (Chrome/Chromium)
- ✅ Lokalny `run_tests.sh` z virtualenv i opcjonalnym auto-otwieraniem raportu (GUI)
- ✅ Pipeline Jenkins z publikacją HTML
- ✅ E-mail (Email Extension) z osadzonym **zrzutem PNG** `report.html`
- ✅ Gdy KPI są niedostępne, e-mail **pomija** statystyki bez błędów

---

## Repository Layout · Struktura repozytorium

```text
.
├── Jenkinsfile
├── requirements.txt
├── run_tests.sh
├── page_objects/
│   └── WikipediaPage.robot
├── tests/
│   ├── Test Search.robot
│   ├── Test Paragraph.robot
│   └── Test Infobox.robot
└── robot_reports/   # generated at runtime (report, log, output.xml, screenshots, snapshot)

