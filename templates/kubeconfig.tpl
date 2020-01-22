# vi: ft=yaml

apiVersion: v1
clusters:
- name: ${cluster_name}
  cluster:
    certificate-authority-data: ${ca_certificate}
    server: https://${server}
contexts:
- name: ${cluster_name}
  context:
    cluster: ${cluster_name}
    user: client
current-context: ${cluster_name}
kind: Config
preferences: {}
users:
- name: client
  user:
    client-certificate-data: ${client_certificate}
    client-key-data: ${client_key}
