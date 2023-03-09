# EKS Extended Cluster on Outposts Servers

## WARNING:
EKS on Outposts currently is only *supported* on the Racks form factor, thus running on the Servers form factor is not currently officially *supported*.  However, this repo shows a specific example where the cluster can be created with worker nodes running on the Outposts Server, however this configuration is *not currently supported*, but doesn't mean it doesn't actually work...

## Limitations (Known)
1. This example is based the deployment option known as [Extended Clusters](https://docs.aws.amazon.com/eks/latest/userguide/eks-outposts.html#outposts-overview-comparing-deployment-options) where the kubernetes control plane nodes run in the region, thus not on the Outposts Servers.  The "Local Clusters" deployment option is currently not available due to [Outposts Servers requiring AMIs to be composed of only a single snapshot](https://docs.aws.amazon.com/outposts/latest/server-userguide/launch-instance.html#launch-instances) combined with fact that EKS Control Plane nodes are implemented using the Bottlerocket AMI, which currently is composed of two snapshots.  (To see this for yourself, deploy EKS Local Clusters to an Outposts Rack, observe the new EC2 instances that get created, then describe one of those new instances to see the AMIid, then describe the AMI to see the composition of the snapshots)

2. Nodes in your Node Groups are subject to the same AMI limitations referenced above, thus can't use Bottlerocket or any other AMI composed of more than 1 snapshot.  This example currently uses an EKS-Optimized AmazonLinux2 AMI

## (Very Limited) Testing

1. Deployed an nginx workload with MetalLB using the https://devopslearning.medium.com/metallb-load-balancer-for-bare-metal-kubernetes-43686aa0724f as the guide for nginx but not for MetalLB.
1. Exposing a workload via the [LNI](https://docs.aws.amazon.com/outposts/latest/server-userguide/local-network-interface.html) using a Load Balancer such as [MetalLB in Layer 2 (Gratuitous ARP) mode](https://metallb.universe.tf/concepts/layer2/). 
1. Testing conducted by repo owner has only been done on a single Outposts Server.  Thus have NOT attempted to configure nor test getting nodes of different servers to talk to each other via the [LNI](https://docs.aws.amazon.com/outposts/latest/server-userguide/local-network-interface.html) of the Server. 
1. Session Manager works with AL2's EKS optimized AMI.  Have not attempted to test on RHEL 8.4+ yet.

## Current issues:

High Priority:
1. curl -v http://192.168.2.169:80 from device other than the Outposts Server it's running on.  Expect need to setup the multus cni per quip doc
1.1. Consult https://docs.aws.amazon.com/eks/latest/userguide/pod-multiple-network-interfaces.html and https://github.com/aws-samples/eks-install-guide-for-multus as needed

Low Priority:
1. as lni created from within userdata, need a lambda or some other method to cleanup these interfaces when instances they are attached to are terminated
2. Will need ability to run cloud-init from userdata, or to write scripts which get executed when required like for partition. Asked Oscar M for examples
3. parameterize eth1, 192.168.x.x, and other hardcoded values

## Identified tests not executed yet
Low:
1. TBD

Medium:
1. redo config for custom EKS for RHEL 8.7 AMI for EKS 1.24 since need to get into distro specific network setup.

## Successful tests

1. Console  
    1. Nodes Health in ASG
    2. Nodes register in cluster 
2. cli
    1. kubectl get nodes -o wide
    2. kubectl get services   
    3. curl -v http://192.168.2.169:80 from both worker nodes.