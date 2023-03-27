apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    kubeProxyReplacement: strict
    k8sServiceHost: ${k8s_service_host}
    k8sServicePort: 6443
    cni:
      chainingMode: "none"
    hubble:
      enabled: true
      metrics:
        enabled:
          - dns:query;ignoreAAA
          - drop
          - tcp
          - flow
          - icmp
          - http
      relay:
        enabled: true
        service:
          type: NodePort
      ui:
        enabled: true
        service:
          type: NodePort
    prometheus:
      enabled: true
    operator:
      prometheus:
        enabled: true
    envoy:
      enabled: true
    clustermesh:
      apiserver:
        tls:
          auto:
            enabled: true
      useAPIServer: true
    debug:
      enabled: true
