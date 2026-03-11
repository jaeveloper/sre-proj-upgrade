## Grafana is deployed as part of kube-prometheus-stack.
## Place custom dashboard ConfigMaps here and Grafana will auto-load them
## via the sidecar (grafana.sidecar.dashboards.enabled = true by default).
##
## Access Grafana:
##   kubectl port-forward svc/prometheus-grafana -n observability 3000:80
##   http://localhost:3000   admin / prom-operator
##
## Pre-built dashboards included by kube-prometheus-stack:
##   - Kubernetes cluster resources
##   - Node exporter
##   - Pod resources
##   - KEDA metrics (add via KEDA Grafana dashboard ID 16303)
