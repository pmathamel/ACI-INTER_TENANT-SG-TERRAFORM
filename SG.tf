

//Tenant

resource "aci_tenant" "demo_tenant" {
  name        = var.aci_tenant
}



//VRF

resource "aci_vrf" "demo_vrf" {
  tenant_dn              = aci_tenant.demo_tenant.id
  name                   = var.aci_vrf

}

//demo_AP

resource "aci_application_profile" "demo_AP" {
  tenant_dn                   = aci_tenant.demo_tenant.id
  name       = var.aci_ap
}


resource "aci_application_profile" "demo_AP_common" {
  tenant_dn                   = "uni/tn-common"
  name       = var.aci_ap
}

//Create Contract in user tenant

resource "aci_contract" "demo_contract" {
 tenant_dn   =  aci_tenant.demo_tenant.id
 name        = var.aci_contract
 scope       = "global"

}

resource "aci_contract_subject" "demo_contract_S1" {
 contract_dn   = aci_contract.demo_contract.id
 name          = "S1"
 relation_vz_rs_subj_graph_att = aci_l4_l7_service_graph_template.template.id
 relation_vz_rs_subj_filt_att = ["uni/tn-common/flt-default"]
}

//Import contract in common tennant
/*
resource "aci_imported_contract" "imported_demo_contract" {
  tenant_dn   = "uni/tn-common"
  name        = var.aci_contract
  relation_vz_rs_if = aci_contract.demo_contract.id
}*/

//The above relation is not being correctly pushed, hence using rest_api below

resource "aci_rest" "contract_import" {
  path       = "/api/mo/uni.json"
  payload = <<EOF
    {
      "vzCPIf": {
        "attributes": {
          "annotation": "orchestrator:terraform", 
          "descr": "", 
          "dn": "uni/tn-common/cif-my_contract", 
          "name": "my_contract", 
          "nameAlias": "", 
          "ownerKey": "", 
          "ownerTag": "", 
          "userdom": ":all:"
        }, 
        "children": [
          {
            "vzRsIf": {
              "attributes": {
                "annotation": "orchestrator:terraform", 
                "intent": "install", 
                "prio": "unspecified", 
                "tDn": "uni/tn-pmathame-TF/brc-my_contract", 
                "userdom": ":all:"
              }
            }
          }
        ]
      }
    }
EOF
}

// USER BDS AND EPGS

resource "aci_bridge_domain" "demo_bd_1" {
 tenant_dn                   = "uni/tn-common"
 name                        = var.aci_bd_1
 bridge_domain_type          = "regular"
 unicast_route               = "yes"
 relation_fv_rs_ctx          = "uni/tn-common/ctx-default"

}
resource "aci_subnet" "subnet-demo_bd_1" {
 parent_dn        = aci_bridge_domain.demo_bd_1.id
 ip               = "192.168.100.1/24"
 scope            = ["public", "shared"]
}

resource "aci_application_epg" "demo_epg_1" {
    application_profile_dn  = aci_application_profile.demo_AP_common.id
    name                              = var.aci_epg_1
    relation_fv_rs_bd = aci_bridge_domain.demo_bd_1.id
}





resource "aci_epg_to_domain" "dom-epg1" {
  application_epg_dn    = aci_application_epg.demo_epg_1.id
  tdn                   = "uni/vmmp-VMware/dom-ACI_VMware"
}





resource "aci_bridge_domain" "demo_bd_2" {
 tenant_dn                   = aci_tenant.demo_tenant.id
 name                        = var.aci_bd_2
 bridge_domain_type          = "regular"
 unicast_route               = "yes"
 relation_fv_rs_ctx          = aci_vrf.demo_vrf.id

}
resource "aci_subnet" "subnet-demo_bd_2" {
 parent_dn        = aci_application_epg.demo_epg_2.id
 ip               = "192.168.101.1/24"
 scope            = ["public", "shared"]

}


resource "aci_application_epg" "demo_epg_2" {
    application_profile_dn  = aci_application_profile.demo_AP.id
    name                              = var.aci_epg_2
    relation_fv_rs_bd = aci_bridge_domain.demo_bd_2.id
    relation_fv_rs_prov = [aci_contract.demo_contract.id]
}

resource "aci_epg_to_domain" "dom-epg2" {
  application_epg_dn    = aci_application_epg.demo_epg_2.id
  tdn                   = "uni/vmmp-VMware/dom-ACI_VMware"
}




//Service BDs
resource "aci_bridge_domain" "demo_service_bd_inside" {
 tenant_dn                   = aci_tenant.demo_tenant.id
 name                        = var.aci_service_bd
 bridge_domain_type          = "regular"
 unicast_route               = "yes"
 relation_fv_rs_ctx          = aci_vrf.demo_vrf.id

}
resource "aci_subnet" "subnet_inside" {
 parent_dn        = aci_bridge_domain.demo_service_bd_inside.id
 ip               = "192.168.1.1/24"

}


resource "aci_bridge_domain" "demo_service_bd_outside" {
 tenant_dn                   = "uni/tn-common" 
 name                        = "service-bd-outside"
 bridge_domain_type          = "regular"
 unicast_route               = "yes"
 relation_fv_rs_ctx          = "uni/tn-common/ctx-default"

}
resource "aci_subnet" "subnet_outside" {
 parent_dn        = aci_bridge_domain.demo_service_bd_outside.id
 ip               = "192.168.2.1/24"

}


//Redir Policy

resource "aci_service_redirect_policy" "redir-pol-provider" {
  tenant_dn               = aci_tenant.demo_tenant.id
  name                    = "redir-pol-provider"
}
resource "aci_destination_of_redirected_traffic" "destination_provider" {
  service_redirect_policy_dn  = aci_service_redirect_policy.redir-pol-provider.id
  ip                          = "192.168.1.2"
  mac                         = "DE:AD:BE:EF:00:01"
  dest_name                   = "FW1-inside"
  pod_id                      = "1"
}

resource "aci_service_redirect_policy" "redir-pol-consumer" {
  tenant_dn               = "uni/tn-common" 
  name                    = "redir-pol-consumer"
}
resource "aci_destination_of_redirected_traffic" "destination_consumer" {
  service_redirect_policy_dn  = aci_service_redirect_policy.redir-pol-consumer.id
  ip                          = "192.168.2.2"
  mac                         = "DE:AD:BE:EF:00:01"
  dest_name                   = "FW1-outside"
  pod_id                      = "1"
}

//SG template

resource "aci_l4_l7_service_graph_template" "template" {
  tenant_dn                         = aci_tenant.demo_tenant.id
  name                              = var.aci_service_graph
  ui_template_type                  = "ONE_NODE_FW_ROUTED"
  term_prov_name                    = "prov"
  term_cons_name                    = "cons"
}

resource "aci_connection" "consumer" {
  l4_l7_service_graph_template_dn  = aci_l4_l7_service_graph_template.template.id
  name  = "consumer"
  adj_type  = "L3"
  description = ""
  annotation  = ""
  conn_dir  = "consumer"
  conn_type  = "internal"
  direct_connect  = "yes"
  name_alias  = ""
  unicast_route  = "yes"
  relation_vns_rs_abs_connection_conns = [
    aci_l4_l7_service_graph_template.template.term_cons_dn,
    aci_function_node.node.conn_consumer_dn
  ]
  
}

resource "aci_connection" "provider" {
  l4_l7_service_graph_template_dn  = aci_l4_l7_service_graph_template.template.id
  name  = "provider"
  adj_type  = "L3"
  description = ""
  annotation  = ""
  conn_dir  = "provider"
  conn_type  = "internal"
  direct_connect  = "yes"
  name_alias  = ""
  unicast_route  = "yes"
  relation_vns_rs_abs_connection_conns = [
    aci_l4_l7_service_graph_template.template.term_prov_dn,
    aci_function_node.node.conn_provider_dn
  ]
}

resource "aci_function_node" "node" {
  l4_l7_service_graph_template_dn  = aci_l4_l7_service_graph_template.template.id
  name  = "N1"
  func_template_type  = "FW_ROUTED"
  func_type  = "GoTo"
  routing_mode  = "Redirect"
  managed                           = "no"
  relation_vns_rs_node_to_l_dev = "uni/tn-pmathame-TF/lDevIf-[uni/tn-common/lDevVip-fw]"
  }

//Device Selection Policy

resource "aci_logical_device_context" "dsp" {
  tenant_dn         = aci_tenant.demo_tenant.id
  ctrct_name_or_lbl = var.aci_contract
  graph_name_or_lbl = var.aci_service_graph
  node_name_or_lbl  = "N1"
  annotation        = ""
  description       = ""
  context           = ""
  name_alias        = ""
  relation_vns_rs_l_dev_ctx_to_l_dev = "uni/tn-pmathame-TF/lDevIf-[uni/tn-common/lDevVip-fw/]"
}

resource "aci_logical_interface_context" "consumer" {
  logical_device_context_dn  = aci_logical_device_context.dsp.id
  annotation  = ""
  conn_name_or_lbl  = "consumer"
  description = ""
  l3_dest  = "yes"
  name_alias  = ""
  permit_log  = "no"
  relation_vns_rs_l_if_ctx_to_l_if = "uni/tn-pmathame-TF/lDevIf-[uni/tn-common/lDevVip-fw]/lDevIfLIf-outside"
  relation_vns_rs_l_if_ctx_to_bd = aci_bridge_domain.demo_service_bd_outside.id
  relation_vns_rs_l_if_ctx_to_svc_redirect_pol = aci_service_redirect_policy.redir-pol-consumer.id
}

resource "aci_logical_interface_context" "provider" {
  logical_device_context_dn  = aci_logical_device_context.dsp.id
  annotation  = ""
  conn_name_or_lbl  = "provider"
  description = ""
  l3_dest  = "yes"
  name_alias  = ""
  permit_log  = "no"
  relation_vns_rs_l_if_ctx_to_l_if = "uni/tn-pmathame-TF/lDevIf-[uni/tn-common/lDevVip-fw]/lDevIfLIf-inside"
  relation_vns_rs_l_if_ctx_to_bd = aci_bridge_domain.demo_service_bd_inside.id
  relation_vns_rs_l_if_ctx_to_svc_redirect_pol = aci_service_redirect_policy.redir-pol-provider.id
}

// Before pushing the code below, make sure the DN of vnsLDevVip, 
// vnsRsALDevToPhysDomP, and vnsRsCIfAttN, and the vlan encap of vnsLIf matches your setup.
resource "aci_rest" "l4-l7-device" {
  path       = "/api/mo/uni.json"
  payload = <<EOF
  {
  "vnsLDevVip": {
    "attributes": {
      "devtype": "PHYSICAL", 
      "dn": "uni/tn-common/lDevVip-fw", 
      "funcType": "GoTo", 
      "managed": "no", 
      "name": "fw", 
      "svcType": "FW", 
    }, 
    "children": [
      {
        "vnsRsALDevToPhysDomP": {
          "attributes": {
            "tDn": "uni/phys-pmathame-PHYS", 
          }
        }
      }, 
      {
        "vnsLIf": {
          "attributes": {
            "encap": "vlan-1051", 
            "name": "outside", 
          }, 
          "children": [
            {
              "vnsRsCIfAttN": {
                "attributes": {
                  "tDn": "uni/tn-common/lDevVip-fw/cDev-fw-1/cIf-[oneleg]", 
                }
              }
            }
          ]
        }
      }, 
      {
        "vnsLIf": {
          "attributes": {
            "encap": "vlan-1052", 
            "name": "inside", 
          }, 
          "children": [
            {
              "vnsRsCIfAttN": {
                "attributes": {
                  "tDn": "uni/tn-common/lDevVip-fw/cDev-fw-1/cIf-[oneleg]", 
                }
              }
            }
          ]
        }
      }, 
      {
        "vnsCDev": {
          "attributes": {
            "name": "fw-1", 
          }, 
          "children": [
            {
              "vnsCIf": {
                "attributes": {
                  "name": "oneleg", 
                }, 
                "children": [
                  {
                    "vnsRsCIfPathAtt": {
                      "attributes": {
                        "tDn": "topology/pod-1/paths-101/pathep-[eth1/4]", 
                      }
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    ]
  }
}

EOF
}


// The L4-L7 device needs to be imported in the user tenant before being used. 
//This is not implemented in TF, so we need to use rest_api


resource "aci_rest" "import-l4l7-dev" {
  path       = "/api/mo/uni.json"
  payload = <<EOF
   {
      "vnsLDevIf": {
        "attributes": {
          "annotation": "", 
          "description": "", 
          "dn": "uni/tn-pmathame-TF/lDevIf-[uni/tn-common/lDevVip-fw]", 
          "ldev": "uni/tn-common/lDevVip-fw", 
          "name": "", 
          "nameAlias": "", 
          "userdom": ":all:"
        }
      }
    }
EOF
}

//Consuming a contract interface is not yet implemented in TF, therefore aci_rest is used

resource "aci_rest" "cons_contract_if" {
  path       = "/api/mo/uni.json"
  payload = <<EOF
   {
      "fvRsConsIf": {
        "attributes": {
          "annotation": "orchestrator:terraform", 
          "dn": "uni/tn-common/ap-AP-demo/epg-EPG-1/rsconsIf-my_contract", 
          "prio": "unspecified", 
          "tnVzCPIfName": "my_contract", 
          "userdom": ":all:"
        }
      }
    }
EOF
}