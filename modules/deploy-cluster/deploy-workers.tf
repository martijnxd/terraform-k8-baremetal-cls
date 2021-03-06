resource "vsphere_virtual_machine" "worker_nodes" {
  count            = var.nodeconfig.worker_nodes.count
  name             = "${var.nodeconfig.worker_nodes.prefix}-${count.index + 1}"
  folder           = var.folder
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  num_cpus         = var.nodeconfig.worker_nodes.cpu
  memory           = var.nodeconfig.worker_nodes.memory
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  scsi_type        = data.vsphere_virtual_machine.template.scsi_type
  firmware         = "efi"
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = "vmxnet3"
  }
  disk {
    label = "${var.nodeconfig.worker_nodes.prefix}-${count.index + 1}-disk0"
    size  = var.nodeconfig.worker_nodes.disk
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    timeout       = 120
    customize {
      linux_options {
        host_name = "${var.nodeconfig.worker_nodes.prefix}-${count.index + 1}"
        domain    = var.domain
      }
      network_interface {
        ipv4_address = "${substr(var.nodeconfig.worker_nodes.startip, 0, length(var.nodeconfig.worker_nodes.startip) - length(element(split(".", var.nodeconfig.worker_nodes.startip), 3)))}${(tonumber(element(split(".", var.nodeconfig.worker_nodes.startip), 3)) + count.index)}"
        ipv4_netmask = 24
      }
      ipv4_gateway    = var.ipv4_gateway
      dns_server_list = var.dns
    }
  }
}

resource "vsphere_compute_cluster_vm_anti_affinity_rule" "cluster_worker_anti_affinity_rule" {
  count               = (length(vsphere_virtual_machine.worker_nodes) / var.cluster_node_count)
  name                = "${var.anti_affinity_rule_name_wn}-${count.index}"
  compute_cluster_id  = data.vsphere_compute_cluster.cluster.id
  virtual_machine_ids = [for k, v in slice(vsphere_virtual_machine.worker_nodes, (count.index * var.cluster_node_count), var.cluster_node_count + (count.index * var.cluster_node_count)) : v.id]
}
