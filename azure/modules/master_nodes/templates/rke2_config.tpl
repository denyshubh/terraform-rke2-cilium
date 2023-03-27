token: sr02KliYHqmUrAEfUyVi3/D0hzW5ov5hSGOLlJFmfDU=
write-kubeconfig-mode: "0644"
tls-san:
  - "${dns1}"
  - "${dns2}"
  - "${dns3}"
  - "${ip1}"
  - "${ip2}"
  - "${ip3}"
cni: "cilium"
disable-kube-proxy: true
node-label:
  - "node.kubernetes.io/master=true"
  - "node.kubernetes.io/etcd=true"
