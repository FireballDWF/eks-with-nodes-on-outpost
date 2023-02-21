# EKS Extended Cluster on Outposts Servers

## WARNING:
EKS on Outposts currently is only *supported* on the Racks form factor, thus running on the Servers form factor is not currently officially *supported*.  However, this repo shows a specific example where the cluster can be created with worker nodes running on the Outposts Server, however this configuration is *not currently supported*, but doesn't mean it doesn't actually work...

## Limitations (Known)
1. This example is based the deployment option known as [Extended Clusters](https://docs.aws.amazon.com/eks/latest/userguide/eks-outposts.html#outposts-overview-comparing-deployment-options) where the kubernetes control plane nodes run in the region, thus not on the Outposts Servers.  The "Local Clusters" deployment option is currently not available due to [Outposts Servers requiring AMIs to be composed of only a single snapshot](https://docs.aws.amazon.com/outposts/latest/server-userguide/launch-instance.html#launch-instances) combined with fact that EKS Control Plane nodes are implemented using the Bottlerocket AMI, which currently is composed of two snapshots.  (To see this for yourself, deploy EKS Local Clusters to an Outposts Rack, observe the new EC2 instances that get created, then describe one of those new instances to see the AMIid, then describe the AMI to see the composition of the snapshots)

2. Nodes in your Node Groups are subject to the same AMI limitations referenced above, thus can't use Bottlerocket or any other AMI composed of more than 1 snapshot.  This example currently uses an EKS-Optimized AmazonLinux2 AMI

3. The subnets created on the Outposts Server leveraging terraform do not yet automatically configure the subnets to support the [LNI feature of Servers](https://docs.aws.amazon.com/outposts/latest/server-userguide/local-network-interface.html).  The missing step is documented at [Enable local network interfaces of Outpost subnets](https://docs.aws.amazon.com/outposts/latest/server-userguide/local-network-interface.html#enable-lni).  A future enhancement to this repo may leverage a ["local-exec" provisioner](https://developer.hashicorp.com/terraform/language/resources/provisioners/local-exec) to execute the referenced awscli modify-subnet-attribute command.

4. The nodes created do not yet have LNI's created/attached. Will need to refactor to create nodes via the module terraform-aws-eks such as seen in https://gitlab.aws.dev/osmed/london_demo/-/blob/main/main.tf#L120 and following the example for customizing network_interfaces as seen in https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v19.10.0/examples/self_managed_node_group/main.tf#L163 

## (Very Limited) Testing

1. Have not tested clusters running an actual workload.
1. Have not tested exposing a workload via the [LNI](https://docs.aws.amazon.com/outposts/latest/server-userguide/local-network-interface.html) using a Load Balancer such as [MetalLB in Layer 2 (Gratuitous ARP) mode](https://metallb.universe.tf/concepts/layer2/)
1. Testing conducted by repo owner has only been done on a single Outposts Server.  Thus have NOT attempted to configure nor test getting nodes to talk to each other via the [LNI](https://docs.aws.amazon.com/outposts/latest/server-userguide/local-network-interface.html) of the Server. 
