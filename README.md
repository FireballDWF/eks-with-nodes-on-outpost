# EKS Extended Cluster on Outposts Servers

## WARNING:
EKS on Outposts currently is only *supported* on the Racks form factor, thus running on the Servers form factor is not currently officially *supported*.  However, this repo shows a specific example where the cluster can be created with worker nodes running on the Outposts Server, however this configuration is *not currently supported*, but doesn't mean it doesn't actually work...

## Limitations (Known)
1. This example is based the deployment option known as [Extended Clusters](https://docs.aws.amazon.com/eks/latest/userguide/eks-outposts.html#outposts-overview-comparing-deployment-options) where the kubernetes control plane nodes run in the region, thus not on the Outposts Servers.  The "Local Clusters" deployment option is currently not available due to [Outposts Servers requiring AMIs to be composed of only a single snapshot](https://docs.aws.amazon.com/outposts/latest/server-userguide/launch-instance.html#launch-instances) combined with fact that EKS Control Plane nodes are implemented using the Bottlerocket AMI, which currently is composed of two snapshots.  (To see this for yourself, deploy EKS Local Clusters to an Outposts Rack, observe the new EC2 instances that get created, then describe one of those new instances to see the AMIid, then describe the AMI to see the composition of the snapshots)

2. Nodes in your Node Groups are subject to the same AMI limitations referenced above, thus can't use Bottlerocket or any other AMI composed of more than 1 snapshot.  This example currently uses an EKS-Optimized AmazonLinux2 AMI

## (Very Limited) Testing

1. Deployed an nginx workload with MetalLB using the https://devopslearning.medium.com/metallb-load-balancer-for-bare-metal-kubernetes-43686aa0724f as the guide for nginx but not for MetalLB 
1. Exposing a workload via the [LNI](https://docs.aws.amazon.com/outposts/latest/server-userguide/local-network-interface.html) using a Load Balancer such as [MetalLB in Layer 2 (Gratuitous ARP) mode](https://metallb.universe.tf/concepts/layer2/).  First testing with EKS 1.24 (as 1.25 eliminates PodSecurityPolicy and the Medium post above uses a config which is using PodSecurityPolicy.  Still need to test if laest version of MetalLB work with the 1.25 version of EKS)
    1.24: 
        kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
            installs with no errors
1. Testing conducted by repo owner has only been done on a single Outposts Server.  Thus have NOT attempted to configure nor test getting nodes of different servers to talk to each other via the [LNI](https://docs.aws.amazon.com/outposts/latest/server-userguide/local-network-interface.html) of the Server. 
1. Session Manager works with AL2's EKS optimized AMI.  Have not attempted to test on RHEL 8.4+ yet.

## Current issues:
1. eth1 LNI changes to use DHCP from local network don't survive reboot - lower priority sysadmin level fix
2. Traffic thru LNI interfaces getting dropped at receiver (tcpdump shows traffic (ping and http:80) arriving but no reply by receiver) Can't connect between instances on same server via LNI: Priority: Showstopper.  Next step: test where sender is an instance that is not an EKS worker node.

## TODOs:
1. Automate via USERDATA my manual updates to LNI networking - Medium
2. Automate current manual install of Cloudwatch Agent 
```
sudo yum install -y amazon-cloudwatch-agent
sudo curl https://ams-configuration-artifacts-us-west-2.s3.us-west-2.amazonaws.com/configurations/cloudwatch/latest/linux-cloudwatch-config.json -o /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/ams-accelerate-config.json
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/file_ams-accelerate-config.json
```