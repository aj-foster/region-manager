# DigitalOcean App Platform instance
#
# This file contains the definition of the running application and all of its environment variables.
# If you intend to update the environment variables, pay special attention to the all-caps comment
# below.

resource "digitalocean_app" "this" {
  lifecycle {
    ignore_changes = [
      # COMMENT TO UPDATE ENV VALUES — BUT DON'T COMMIT IT
      spec[0].service[0].env
    ]
  }

  spec {
    name   = "ftcregion"
    region = "nyc"

    domain {
      name     = "ftcregion.com"
      type     = "PRIMARY"
      zone     = "ftcregion.com"
      wildcard = false
    }

    ingress {
      rule {
        component {
          name = "ftcregion"
        }
        match {
          path {
            prefix = "/"
          }
        }
      }
    }

    service {
      name               = "ftcregion"
      instance_size_slug = "basic-xxs"
      instance_count     = 1
      http_port          = 4000

      image {
        registry_type = "DOCR"
        repository    = "ftcregion"
        tag           = "latest"
      }

      health_check {
        initial_delay_seconds = 10
      }

      #
      # Env
      #

      # env {
      #   key   = "APPSIGNAL_ENV"
      #   value = var.nq_appsignal_env
      #   scope = "RUN_TIME"
      #   type  = "GENERAL"
      # }

      # env {
      #   key   = "APPSIGNAL_KEY"
      #   value = var.nq_appsignal_key
      #   scope = "RUN_TIME"
      #   type  = "SECRET"
      # }

      env {
        key   = "ASSET_HOST"
        value = var.rm_asset_host
        scope = "RUN_TIME"
        type  = "GENERAL"
      }

      env {
        key   = "DATABASE_CACERT"
        value = var.rm_database_cacert
        scope = "RUN_TIME"
        type  = "GENERAL"
      }

      env {
        key   = "DATABASE_URL"
        value = var.rm_database_url
        scope = "RUN_TIME"
        type  = "SECRET"
      }

      env {
        key   = "PHX_HOST"
        value = var.domain
        scope = "RUN_TIME"
        type  = "GENERAL"
      }

      env {
        key   = "POOL_SIZE"
        value = "20"
        scope = "RUN_TIME"
        type  = "GENERAL"
      }

      env {
        key   = "SECRET_KEY_BASE"
        value = var.rm_secret_key_base
        scope = "RUN_TIME"
        type  = "SECRET"
      }

      # env {
      #   key   = "SES_HOST"
      #   value = "email-smtp.us-east-1.amazonaws.com"
      #   scope = "RUN_TIME"
      #   type  = "GENERAL"
      # }

      # env {
      #   key   = "SES_PASS"
      #   value = module.az_ses.smtp_password
      #   scope = "RUN_TIME"
      #   type  = "SECRET"
      # }

      # env {
      #   key   = "SES_USER"
      #   value = module.az_ses.smtp_username
      #   scope = "RUN_TIME"
      #   type  = "SECRET"
      # }

      env {
        key   = "SPACES_ACCESS_ID"
        value = var.rm_spaces_access_id
        scope = "RUN_TIME"
        type  = "SECRET"
      }

      env {
        key   = "SPACES_ACCESS_KEY"
        value = var.rm_spaces_access_key
        scope = "RUN_TIME"
        type  = "SECRET"
      }

      env {
        key   = "SPACES_HOST"
        value = var.rm_spaces_host
        scope = "RUN_TIME"
        type  = "GENERAL"
      }

      env {
        key   = "STORAGE_BUCKET"
        value = var.rm_storage_bucket
        scope = "RUN_TIME"
        type  = "GENERAL"
      }
    }
  }
}
