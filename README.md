# k8s-mac: 誰得Mac上でKubernetesをGPU対応で動作させる環境構築スクリプト

あとで、英語とかでまともに書き直すかも知れません。

## これはなに？

Mac(Apple Silicon上)でKubernetes環境を簡単に構築します。特徴は、

* Device PluginによりPodにGPUをアタッチできる
* Ingress/Gateway APIが標準で利用できるようになっている

です。最近のLLMブームに乗っかって、Macのコンテナ上からGPUを使いたくて作りました。

## 動作確認

OpenTofu(Terraformでも可)をインストールする。

    % brew install opentofu

init/applyで環境に適用

    % tofu init
    % tofu apply

これで構築完了。あとは、

    % kubectl get all --all-namespaces

でKubernetesクラスタが動作していることを確認してください。

メモリ、CPU、ディスク容量を変えたい場合は、適当にvariables.tfの内容を変更してください。デフォルトでは、

    vm_memory = 10240 (10GB)
    vm_cpus = 6

となっているので、スペックが低いMacをご利用の場合は、この辺りの値を小さくしてください。ちなみにollamaを利用することを前提にこの値は設定しています。

## 再起動時の注意

マシンを再起動すると、Kubernetesクラスタが停止します。クラスタを起動するには、Podmanの仮想マシンを起動してKubernetesのコントロールプレーンのコンテナを起動します。

    % podman machine start
    % podman container start kind-control-plane
    

## GPUのPodへのアタッチ

他のデバイスプラグインと同じように、resourcesで指定します。apple.com/gpuでGPUを割り当てることがでますが、デバイスが1しかないので、1個のコンテナにしか割り当てれないことに注意してください。

```
    resources:
      limits:
        apple.com/gpu: 1
```

コンテナは、ARMアーキテクチャのLinuxとして動作します。LinuxではMacでネイティブに利用されているGPUのアクセス機構Metal APIに対応していないので利用することができません。そのため、Vulkan API(Linux)-Metal API(Mac)の変換を内部で行い、LinuxからはVulkan APIでGPUが使えるようになっています。
GPUの利用はVulkan APIを利用してください。

## 使い方

下記のテストPod用YAMLを用意する。

#### testpod.yaml

```
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

デプロイする。

    % kubectl apply -f testpod.yaml


下記のコマンドで、「Virtio-GPU Venus (Apple M2)｣という記載があるドライバがあれば正しくGPUがアタッチできている。
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

## ライセンス・利用条件

あんまりどうでもいいと思っていますが、MITライセンスでお願いします。注意点としては、

* SNSなどで動かないなどの愚痴を書くくらいなら、GitHubのIssueを上げて頂けると助かります。SNSで呟いても開発者には届きません。
* あまり利用価値はないと思っていますが、利用価値を感じた方は、お教え頂けるとありがたいです。
* 商用利用は自由ですが、「こんなことに役立った！」というのを教えて頂けるとありがたいです。


## 技術的内容

1. コンテナ環境にはPodmanを利用。ただし、デフォルトではGPUをコンテナで利用できないため、krunkitをインストールし、利用するように設定している。
2. kindでPodman上にKubernetesクラスタを作成。その際に、Podman用のVM上のGPUデバイスをkindで作成されるコンテナにアタッチする。
3. Generic Device PluginでGPUデバイスをkind上のPodにアタッチできるようにする。
4. TraefikによりIngress/Gateway APIをサポート(Nginx IngressにもingressClass変数で変更できる)

## 参考文献

* [PodmanのコンテナからmacOSのApple Silicon GPUを使ってAIワークロードを高速処理できるようになりました](https://zenn.dev/orimanabu/articles/podman-libkrun-gpu)
  * PodmanのPodでGPUで使えるようになるところまで大変参考にさせて頂きました。

* [Kubernetes Generic Device Plugin](https://github.com/squat/generic-device-plugin)
  * このプラグインがなければDevice PluginによるGPUのアタッチは実装できなかったと思います。

* [Traefik](https://github.com/traefik/traefik-helm-chart)
  * Ingress/Gateway API対応で利用しました。これ一つで2役こなせる神Proxyです。


