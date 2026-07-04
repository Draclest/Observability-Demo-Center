# ==============================================================================
# EDOT — Elastic Distribution of OpenTelemetry (opentelemetry-kube-stack)
#
# Deploie : OTel Operator + CRDs, un collecteur DaemonSet (metriques noeud),
# un collecteur Deployment (metriques cluster) et une ressource Instrumentation
# pour l'auto-instrumentation des pods annotes.
#
# ATTENTION : le schema de values d'opentelemetry-kube-stack evolue selon la
# version. Cette configuration cible la serie 0.3.x. Avant un premier
# deploiement, comparez avec :
#   helm show values open-telemetry/opentelemetry-kube-stack --version <ver>
# Les points a verifier en priorite : structure collectors.<name>.config,
# presets disponibles, et cle de l'exporter elasticsearch.
#
# La connexion a Elasticsearch se fait via le secret d'utilisateur genere par
# ECK (elasticsearch-es-elastic-user, cle "elastic") monte en variable
# d'environnement : Terraform n'a pas besoin de LIRE ce secret (pas de course
# a la creation), le collecteur le resout au runtime.
# ==============================================================================

locals {
  es_endpoint            = "http://elasticsearch-es-http.${var.namespace}.svc:9200"
  es_elastic_user_secret = "elasticsearch-es-elastic-user"

  es_password_env = [{
    name = "ES_PASSWORD"
    valueFrom = {
      secretKeyRef = {
        name = local.es_elastic_user_secret
        key  = "elastic"
      }
    }
  }]

  es_exporter = {
    elasticsearch = {
      endpoints = [local.es_endpoint]
      user      = "elastic"
      password  = "$${env:ES_PASSWORD}"
    }
  }
}

resource "helm_release" "edot" {
  name       = "opentelemetry-kube-stack"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-kube-stack"
  version    = var.otel_kube_stack_version
  namespace  = kubernetes_namespace.elastic.metadata[0].name

  atomic  = true
  timeout = 600

  values = [yamlencode({
    crds = {
      install = true
    }

    # OTel Operator (webhooks certifies par le cert-manager deja installe).
    opentelemetry-operator = {
      enabled = true
      admissionWebhooks = {
        certManager = {
          enabled = true
        }
      }
    }

    # Instrumentation pour l'auto-instrumentation zero-code des pods annotes.
    instrumentation = {
      enabled = true
      exporter = {
        endpoint = "http://opentelemetry-kube-stack-daemon-collector.${var.namespace}.svc:4318"
      }
    }

    collectors = {
      # Collecteur DaemonSet : metriques niveau noeud + logs.
      daemon = {
        presets = {
          hostMetrics    = { enabled = true }
          kubeletMetrics = { enabled = true }
          logsCollection = { enabled = true }
        }
        extraEnvs = local.es_password_env
        config = {
          exporters = local.es_exporter
          service = {
            pipelines = {
              traces  = { exporters = ["elasticsearch"] }
              metrics = { exporters = ["elasticsearch"] }
              logs    = { exporters = ["elasticsearch"] }
            }
          }
        }
      }

      # Collecteur Deployment : metriques niveau cluster + evenements.
      cluster = {
        presets = {
          clusterMetrics   = { enabled = true }
          kubernetesEvents = { enabled = true }
        }
        extraEnvs = local.es_password_env
        config = {
          exporters = local.es_exporter
          service = {
            pipelines = {
              metrics = { exporters = ["elasticsearch"] }
              logs    = { exporters = ["elasticsearch"] }
            }
          }
        }
      }
    }
  })]

  depends_on = [kubectl_manifest.elasticsearch]
}
