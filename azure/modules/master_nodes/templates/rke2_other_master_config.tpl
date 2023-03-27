write-kubeconfig-mode: "0644"
tls-san:
  - "${dns1}"
  - "${dns2}"
  - "${dns3}"
  - "${ip1}"
  - "${ip2}"
  - "${ip3}"
disable-kube-proxy: true
cni: "cilium"
node-label:
  - "node.kubernetes.io/master=true"
  - "node.kubernetes.io/etcd=true"
