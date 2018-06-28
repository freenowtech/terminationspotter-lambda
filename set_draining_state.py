#!/usr/bin/env python3
import boto3
import botocore.client
import logging

log = logging.getLogger()
log.setLevel(logging.WARNING)


def get_cluster_and_container_instance_arn(client: botocore.client.BaseClient, instance_id: str) -> (str, str):
    list_clusters_paginator = client.get_paginator("list_clusters")
    for page in list_clusters_paginator.paginate():
        for cluster in page["clusterArns"]:
            list_container_instances_paginator = client.get_paginator("list_container_instances")
            for instance in list_container_instances_paginator.paginate(cluster=cluster, status="ACTIVE"):
                if instance.get("containerInstanceArns"):
                    describe_container_instances_response = client.describe_container_instances(
                        cluster=cluster, containerInstances=instance["containerInstanceArns"])
                    for container_instance in describe_container_instances_response["containerInstances"]:
                        if instance_id in container_instance["ec2InstanceId"]:
                            return cluster, container_instance["containerInstanceArn"]
    return None, None


def main(event: dict):
    client = boto3.client("ecs", region_name=event["region"])

    instance_id = event["detail"]["instance-id"]
    cluster, container_instance_arn = get_cluster_and_container_instance_arn(client, instance_id)

    # if the instance is not part of any cluster we don't care
    if not cluster or not container_instance_arn:
        log.info("Instance {instance_id} is not part of any cluster".format(instance_id=instance_id))
        return

    # if it is part of a cluster set instance to draining state
    else:
        log.debug("cluster: {cluster}".format(cluster=cluster))
        log.debug("container_instance_arn: {container_instance_arn}".format(
            container_instance_arn=container_instance_arn))

        client.update_container_instances_state(
            cluster=cluster, containerInstances=[container_instance_arn], status="DRAINING"
        )
        log.info("Instance {container_instance_arn} in cluster {cluster} set to DRAINING state".format(
            container_instance_arn=container_instance_arn, cluster=cluster))


def lambda_handler(event, context):
    log.info(event)
    main(event)
