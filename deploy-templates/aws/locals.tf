locals {
  wait_for_cluster_cmd = "timeout ${var.connection_timeout}s bash -c 'while ! wget --no-check-certificate -O - -q $ENDPOINT >/dev/null && exit 0 ; do echo \"Waiting for Vault port 8200 open\"; sleep 15; done'"
  tags = merge(var.tags, {
    "user:tag" = var.cluster_name
  })
}