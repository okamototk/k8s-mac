# k8s-mac: Kubernetes Installer with macOS GPU Support

## Challenge

Installing Kubernetes on Apple Silicon Macs while enabling GPU acceleration presents unique challenges. macOS uses the Metal API for GPU access, but Linux containers (the default runtime for Kubernetes on macOS) cannot leverage Metal. This prevents GPU utilization for workloads like AI/ML inference in containers.

## Solution

k8s-mac simplifies GPU-enabled Kubernetes setups on Apple Silicon Macs. By automating the installation of required components (including Vulkan API support for GPU passthrough), it allows containers to access the GPU via Vulkan instead of Metal.

## Key Features:

1. One-Command Setup: Uses OpenTofu/Terraform for infrastructure provisioning.

2. Vulkan GPU Support: Containers leverage the GPU through Vulkan API (compatible with frameworks like llama.cpp and Ollama).

3. Native macOS Integration: Works seamlessly with Apple Silicon GPUs (M1/M2/M3/M4).


## Installation

### Prerequisites

* macOS Ventura or newer (Apple Silicon only).
* Homebrew installed.

### Steps

Install OpenTofu (recommended) or Terraform:

```bash
brew install opentofu
# OR for Terraform: 
# brew install terraform
```

Initialize & Deploy:

```bash
tofu init   # Use `terraform init` if using Terraform
tofu apply  # Use `terraform apply` if using Terraform
```

### Verify Installation:

```bash
kubectl get all --all-namespaces
```

### Configuration (Optional)
Adjust resource allocation in variables.tf (defaults below are suitable for 7B/8B LLMs):

```
vm_memory = 10240  # 10GB RAM
vm_cpus   = 6      # 6 vCPUs
```

Note: Reduce these values for lower-spec Macs (e.g., vm_cpus = 4 for base M1).


## Using the GPU in Pods

To request GPU access, specify apple.com/gpu in your pod’s resource limits:

```yaml
resources:
  limits:
    apple.com/gpu: 1  # Apple Silicon devices have 1 GPU
```

Important: Only 1 GPU can be allocated per pod (Apple Silicon GPUs are unified).

Containers must use ARM64 Linux images with Vulkan support.

## Example: Validating GPU Access

### Step 1: Deploy a Test Pod

Save this as testpod.yaml:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test
spec:
  containers:
  - name: test
    image: quay.io/slopezpa/fedora-vgpu-llama
    command: [ "/bin/bash", "-c", "--" ]
    args: [ "while true; do sleep 30; done;" ]
    resources:
      limits:
        apple.com/gpu: 1
```

Apply the pod:

```bash
kubectl apply -f testpod.yaml
```

### Step 2: Verify GPU Detection

Check the logs for Vulkan GPU details.
If you find "Virtio-GPU Venus (Apple MX)" by following commands, GPU is working properly on container:

```
% kubectl exec -it test -- /bin/bash
[root@test /]# vulkaninfo --summary
...
==========
VULKANINFO
==========

Vulkan Instance Version: 1.3.268


Instance Extensions: count = 23
-------------------------------
VK_EXT_acquire_drm_display             : extension revision 1
...


Devices:
========
GPU0:
        apiVersion         = 1.2.0
        driverVersion      = 23.3.5
        vendorID           = 0x106b
        deviceID           = 0xf000208
        deviceType         = PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU
        deviceName         = Virtio-GPU Venus (Apple M2)
        driverID           = DRIVER_ID_MESA_VENUS
        driverName         = venus
        driverInfo         = Mesa 23.3.5
        conformanceVersion = 1.3.0.0
        deviceUUID         = a96512ea-8991-5aa2-91a5-d72e0b0e8db6
        driverUUID         = d2076857-3352-aaf9-a5ba-778bcb213a61
GPU1:
        apiVersion         = 1.3.267
        driverVersion      = 0.0.1
        vendorID           = 0x10005
        deviceID           = 0x0000
        deviceType         = PHYSICAL_DEVICE_TYPE_CPU
        deviceName         = llvmpipe (LLVM 17.0.6, 128 bits)
        driverID           = DRIVER_ID_MESA_LLVMPIPE
        driverName         = llvmpipe
        driverInfo         = Mesa 23.3.5 (LLVM 17.0.6)
        conformanceVersion = 1.3.1.1
        deviceUUID         = 6d657361-3233-2e33-2e35-000000000000
        driverUUID         = 6c6c766d-7069-7065-5555-494400000000
```

That's all. Enjoy it!!!

## License / Condition

This software is available under MIT license. 

This is not condition but I hope:

* If you post complain on SNS, please create issue on GitHub. SNS post may not reach to me.
* If you feel k8s-mac is valuable, let me know. It increase my motivation:)
* Also if you use k8s-mac for commercial product, let me know. 

## Reference:

Mosty Japanese articles. But I would like to put them for showing my appreciate:

* [PodmanのコンテナからmacOSのApple Silicon GPUを使ってAIワークロードを高速処理できるようになりました](https://zenn.dev/orimanabu/articles/podman-libkrun-gpu)
 * PodmanのPodでGPUで使えるようになるところまで大変参考にさせて頂きました。

* [Kubernetes Generic Device Plugin](https://github.com/squat/generic-device-plugin)
  * このプラグインがなければDevice PluginによるGPUのアタッチは実装できなかったと思います。

* [Traefik](https://github.com/traefik/traefik-helm-chart)
  * Ingress/Gateway API対応で利用しました。これ一つで2役こなせる神Proxyです。
