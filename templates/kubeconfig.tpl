# vi: ft=yaml

apiVersion: v1
clusters:
- name: gke
  cluster:
    certificate-authority-data: ${ca_certificate}
    server: https://${server}
contexts:
- name: gke
  context:
    cluster: gke
    user: gke
current-context: gke
kind: Config
preferences: {}
users:
- name: gke
  user:
    client-certificate-data: ${client_certificate}
    client-key-data: ${client_key}
