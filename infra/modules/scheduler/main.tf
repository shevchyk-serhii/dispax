# ── МОДУЛЬ: CPU SCHEDULER ─────────────────────────────────────────────────────
# Перемикає Cloud Run сервіс між двома режимами за розкладом (Europe/Berlin):
#   • "on"  (Пн–Пт 06:00): min-instances=1 + CPU always-on → фонові фібери працюють
#   • "off" (Пн–Пт 23:00): min-instances=0 + CPU throttled → scale-to-zero, ~€0
# Вихідні і ночі лишаються в "off" режимі (max економія).
#
# Механізм: Cloud Scheduler (cron) → запускає Cloud Run Job (образ cloud-sdk) →
# Job виконує `gcloud run services update` тільки з потрібними прапорцями
# (partial update, не чіпає image/env/vpc — як `make deploy`).

# ── ЗМІННІ ────────────────────────────────────────────────────────────────────

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "service_name" {
  type    = string
  default = "dispax" # Cloud Run сервіс яким керуємо
}

variable "runtime_sa_name" {
  type = string # Повне ім'я SA від якого працює Cloud Run сервіс (для actAs)
}

variable "time_zone" {
  type    = string
  default = "Europe/Berlin" # Розклад у місцевому часі (з урахуванням DST)
}

variable "schedule_on" {
  type    = string
  default = "0 6 * * 1-5" # Пн–Пт 06:00 — увімкнути always-on
                          # Вихідні-увімк: змінити "1-5" → "*"
}

variable "schedule_off" {
  type    = string
  default = "0 23 * * 1-5" # Пн–Пт 23:00 — вимкнути (scale-to-zero)
}

# ── СЕРВІСНИЙ АКАУНТ ДЛЯ ПЕРЕМИКАЧА ───────────────────────────────────────────
# Окремий SA з мінімальними правами: керувати сервісом + actAs runtime-SA.
resource "google_service_account" "switcher" {
  project      = var.project_id
  account_id   = "dispax-cpu-scheduler-sa"
  display_name = "Dispax CPU Scheduler (on/off switcher)"
}

# Право оновлювати Cloud Run сервіс (змінювати min-instances / cpu-throttling).
resource "google_project_iam_member" "switcher_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.switcher.email}"
}

# actAs: оновлення сервіса який працює від dispax-server-sa вимагає права
# "використовувати" цей runtime-SA. Без цього `gcloud run services update` падає.
resource "google_service_account_iam_member" "switcher_act_as_runtime" {
  service_account_id = var.runtime_sa_name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.switcher.email}"
}

# `run services update` пересоздає ревізію і валідує що вона зможе скачати образ —
# тому switcher-SA потрібне право читати Artifact Registry. Без нього update падає
# з PERMISSION_DENIED на artifactregistry.repositories.downloadArtifacts.
resource "google_project_iam_member" "switcher_ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.switcher.email}"
}

# ── CLOUD RUN JOBS (виконують перемикання) ────────────────────────────────────
# Кожен job — одноразовий контейнер cloud-sdk що робить один `gcloud` виклик.
locals {
  modes = {
    on = {
      name = "dispax-cpu-on"
      # always-on: 1 інстанс завжди живий + CPU не throttle (фібери працюють)
      args = ["--min-instances=1", "--no-cpu-throttling"]
    }
    off = {
      name = "dispax-cpu-off"
      # scale-to-zero: 0 інстансів коли простій + CPU тільки на запити
      args = ["--min-instances=0", "--cpu-throttling"]
    }
  }
}

resource "google_cloud_run_v2_job" "switch" {
  for_each = local.modes

  project  = var.project_id
  name     = each.value.name
  location = var.region

  template {
    template {
      service_account = google_service_account.switcher.email
      max_retries     = 1
      timeout         = "120s"

      containers {
        image = "gcr.io/google.com/cloudsdktool/google-cloud-cli:stable"

        # gcloud run services update <svc> --region <r> --project <p> <flags>
        # Partial update: чіпає ТІЛЬКИ передані прапорці, решта (image/env/vpc)
        # лишається недоторканою.
        command = ["gcloud"]
        args = concat(
          [
            "run", "services", "update", var.service_name,
            "--region", var.region,
            "--project", var.project_id,
            "--quiet",
          ],
          each.value.args,
        )
      }
    }
  }
}

# ── CLOUD SCHEDULER JOBS (cron-тригери) ───────────────────────────────────────
# Дёргают Cloud Run Job через Admin API :run ендпоінт з OAuth токеном switcher-SA.
locals {
  run_job_uri = {
    for k, v in local.modes :
    k => "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${v.name}:run"
  }
}

resource "google_cloud_scheduler_job" "switch" {
  for_each = {
    on  = { schedule = var.schedule_on, desc = "Cloud Run always-on (Mon-Fri 06:00)" }
    off = { schedule = var.schedule_off, desc = "Cloud Run scale-to-zero (Mon-Fri 23:00)" }
  }

  project     = var.project_id
  region      = var.region
  name        = "dispax-cpu-${each.key}"
  description = each.value.desc
  schedule    = each.value.schedule
  time_zone   = var.time_zone

  # Якщо запуск проґавлений (напр. деплой триває) — не «доганяти» старі тіки.
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = local.run_job_uri[each.key]

    oauth_token {
      service_account_email = google_service_account.switcher.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [google_cloud_run_v2_job.switch]
}

# ── ВИХОДИ ────────────────────────────────────────────────────────────────────

output "switcher_sa_email" {
  value = google_service_account.switcher.email
}
