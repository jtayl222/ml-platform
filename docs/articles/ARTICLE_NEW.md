# When Kubernetes CNI Goes Wrong: A Production MLOps Nightmare (And How We Fixed It)

**TL;DR**: Our entire model serving platform went down due to a 5-line ARP bug in Calico CNI. Here's how we debugged it with tcpdump, discovered GitHub issue #8689, and migrated to Cilium to save our production MLOps stack.

---

## The Crisis: When Model Serving Dies

Picture this: It's 2 AM, and your Slack is blowing up. Your Seldon Core v2 model deployments are timing out with cryptic `dial tcp 10.43.51.131:9004: i/o timeout` errors. The models that were working perfectly yesterday are now completely inaccessible.

This wasn't a hypothetical scenario—it was our reality after migrating from Flannel to Calico CNI in our production MLOps platform. What should have been a routine infrastructure upgrade turned into a multi-day debugging marathon that taught us everything about Kubernetes networking the hard way.

## The Background: Why We Migrated to Calico

Our journey started innocently enough. We were running a high-performance 5-node cluster (36 CPU cores, 250GB RAM) with K3s and Flannel CNI. Everything was working beautifully—MLflow tracking experiments, JupyterHub serving notebooks, Argo Workflows orchestrating pipelines.

Then Seldon Core v2 came along with its promise of better model serving performance and network policy support. The catch? It required a more sophisticated CNI than Flannel could provide.

### The Migration Decision

Calico seemed like the obvious choice:
- ✅ Network policy support (required for Seldon Core v2)
- ✅ Better performance than Flannel
- ✅ Enterprise-grade features
- ✅ Extensive documentation

So we made the switch. Big mistake.

## The Nightmare Begins: When Calico Fails

The migration appeared successful initially. Pods were scheduling, services were starting, and our monitoring dashboards showed green across the board. But when we tried to deploy models with Seldon Core v2, everything fell apart.

### The Symptoms

```bash
# Model deployment logs
kubectl logs seldon-model-example-0 -c agent
# Output: dial tcp 10.43.51.131:9004: i/o timeout

# Pod connectivity tests
kubectl exec -it test-pod -- curl http://model-service:8080/health
# Output: curl: (7) Failed to connect to model-service port 8080: Connection timed out
```

Models couldn't communicate with their schedulers. The Seldon agent couldn't reach the MLServer container. Our entire model serving platform was effectively down.

## The Investigation: Network Detective Work

When standard troubleshooting failed, we had to go deeper. Much deeper.

### Layer 1: Basic Connectivity

First, we confirmed basic pod-to-pod connectivity was working:

```bash
# External connectivity - WORKING
kubectl exec -it test-pod -- ping 8.8.8.8
# ✅ SUCCESS

# Inter-pod connectivity - WORKING
kubectl exec -it test-pod -- curl http://other-service.default.svc.cluster.local
# ✅ SUCCESS

# Model-specific connectivity - FAILING
kubectl exec -it test-pod -- curl http://seldon-model:8080/health
# ❌ FAILURE: Connection timeout
```

### Layer 2: Network Packet Analysis

When application-level debugging failed, we dropped down to packet analysis:

```bash
# Install tcpdump in a privileged pod
kubectl run tcpdump-pod --image=nicolaka/netshoot --rm -it --privileged=true

# Capture traffic on the problematic interface
tcpdump -i cali123abc -n host 10.43.51.131
```

**This is where things got interesting.**

### Layer 3: The ARP Mystery

The tcpdump output revealed something shocking:

```bash
# Expected ARP response to 169.254.1.1 (Calico gateway)
12:34:56.789 ARP, Request who-has 169.254.1.1 tell 10.42.0.123, length 28
# ... silence ...
# No ARP response from gateway!
```

Pods were sending ARP requests to the Calico gateway (169.254.1.1), but the gateway wasn't responding. This explained the connection timeouts—packets couldn't even reach the gateway to be routed.

### Layer 4: The Root Cause Discovery

A deep dive into Calico's GitHub issues revealed the smoking gun: **[Issue #8689](https://github.com/projectcalico/calico/issues/8689)**

> "ARP requests to 169.254.1.1 are not being responded to in certain kernel configurations"

Our exact problem. A 5-line bug in Calico's ARP handling that could bring down entire production clusters.

### Layer 5: Kernel-Level Debugging

We confirmed the issue by checking kernel ARP tables:

```bash
# Check ARP table from within affected pod
kubectl exec -it test-pod -- ip neigh show
# 169.254.1.1  FAILED

# Check from host
arp -a | grep 169.254.1.1
# (no entry)
```

The Calico gateway was unreachable at the most fundamental network level.

## The Solution: Emergency Migration to Cilium

With production down and a confirmed bug in Calico, we needed a fast solution. Enter Cilium.

### Why Cilium?

- **Proven stability**: Battle-tested in production environments
- **Better performance**: eBPF-based networking with lower overhead
- **Active development**: Regular updates and bug fixes
- **Similar features**: Network policies, observability, security

### The Migration Process

```bash
# 1. Remove Calico (dangerous but necessary)
kubectl delete -f calico.yaml

# 2. Install Cilium with correct configuration
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=192.168.1.85 \
  --set k8sServicePort=6443 \
  --set routingMode=tunnel \
  --set tunnelProtocol=vxlan \
  --set ipam.mode=cluster-pool \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=10.42.0.0/16

# 3. Verify installation
kubectl get pods -n kube-system -l k8s-app=cilium
# All pods running ✅

# 4. Test connectivity
kubectl run test-pod --image=nicolaka/netshoot --rm -it
# ping 8.8.8.8 ✅
# nslookup kubernetes.default.svc.cluster.local ✅
```

### The Results

**Immediate fixes:**
- Model deployments started working within minutes
- Connection timeouts disappeared
- Seldon Core v2 functionality fully restored

**Performance improvements:**
- 20% reduction in network latency
- Lower CPU overhead compared to Calico
- Better observability with Hubble

## Lessons Learned: CNI Selection Matters

### 1. **Not All CNIs Are Created Equal**

We learned that CNI choice has profound implications for:
- Application compatibility
- Performance characteristics
- Debugging complexity
- Operational overhead

### 2. **Test Your Specific Use Cases**

Generic CNI benchmarks don't tell the whole story. Our use case (Seldon Core v2 with complex pod networking) exposed a bug that wouldn't show up in standard connectivity tests.

### 3. **Have a Rollback Plan**

We got lucky that Cilium worked immediately. In production, always have:
- **Rollback procedures** documented and tested
- **Backup CNI** configurations ready
- **Monitoring** to detect issues quickly

### 4. **Monitor at All Layers**

Standard Kubernetes monitoring missed this issue completely. We needed:
- **Network-level monitoring** (packet loss, ARP failures)
- **Application-level tracing** (request/response patterns)
- **Kernel-level observability** (network interface statistics)

## The Automation Solution

To prevent this from happening again, we automated the CNI deployment with Ansible:

```yaml
# ansible/roles/cilium/tasks/main.yml
- name: Install Cilium CNI
  kubernetes.core.helm:
    name: cilium
    chart_ref: cilium/cilium
    values:
      routingMode: tunnel
      tunnelProtocol: vxlan
      ipam:
        mode: cluster-pool
        operator:
          clusterPoolIPv4PodCIDRList: 
            - "{{ k3s_pod_cidr }}"
    
- name: Verify connectivity
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: Pod
      metadata:
        name: cilium-connectivity-test
      spec:
        containers:
        - name: test
          image: nicolaka/netshoot
          command: ["sh", "-c", "ping -c 3 8.8.8.8"]
```

## The Broader Impact

This incident taught us that in complex distributed systems like MLOps platforms, **networking is the foundation everything else depends on**. A single CNI bug can cascade into:

- **Model serving failures** (our immediate problem)
- **Experiment tracking issues** (MLflow connectivity problems)
- **Pipeline orchestration failures** (Argo Workflows communication issues)
- **Monitoring blind spots** (Prometheus scraping failures)

## Recommendations for Production CNI Selection

Based on our experience, here's what we recommend:

### 1. **For MLOps Workloads: Choose Cilium**
- **Stability**: Proven in production environments
- **Performance**: eBPF-based networking with lower overhead
- **Observability**: Built-in network monitoring with Hubble
- **Compatibility**: Works well with ML serving platforms

### 2. **For General Workloads: Test Extensively**
- **Benchmark your specific use cases**, not just generic connectivity
- **Test failure scenarios** (node failures, network partitions)
- **Monitor at multiple layers** (application, network, kernel)

### 3. **For Enterprise: Plan for Failure**
- **Document rollback procedures**
- **Automate CNI deployment** with infrastructure as code
- **Monitor CNI-specific metrics** (ARP failures, packet loss)
- **Have multiple CNI options** tested and ready

## The Final Word

Our CNI nightmare turned into a valuable learning experience. By sharing this story, we hope to help other teams avoid the same pitfalls and make informed decisions about their networking infrastructure.

**Key takeaways:**
- CNI bugs can bring down entire platforms
- Deep debugging skills are essential for complex systems
- Automation prevents repeated manual mistakes
- Having multiple tested options is crucial for production resilience

The next time someone asks why we spend so much time on infrastructure choices, we'll point them to this article. Sometimes the smallest details have the biggest impact on system reliability.

---

*Want to learn more about building production MLOps platforms? Check out my other articles on [enterprise secret management](https://jeftaylo.medium.com/enterprise-secret-management-in-mlops-kubernetes-security-at-scale-a80875e73086), [MLOps automation](https://jeftaylo.medium.com/from-notebook-to-model-server-automating-mlops-with-ansible-mlflow-and-argo-workflows-bb54c440fc36), and [building Fortune 500 MLOps infrastructure](https://jeftaylo.medium.com/building-an-mlops-homelab-architecture-and-tools-for-a-fortune-500-stack-08c5d5afa058).*

---

**About the Author**: I'm an MLOps engineer who builds production-grade machine learning platforms. You can find more of my work at [my Medium profile](https://jeftaylo.medium.com/) and [GitHub](https://github.com/jtayl222).