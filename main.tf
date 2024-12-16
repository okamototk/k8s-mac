terraform {
  required_providers {
    installer = {
      source  = "shihanng/installer"
      version = "~> 0.6.1"
    }
    kubectl = {
    source  = "gavinbunney/kubectl"
      version = "~> 1.17.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

resource "installer_brew" "podman" {
  name = "podman"
}

resource "installer_brew" "krunkit" {
  name = "slp/krunkit/krunkit"
  depends_on = [ installer_brew.podman ]
}

resource "local_file" "containers_conf" {
  source      = "config/containers.conf"
  filename = "~/.config/containers/containers.conf"
}

resource "installer_brew" "kind" {
  name = "kind"
  depends_on = [ installer_brew.krunkit ]
}

resource "installer_brew" "kubectl" {
  name = "kubectl"
  depends_on = [ installer_brew.kind ]
}

resource "null_resource" "create_cluster" {
  provisioner "local-exec" {
    command = "podman machine init --now --rootful --disk-size ${var.vm_disk} --cpus ${var.vm_cpus} --memory ${var.vm_memory}"
  }

  provisioner "local-exec" {
    command = "kind create cluster --config config/kind-config.yaml"
    environment = {
      KIND_EXPERIMENTAL_PROVIDER = "podman"
    }
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = "while true ; do kubectl get pods -nkube-system kube-apiserver-kind-control-plane; if [ $? == 0 ]; then break; fi ;done"
  }

  provisioner "local-exec" {
    when       = destroy
    command    = "podman machine rm --force"
    on_failure = continue
  }

  depends_on = [installer_brew.kind, local_file.containers_conf]
}

resource "null_resource" "create_config" {

  provisioner "local-exec" {
    command = var.ingressClass == "nginx" ? "kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml" : "true"
  }
  provisioner "local-exec" {
    command = var.ingressClass == "traefik" ? "helm repo add traefik https://traefik.github.io/charts" : "true"
  }
  provisioner "local-exec" {
    command = var.ingressClass == "traefik" ? "helm upgrade --install traefik traefik/traefik -ntraefik --create-namespace -f config/traefik-values.yaml" : "true"
  }
  provisioner "local-exec" {
    command = "kubectl apply -f config/generic-device-plugin.yaml"
  }
  provisioner "local-exec" {
    command = "sleep 10;kubectl wait --namespace kube-system --for=condition=ready pod --selector=app.kubernetes.io/name=generic-device-plugin --timeout=90s"
  }
  provisioner "local-exec" {
    command = var.ingressClass == "nginx" ? "kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s" : "true"
  } 
  provisioner "local-exec" {
    command = var.ingressClass == "traefik" ? "kubectl wait --namespace traefik --for=condition=ready pod --selector=app.kubernetes.io/name=traefik --timeout=90s" : "true"
  } 
  depends_on = [null_resource.create_cluster, installer_brew.helm]
}

resource "installer_brew" "helm" {
  name = "helm"
  depends_on = [ installer_brew.kubectl, null_resource.create_cluster ]
}
