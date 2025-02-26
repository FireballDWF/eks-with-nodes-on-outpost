I've stopped using this repo, however development continues elsewhere, if you like what you see and want to see even more, contact me.
----------------------

# EKS Extended Cluster on Outposts Servers

## WARNING:
EKS on Outposts currently is only *supported* on the Racks form factor, thus running on the Servers form factor is not currently officially *supported*.  However, this repo shows a specific example where the cluster can be created with worker nodes running on the Outposts Server, however this configuration is *not currently supported*, but doesn't mean it doesn't actually work...

## Limitations (Known)
1. This example is based the deployment option known as [Extended Clusters](https://docs.aws.amazon.com/eks/latest/userguide/eks-outposts.html#outposts-overview-comparing-deployment-options) where the kubernetes control plane nodes run in the region, thus not on the Outposts Servers.  The [Local Clusters](https://aws.amazon.com/blogs/containers/amazon-eks-on-aws-outposts-now-supports-local-clusters/) deployment option is currently not available due to [Outposts Servers requiring AMIs to be composed of only a single snapshot](https://docs.aws.amazon.com/outposts/latest/server-userguide/launch-instance.html#launch-instances) combined with fact that EKS Control Plane nodes are implemented using the [Bottlerocket](https://aws.amazon.com/bottlerocket/faqs/) AMI, which currently is composed of two snapshots.  (To see this for yourself, deploy EKS Local Clusters to an Outposts Rack, observe the new EC2 instances that get created, then describe one of those new instances to see the AMIid, then describe the AMI to see the composition of the snapshots)

2. Nodes in your Node Groups are subject to the same AMI limitations referenced above, thus can't use Bottlerocket or any other AMI composed of more than 1 snapshot.  This example currently uses an EKS-Optimized AmazonLinux2 AMI

## (Very Limited) Testing

1. Deployed an nginx workload with MetalLB using the https://devopslearning.medium.com/metallb-load-balancer-for-bare-metal-kubernetes-43686aa0724f as the guide for nginx but not for MetalLB.
1. Exposing a workload via the [LNI](https://docs.aws.amazon.com/outposts/latest/server-userguide/local-network-interface.html) using a Load Balancer such as [MetalLB in Layer 2 (Gratuitous ARP) mode](https://metallb.universe.tf/concepts/layer2/). 
1. Testing conducted by repo owner has only been done on a single Outposts Server.  Thus have NOT attempted to configure nor test getting pods on nodes/instances on different servers to talk to each other via their [LNI](https://docs.aws.amazon.com/outposts/latest/server-userguide/local-network-interface.html) interfaces. 
1. Session Manager works with AL2's EKS optimized AMI.  Have not attempted to test on RHEL 8.4+ yet.

## Current issues:

Medium Priority:
1. LNI configurations of kind=NetworkAttachmentDefinition via https://github.com/FireballDWF/eks-with-nodes-on-outpost/blob/main/manifests/lni.yaml are all statically configured.
    1. Have not figured out how to get ipvlan ipam type=dhcp to work, submitted https://github.com/containernetworking/plugins/issues/862
    2. In meantime, next step is to try at least IP ranges in the static configuration so could try to reduce the number of different ipvlan configurations required

Low Priority:
1. as lni created from within userdata, need a lambda or some other method to cleanup these interfaces when instances they are attached to are terminated
2. Will need ability to run cloud-init from userdata, or to write scripts which get executed when required like for partition. Asked Oscar M for examples
3. parameterize eth1, 192.168.x.x, and other hardcoded values

## Identified tests not executed yet

High:
1. Test actual failover where Instance that metallb is arping from is terminated, thus expected behavior is other MetalLB node detects the failure, and starts arp'ing from the remaining node, service is still accessible, and replacement node comes up automatically, and can then terminate the current primary, and the replacement becomes primary and works.
2. Can communication between Pods and Nodes be configured to occur only thru an LNI interface?  (As the default is for communication to occur via the default ENI thus VPC communication, attempts to communication to other servers via VPC, which would get routed thru the region, would get dropped in the region)

Low:
1. Cost Optimization: 
    1. how to configure that an aws LB should not be deployed, as only want the MetalLB 
2.  Also consider userdata example for rc.local from https://github.com/aws-samples/eks-install-guide-for-multus/blob/main/cfn/templates/nodegroup/eks-nodegroup-multus.yaml

Medium:
1. redo config for custom EKS for RHEL 8.7 AMI for EKS 1.24 since need to get into distro specific network setup.

## Successful tests

1. Workload Specific:
    1. Primary test:
        1. curl -v http://192.168.2.169:80 
    1. Troubleshooting tests
        1. arping -I eth1 192.168.2.169
1. General Cluster Health
    1. Console  
        1. Nodes Health in ASG
        2. Nodes register in cluster 
    2. cli
        1. kubectl get nodes -o wide
        2. kubectl get service -o wide 
        3. from both worker nodes
        4. aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names filiatra-eks-outpost-tf-2023032417415967300000000b  --output text --query 'AutoScalingGroups[0].Instances[*].InstanceId' 
        5. kubectl get all -n metallb-system -o wide
        6. kubectl get ns  
